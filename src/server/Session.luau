--!strict
-- Each player's money and base. Owns the income/hatch tick, the DataStore save, and the attributes the HUD reads.
-- Other services change a player's state only through the functions here, then call Session.changed(player) so the
-- base visuals refresh.
local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local Base = require(ReplicatedStorage.Shared.Game.Base)
local Bats = require(ReplicatedStorage.Shared.Game.Bats)
local Zones = require(ReplicatedStorage.Shared.Game.Zones)
local Economy = require(ReplicatedStorage.Shared.Game.Economy)
local Eggs = require(ReplicatedStorage.Shared.Game.Eggs)
local Progression = require(ReplicatedStorage.Shared.Game.Progression)
local BaseView = require(ReplicatedStorage.Shared.Game.BaseView)
local Collection = require(ReplicatedStorage.Shared.Game.Collection)
local Daily = require(ReplicatedStorage.Shared.Game.Daily)
local Rebirth = require(ReplicatedStorage.Shared.Game.Rebirth)
local Store = require(ReplicatedStorage.Shared.Game.Store)

local Session = {}

export type State = {
	player: Player,
	coins: number,
	base: Base.Base,
	loaded: boolean,
	mp: number, -- Meme Points: decide how far into the Wilds you may go
	speedXp: number, -- total speed XP earned by running
	treadmill: number, -- treadmill upgrade level
	claims: { [string]: boolean }, -- the worlds whose Index is complete and rewarded (their ids)
	pendingWorlds: { Zones.Zone }, -- worlds finished since the last publish (listeners are told after)
	collection: Collection.Collection, -- the Index: every character (and mutation) ever seen in this player's base
	carry: string?, -- the egg tier being carried back from the Wilds
	carryFrom: string?, -- which nest it came from (so a catch can put it back)
	carryMutation: string, -- the carried egg's mutation (Normal, Gold or Rainbow)
	purchases: Store.Purchases, -- passes owned, receipts seen, hatch tokens, paid limited eggs waiting for room
	rebirths: number,
	dailyLast: number?, -- the UTC day of the last daily reward
	dailyStreak: number,
	slow: boolean, -- Slow Mode is on (not saved)
}

local states: { [Player]: State } = {}
local listeners: { (Player) -> () } = {}
local hatchListeners: { (Player, { number }) -> () } = {}
local store: DataStore? = nil
local multipliers: () -> (number, number) = function()
	return 1, 1
end
local clock: () -> number = os.time
local catalog: Store.Catalog = Config.Monetization :: any
local loadedListeners: { (Player) -> () } = {}

-- Tests (and nothing else) swap the catalogue so they can sell things with real-looking ids.
function Session.setCatalog(c: Store.Catalog)
	catalog = c
end

function Session.catalog(): Store.Catalog
	return catalog
end

function Session.onLoaded(fn: (Player) -> ())
	table.insert(loadedListeners, fn)
end

-- The live-event multipliers (luck, income) come from LiveOps; Session never reads events itself.
function Session.setMultipliers(fn: () -> (number, number))
	multipliers = fn
end

function Session.setClock(fn: () -> number)
	clock = fn
end

function Session.now(): number
	return clock()
end

function Session.get(player: Player): State?
	return states[player]
end

function Session.onChanged(fn: (Player) -> ())
	table.insert(listeners, fn)
end

local deliverListeners: { (Player, string) -> () } = {}
local worldListeners: { (Player, Zones.Zone) -> () } = {}

-- Called when a player finishes a world's Index (the reward has just been paid).
function Session.onWorldComplete(fn: (Player, Zones.Zone) -> ())
	table.insert(worldListeners, fn)
end

-- Called when a player brings a stolen egg home (the egg's tier).
function Session.onDelivered(fn: (Player, string) -> ())
	table.insert(deliverListeners, fn)
end

function Session.onHatched(fn: (Player, { number }) -> ())
	table.insert(hatchListeners, fn)
end

-- One number on the in-game player list (the "leaderstats" folder Roblox shows beside each name).
local function setStat(player: Player, name: string, value: number)
	local board = player:FindFirstChild("leaderstats")
	if not board then
		local folder = Instance.new("Folder")
		folder.Name = "leaderstats"
		folder.Parent = player
		board = folder
	end
	local stat = (board :: Instance):FindFirstChild(name)
	if not stat then
		local made = Instance.new("IntValue")
		made.Name = name
		made.Parent = board
		stat = made
	end
	(stat :: IntValue).Value = math.floor(value)
end

local function publish(state: State)
	local _, income = multipliers()
	local _, passIncome = Store.multipliers(catalog, state.purchases)
	income *= passIncome * Rebirth.multiplier(state.rebirths)
	state.player:SetAttribute("Coins", math.floor(state.coins))
	state.player:SetAttribute("Income", Base.income(state.base, income))
	state.player:SetAttribute("Slots", state.base.size)
	state.player:SetAttribute("TrapsMax", Store.perks(catalog, state.purchases).trapMax)
	Collection.record(state.collection, state.base)
	state.player:SetAttribute("Index", Collection.encode(state.collection))
	-- finishing a world's Index pays a reward and unlocks the next bat
	for _, zone in Zones.List do
		if not state.claims[zone.id] and Collection.worldComplete(state.collection, zone.id) then
			state.claims[zone.id] = true
			local tier = Eggs.tier(zone.eggs[1])
			state.coins += if tier then tier.price * Config.Index.RewardEggs else 0
			state.pendingWorlds[#state.pendingWorlds + 1] = zone
		end
	end
	local claimed = {}
	for _, zone in Zones.List do
		if state.claims[zone.id] then
			table.insert(claimed, zone.id)
		end
	end
	state.player:SetAttribute("IndexClaims", table.concat(claimed, ","))
	state.player:SetAttribute("BatTier", Bats.tierFor(#claimed))
	local finished = state.pendingWorlds
	if #finished > 0 then
		state.pendingWorlds = {}
		for _, zone in finished do
			for _, fn in worldListeners do
				fn(state.player, zone)
			end
		end
	end
	state.player:SetAttribute("BaseItems", BaseView.encode(state.base))
	local level, left = Progression.levelFor(state.speedXp)
	state.player:SetAttribute("MemePoints", state.mp)
	state.player:SetAttribute("SpeedLevel", level)
	state.player:SetAttribute("TreadmillLevel", state.treadmill)
	state.player:SetAttribute(
		"TreadmillCost",
		if state.treadmill >= Progression.MAX_TREADMILL then 0 else Progression.treadmillCost(state.treadmill)
	)
	state.player:SetAttribute("SpeedStat", Progression.speedStat(Progression.levelFloat(state.speedXp)))
	state.player:SetAttribute("SlowMode", state.slow)
	state.player:SetAttribute(
		"SpeedProgress",
		if level >= Progression.MAX_LEVEL then 1 else left / Progression.xpForNext(level)
	)
	state.player:SetAttribute("Carrying", state.carry or "")
	state.player:SetAttribute("CarryingMutation", if state.carry then state.carryMutation else "")
	local owned = {}
	for key, has in state.purchases.passes do
		if has then
			table.insert(owned, key)
		end
	end
	table.sort(owned)
	state.player:SetAttribute("Passes", table.concat(owned, ","))
	state.player:SetAttribute("HatchTokens", state.purchases.hatchTokens)
	local eggs, characters = 0, 0
	for i = 1, state.base.size do
		local item = state.base.slots[i]
		if item then
			if item.kind == "egg" then
				eggs += 1
			else
				characters += 1
			end
		end
	end
	state.player:SetAttribute("EggsHatching", eggs)
	state.player:SetAttribute("Characters", characters)
	state.player:SetAttribute("Rebirths", state.rebirths)
	state.player:SetAttribute("RebirthCost", Rebirth.cost(state.rebirths))
	state.player:SetAttribute("DailyStreak", state.dailyStreak)
	-- the player list shows these next to every name: a cheap, constant reason to compare and compete
	-- (Meme Points were a leftover of the old gates and meant nothing to players: they are no longer shown)
	setStat(state.player, "Rebirths", state.rebirths)
end

-- Applies the player's speed (level, minus the carry penalty) to their character.
function Session.applySpeed(player: Player)
	local state = states[player]
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if state and humanoid then
		local level = Progression.levelFloat(state.speedXp)
		humanoid.WalkSpeed =
			Progression.slowed(Progression.carrySpeed(Progression.walkSpeed(level), state.carry ~= nil), state.slow)
	end
end

function Session.setSlow(player: Player, on: boolean)
	local state = states[player]
	if state then
		state.slow = on
		Session.applySpeed(player)
		Session.changed(player)
	end
end

function Session.speedLevel(player: Player): number
	local state = states[player]
	return if state then (Progression.levelFor(state.speedXp)) else 0
end

function Session.addPoints(player: Player, points: number)
	local state = states[player]
	if state then
		state.mp += points
		publish(state)
	end
end

-- Training XP (treadmill). Returns the new level.
function Session.addSpeedXp(player: Player, xp: number): number
	local state = states[player]
	if not state then
		return 0
	end
	state.speedXp += xp
	local after = Progression.levelFor(state.speedXp)
	publish(state)
	Session.applySpeed(player) -- speed rises continuously, not only at each new level
	return after
end

function Session.treadmillLevel(player: Player): number
	local state = states[player]
	return if state then state.treadmill else 0
end

-- Pays for the next treadmill level. Returns (ok, message).
function Session.upgradeTreadmill(player: Player): (boolean, string)
	local state = states[player]
	if not state then
		return false, "not ready"
	end
	if state.treadmill >= Progression.MAX_TREADMILL then
		return false, "your treadmill is fully upgraded!"
	end
	local cost = Progression.treadmillCost(state.treadmill)
	if not Session.spend(player, cost) then
		return false, `the next treadmill level costs {Economy.format(cost)}`
	end
	state.treadmill += 1
	publish(state)
	Session.changed(player) -- so the prompt text and the console display show the new level
	return true, `Treadmill level {state.treadmill}!`
end

-- Puts a bought egg straight into the base (limited eggs, rewards). Returns false if there is no room.
function Session.grantEgg(player: Player, tier: string): boolean
	local state = states[player]
	if not state or Base.placeEgg(state.base, tier) == nil then
		return false
	end
	Session.changed(player)
	return true
end

function Session.hatchTokens(player: Player): number
	local state = states[player]
	return if state then state.purchases.hatchTokens else 0
end

function Session.purchases(player: Player): Store.Purchases?
	local state = states[player]
	return if state then state.purchases else nil
end

-- The player's pass multipliers: (luck, income, training).
function Session.passMultipliers(player: Player): (number, number, number)
	local state = states[player]
	if not state then
		return 1, 1, 1
	end
	return Store.multipliers(catalog, state.purchases)
end

-- Spends an instant-hatch token on the egg in this slot. Returns (ok, message).
function Session.useHatchToken(player: Player, slot: number): (boolean, string)
	local state = states[player]
	local item = state and state.base.slots[slot]
	if not state or not item or item.kind ~= "egg" then
		return false, "nothing to hatch"
	end
	if not Store.useToken(state.purchases) then
		return false, "no instant hatches left"
	end
	item.hatchLeft = 0
	Session.hatchNow(player)
	return true, "Instant hatch!"
end

-- Hatches every egg whose timer has reached zero (used right after a skip).
function Session.hatchNow(player: Player)
	local state = states[player]
	if not state then
		return
	end
	local luck = select(1, multipliers()) * select(1, Store.multipliers(catalog, state.purchases))
	local hatched = Base.tick(state.base, 0, function(tier)
		return Eggs.roll(tier, luck, math.random)
	end, function()
		return Eggs.mutation(luck, math.random)
	end)
	if #hatched > 0 then
		for _, fn in hatchListeners do
			fn(player, hatched)
		end
		Session.changed(player)
	end
end

-- The owner pressed Hatch on a finished egg in `slot`: it becomes a character (luck and mutation as usual).
function Session.hatchSlot(player: Player, slot: number): boolean
	local state = states[player]
	if not state then
		return false
	end
	local luck = select(1, multipliers()) * select(1, Store.multipliers(catalog, state.purchases))
	local ok = Base.hatchReady(state.base, slot, function(tier)
		return Eggs.roll(tier, luck, math.random)
	end, function()
		return Eggs.mutation(luck, math.random)
	end)
	if ok then
		for _, fn in hatchListeners do
			fn(player, { slot })
		end
		Session.changed(player)
	end
	return ok
end

-- What this player's passes give besides multipliers (hatch speed, trap count, boss slowing).
function Session.perks(player: Player): Store.Perks
	local state = states[player]
	if not state then
		return Store.perks(catalog, Store.new())
	end
	return Store.perks(catalog, state.purchases)
end

function Session.rebirths(player: Player): number
	local state = states[player]
	return if state then state.rebirths else 0
end

-- Starts over for a permanent income bonus: coins and base reset, Meme Points, speed and passes stay. Returns (ok, message).
function Session.rebirth(player: Player): (boolean, string)
	local state = states[player]
	if not state then
		return false, "not ready"
	end
	if state.carry then
		return false, "put your egg down first"
	end
	if state.rebirths >= Rebirth.MAX then
		return false, "you are fully reborn!"
	end
	local cost = Rebirth.cost(state.rebirths)
	if not Rebirth.can(state.rebirths, state.coins) then
		return false, `a rebirth costs {Economy.format(cost)} coins`
	end
	state.rebirths += 1
	state.coins = Config.Economy.StartCoins
	state.base = Base.new(Config.Economy.StartSlots)
	Session.changed(player)
	return true, `REBORN! Rebirth {state.rebirths}: x{Rebirth.multiplier(state.rebirths)} coins`
end

-- Starts this player over, for the owner's testing: speed, treadmill, rebirths, coins, Meme Points, base and Index go back to the
-- beginning. What they bought with Robux (passes, tokens) stays. Only ever called for the admin who typed /resetme, on themselves.
function Session.resetProgress(player: Player): (boolean, string)
	local state = states[player]
	if not state then
		return false, "not ready"
	end
	state.carry, state.carryFrom, state.carryMutation = nil, nil, "Normal"
	state.coins = Config.Economy.StartCoins
	state.mp = 0
	state.speedXp = 0
	state.treadmill = 0
	state.rebirths = 0
	state.base = Base.new(Config.Economy.StartSlots)
	state.collection = Collection.new()
	state.claims = {}
	Session.applySpeed(player)
	Session.changed(player)
	task.spawn(Session.save, player)
	return true, "You are back at the very start: speed level 0, treadmill 0, no rebirths."
end

-- The owner's testing shortcut (/maxme, on themselves only): the treadmill at its top level, speed past the deepest world's
-- recommended level, and enough coins for anything in the game. Nothing else changes.
Session.MAX_ME_LEVEL = 110
Session.MAX_ME_COINS = 1e33
function Session.maxProgress(player: Player): (boolean, string)
	local state = states[player]
	if not state then
		return false, "not ready"
	end
	local xp = 0
	for level = 0, Session.MAX_ME_LEVEL - 1 do
		xp += Progression.xpForNext(level)
	end
	state.speedXp = math.max(state.speedXp, xp)
	state.treadmill = Progression.MAX_TREADMILL
	state.coins = math.max(state.coins, Session.MAX_ME_COINS)
	Session.applySpeed(player)
	Session.changed(player)
	task.spawn(Session.save, player)
	return true,
		`Maxed: treadmill level {Progression.MAX_TREADMILL}, speed level {Session.MAX_ME_LEVEL}, plenty of coins.`
end

local dailyListeners: { (Player, number, number, string?) -> () } = {}

function Session.onDaily(fn: (Player, number, number, string?) -> ())
	table.insert(dailyListeners, fn)
end

-- The daily reward: once per UTC day, called when a player's save has loaded. Coins go straight in; an egg waits for room.
function Session.claimDaily(player: Player): boolean
	local state = states[player]
	if not state then
		return false
	end
	local streak = Daily.next(state.dailyLast, state.dailyStreak, Daily.dayOf(clock()))
	if not streak then
		return false
	end
	local _, income = multipliers()
	local perSecond = Base.income(
		state.base,
		income * select(2, Store.multipliers(catalog, state.purchases)) * Rebirth.multiplier(state.rebirths)
	)
	local coins, egg = Daily.reward(streak, perSecond)
	state.dailyLast = Daily.dayOf(clock())
	state.dailyStreak = streak
	state.coins += coins
	if egg then
		Store.queueLimited(state.purchases, egg)
	end
	Session.changed(player)
	for _, fn in dailyListeners do
		fn(player, streak, coins, egg)
	end
	return true
end

function Session.carrying(player: Player): (string?, string?, string?)
	local state = states[player]
	if not state then
		return nil, nil, nil
	end
	return state.carry, state.carryFrom, if state.carry then state.carryMutation else nil
end

-- Starts or ends carrying an egg (nil clears it). Slows or restores the runner.
function Session.setCarry(player: Player, tier: string?, from: string?, mutation: string?)
	local state = states[player]
	if not state then
		return
	end
	state.carry = tier
	state.carryFrom = if tier then from else nil
	state.carryMutation = if tier and mutation and Eggs.Mutations[mutation] then mutation else "Normal"
	publish(state)
	Session.applySpeed(player)
end

-- Puts the carried egg in the player's base (it starts hatching) and pays Meme Points. Returns (ok, message).
function Session.deliver(player: Player, at: Base.Spot?): (boolean, string)
	local state = states[player]
	if not state or not state.carry then
		return false, "nothing to deliver"
	end
	local tier = state.carry
	local mutation = state.carryMutation
	-- a Gold egg is worth double, a Rainbow egg five times, in Meme Points and in sale price
	local worth = Eggs.Mutations[mutation] or 1
	local points = Progression.pointsForEgg(tier) * worth
	state.mp += points
	state.carry, state.carryFrom, state.carryMutation = nil, nil, "Normal"
	local message = "Egg placed! It is hatching."
	if Base.firstFree(state.base) == nil then
		-- a full base must never trap you carrying an egg you cannot drop: it is sold for half its price instead
		local def = Eggs.tier(tier)
		local coins = if def then math.floor(def.price * 0.5 * worth) else 0
		state.coins += coins
		message = `Base full! Sold the egg for {Economy.format(coins)} coins. Buy a slot to keep eggs!`
	else
		Base.placeEgg(state.base, tier, mutation, at) -- the egg goes where the player stands in the pen
	end
	Session.applySpeed(player)
	Session.changed(player)
	for _, fn in deliverListeners do
		fn(player, tier)
	end
	return true, message
end

function Session.changed(player: Player)
	local state = states[player]
	if state then
		-- a paid limited egg that was waiting for room goes in as soon as there is a free slot
		while #state.purchases.pendingLimited > 0 and Base.firstFree(state.base) ~= nil do
			local tier = Store.popLimited(state.purchases)
			if tier then
				Base.placeEgg(state.base, tier)
			end
		end
		publish(state)
	end
	for _, fn in listeners do
		fn(player)
	end
end

function Session.add(player: Player, coins: number)
	local state = states[player]
	if state then
		state.coins += coins
		publish(state)
	end
end

function Session.spend(player: Player, coins: number): boolean
	local state = states[player]
	if not state or state.coins < coins then
		return false
	end
	state.coins -= coins
	publish(state)
	return true
end

-- Buys the next slot. Returns (ok, message).
function Session.buySlot(player: Player): (boolean, string)
	local state = states[player]
	if not state then
		return false, "not ready"
	end
	if state.base.size >= Config.Economy.MaxSlots then
		return false, "you have every slot"
	end
	local cost = Economy.slotCost(state.base.size, Config.Economy.StartSlots, Config.Economy.SlotCostBase)
	if not Session.spend(player, cost) then
		return false, `a new slot costs {Economy.format(cost)}`
	end
	Base.grow(state.base, Config.Economy.MaxSlots)
	Session.changed(player)
	return true, "new slot!"
end

-- save format: plain tables only
local function serialise(state: State): { [string]: any }
	local slots = {}
	for i = 1, state.base.size do
		local item = state.base.slots[i]
		if item then
			slots[tostring(i)] = {
				kind = item.kind,
				tier = item.tier,
				hatchLeft = item.hatchLeft,
				eggMutation = item.eggMutation,
				atX = if item.at then item.at.x else nil,
				atZ = if item.at then item.at.z else nil,
				id = item.id,
				mutation = item.mutation,
			}
		end
	end
	return {
		coins = state.coins,
		size = state.base.size,
		slots = slots,
		savedAt = clock(),
		mp = state.mp,
		speedXp = state.speedXp,
		treadmill = state.treadmill,
		index = Collection.encode(state.collection),
		claims = (function()
			local list = {}
			for id in state.claims do
				table.insert(list, id)
			end
			table.sort(list)
			return table.concat(list, ",")
		end)(),
		passes = state.purchases.passes,
		receipts = state.purchases.receiptOrder,
		hatchTokens = state.purchases.hatchTokens,
		pendingLimited = state.purchases.pendingLimited,
		rebirths = state.rebirths,
		dailyLast = state.dailyLast,
		dailyStreak = state.dailyStreak,
	}
end

-- A number read from a save, made safe: NaN, infinity or a non-number become the default, then it is held inside [lo, hi]. A
-- corrupt or tampered save must never be able to poison the economy.
local function sane(value: any, default: number, lo: number, hi: number): number
	local n = tonumber(value)
	if n == nil or n ~= n or n == math.huge or n == -math.huge then
		return default
	end
	return math.clamp(n, lo, hi)
end

local function restore(state: State, saved: { [string]: any })
	state.coins = sane(saved.coins, Config.Economy.StartCoins, 0, 1e36)
	state.mp = sane(saved.mp, 0, 0, 1e15)
	state.speedXp = sane(saved.speedXp, 0, 0, 1e30)
	state.claims = {}
	for id in string.gmatch(if type(saved.claims) == "string" then string.sub(saved.claims, 1, 400) else "", "[^,]+") do
		if Zones.get(id) then
			state.claims[id] = true
		end
	end
	state.treadmill = math.floor(sane(saved.treadmill, 0, 0, Progression.MAX_TREADMILL))
	state.collection =
		Collection.decode(if typeof(saved.index) == "string" then string.sub(saved.index, 1, 4000) else "")
	state.rebirths = math.floor(sane(saved.rebirths, 0, 0, Rebirth.MAX))
	local last = tonumber(saved.dailyLast)
	state.dailyLast = if last ~= nil and last == last and last ~= math.huge and last ~= -math.huge then last else nil
	state.dailyStreak = math.floor(sane(saved.dailyStreak, 0, 0, 1e6))
	local purchases = state.purchases
	for key, owned in (if type(saved.passes) == "table" then saved.passes else {}) :: { [string]: any } do
		purchases.passes[tostring(key)] = owned == true
	end
	for _, receipt in (if type(saved.receipts) == "table" then saved.receipts else {}) :: { any } do
		if type(receipt) == "string" and not purchases.receipts[receipt] then
			purchases.receipts[receipt] = true
			table.insert(purchases.receiptOrder, receipt)
		end
	end
	purchases.hatchTokens = math.floor(sane(saved.hatchTokens, 0, 0, 1e6))
	for _, tier in (if type(saved.pendingLimited) == "table" then saved.pendingLimited else {}) :: { any } do
		if type(tier) == "string" and Eggs.tier(tier) then
			table.insert(purchases.pendingLimited, tier)
		end
	end
	state.base = Base.new(
		math.floor(sane(saved.size, Config.Economy.StartSlots, Config.Economy.StartSlots, Config.Economy.MaxSlots))
	)
	for key, item in (if type(saved.slots) == "table" then saved.slots else {}) :: { [string]: any } do
		local i = tonumber(key)
		if i and i >= 1 and i <= state.base.size and i == math.floor(i) and type(item) == "table" then
			if item.kind == "egg" and type(item.tier) == "string" and Eggs.tier(item.tier) then
				local def = Eggs.tier(item.tier) :: Eggs.Tier
				state.base.slots[i] = {
					kind = "egg",
					tier = item.tier,
					hatchLeft = sane(item.hatchLeft, def.hatchSeconds, 0.1, def.hatchSeconds),
					eggMutation = if type(item.eggMutation) == "string"
							and item.eggMutation ~= "Normal"
							and Eggs.Mutations[item.eggMutation]
						then item.eggMutation
						else nil,
					at = if type(item.atX) == "number" and type(item.atZ) == "number"
						then Base.clampSpot(item.atX, item.atZ)
						else nil,
				}
			elseif item.kind == "char" and type(item.id) == "string" and Eggs.character(item.id) then
				local mutation = if type(item.mutation) == "string" and Eggs.Mutations[item.mutation]
					then item.mutation
					else "Normal"
				state.base.slots[i] = { kind = "char", id = item.id, mutation = mutation }
			end
		end
	end
	local savedAt = sane(saved.savedAt, clock(), 0, clock())
	local away = clock() - savedAt
	state.coins += Economy.offline(
		Base.income(state.base, Rebirth.multiplier(state.rebirths)),
		away,
		Config.Economy.OfflineCapSeconds
	)
end

local function load(state: State)
	local data = store
	if data then
		local ok, saved = pcall(function()
			return data:GetAsync(`u{state.player.UserId}`)
		end)
		if ok and type(saved) == "table" then
			restore(state, saved)
		elseif not ok then
			warn(`[Session] load failed for {state.player.Name}: {saved}`)
		end
	end
	state.loaded = true
end

-- Saves the player. Returns true if saved (or if there is no DataStore to save to, as in Studio), false if it failed.
function Session.save(player: Player): boolean
	local state = states[player]
	local data = store
	if not state or not state.loaded then
		return false
	end
	if not data then
		return true
	end
	local ok, err = pcall(function()
		data:UpdateAsync(`u{player.UserId}`, function()
			return serialise(state)
		end)
	end)
	if not ok then
		warn(`[Session] save failed for {player.Name}: {err}`)
	end
	return ok
end

local function add(player: Player, onJoin: (Player) -> ())
	local state: State = {
		player = player,
		coins = Config.Economy.StartCoins,
		base = Base.new(Config.Economy.StartSlots),
		loaded = false,
		mp = 0,
		speedXp = 0,
		treadmill = 0,
		collection = Collection.new(),
		claims = {},
		pendingWorlds = {},
		purchases = Store.new(),
		rebirths = 0,
		dailyStreak = 0,
		slow = false,
		carryMutation = "Normal",
	}
	states[player] = state
	load(state)
	publish(state)
	for _, fn in loadedListeners do
		fn(player)
	end
	Session.claimDaily(player)
	player.CharacterAdded:Connect(function()
		task.defer(Session.applySpeed, player)
	end)
	Session.applySpeed(player)
	onJoin(player)
	Session.changed(player)
end

function Session.start(onJoin: (Player) -> (), onLeave: (Player) -> ())
	local ok, result = pcall(function()
		return DataStoreService:GetDataStore(Config.Save.StoreName)
	end)
	store = if ok then result else nil

	Players.PlayerAdded:Connect(function(player)
		add(player, onJoin)
	end)
	for _, player in Players:GetPlayers() do
		task.spawn(add, player, onJoin)
	end
	Players.PlayerRemoving:Connect(function(player)
		Session.save(player)
		onLeave(player)
		states[player] = nil
	end)
	game:BindToClose(function()
		for player in states do
			Session.save(player)
		end
	end)

	-- one tick drives income and hatching; the multipliers come from live events
	local carry, sinceSave = 0, 0
	RunService.Heartbeat:Connect(function(dt)
		carry += dt
		sinceSave += dt
		if carry < 0.5 then
			return
		end
		local step = carry
		carry = 0
		local luck, income = multipliers()
		local rng = function()
			return math.random()
		end
		for player, state in states do
			local passLuck, passIncome = Store.multipliers(catalog, state.purchases)
			local myLuck = luck * passLuck
			-- eggs count down and then wait, READY, for their owner to press Hatch (Session.hatchSlot)
			local readyBefore = 0
			for slot = 1, state.base.size do
				if Base.isReady(state.base, slot) then
					readyBefore += 1
				end
			end
			Base.tick(state.base, step * Store.perks(catalog, state.purchases).hatch, function(tier)
				return Eggs.roll(tier, myLuck, rng)
			end, function()
				return Eggs.mutation(myLuck, rng)
			end, false)
			local readyAfter = 0
			for slot = 1, state.base.size do
				if Base.isReady(state.base, slot) then
					readyAfter += 1
				end
			end
			if readyAfter ~= readyBefore then
				Session.changed(player) -- an egg just became READY: the pen shows its Hatch prompt
			end
			state.coins += Base.income(state.base, income * passIncome * Rebirth.multiplier(state.rebirths)) * step
			publish(state)
		end
		if sinceSave >= Config.Save.AutosaveSeconds then
			sinceSave = 0
			for player in states do
				task.spawn(Session.save, player)
			end
		end
	end)
end

return Session
