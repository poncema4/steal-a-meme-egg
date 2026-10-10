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
local Economy = require(ReplicatedStorage.Shared.Game.Economy)
local Eggs = require(ReplicatedStorage.Shared.Game.Eggs)
local Progression = require(ReplicatedStorage.Shared.Game.Progression)
local Store = require(ReplicatedStorage.Shared.Game.Store)

local Session = {}

export type State = {
	player: Player,
	coins: number,
	base: Base.Base,
	loaded: boolean,
	mp: number, -- Meme Points: decide how far into the Wilds you may go
	speedXp: number, -- total treadmill/bought speed XP
	carry: string?, -- the egg tier being carried back from the Wilds
	carryFrom: string?, -- which nest it came from (so a catch can put it back)
	purchases: Store.Purchases, -- passes owned, receipts seen, hatch tokens, paid limited eggs waiting for room
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

function Session.onHatched(fn: (Player, { number }) -> ())
	table.insert(hatchListeners, fn)
end

local function publish(state: State)
	local _, income = multipliers()
	local _, passIncome = Store.multipliers(catalog, state.purchases)
	income *= passIncome
	state.player:SetAttribute("Coins", math.floor(state.coins))
	state.player:SetAttribute("Income", Base.income(state.base, income))
	state.player:SetAttribute("Slots", state.base.size)
	local level, left = Progression.levelFor(state.speedXp)
	state.player:SetAttribute("MemePoints", state.mp)
	state.player:SetAttribute("SpeedLevel", level)
	state.player:SetAttribute(
		"SpeedProgress",
		if level >= Progression.MAX_LEVEL then 1 else left / Progression.xpForNext(level)
	)
	state.player:SetAttribute("Carrying", state.carry or "")
end

-- Applies the player's speed (level, minus the carry penalty) to their character.
function Session.applySpeed(player: Player)
	local state = states[player]
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if state and humanoid then
		local level = Progression.levelFor(state.speedXp)
		humanoid.WalkSpeed = Progression.carrySpeed(Progression.walkSpeed(level), state.carry ~= nil)
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
	local before = Progression.levelFor(state.speedXp)
	state.speedXp += xp
	local after = Progression.levelFor(state.speedXp)
	publish(state)
	if after ~= before then
		Session.applySpeed(player)
	end
	return after
end

-- Buys the next speed level with coins: jumps the XP to the start of that level. Returns (ok, message).
function Session.buySpeed(player: Player): (boolean, string)
	local state = states[player]
	if not state then
		return false, "not ready"
	end
	local level = Progression.levelFor(state.speedXp)
	if level >= Progression.MAX_LEVEL then
		return false, "max speed!"
	end
	local cost = Progression.speedCost(level)
	if not Session.spend(player, cost) then
		return false, `speed {level + 1} costs {Economy.format(cost)}`
	end
	local total = 0
	for n = 0, level do
		total += Progression.xpForNext(n)
	end
	state.speedXp = total
	publish(state)
	Session.applySpeed(player)
	return true, `Speed level {level + 1}!`
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

-- Finishes a hatch right now for coins. Returns (ok, message).
function Session.skipHatch(player: Player, slot: number): (boolean, string)
	local state = states[player]
	local item = state and state.base.slots[slot]
	if not state or not item or item.kind ~= "egg" or not item.tier then
		return false, "nothing to hatch"
	end
	local tier = Eggs.tier(item.tier)
	if not tier then
		return false, "unknown egg"
	end
	local cost = Economy.skipCost(tier.price, item.hatchLeft or 0, tier.hatchSeconds)
	if not Session.spend(player, cost) then
		return false, `skipping costs {Economy.format(cost)}`
	end
	item.hatchLeft = 0
	Session.hatchNow(player)
	return true, "hatched!"
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

function Session.carrying(player: Player): (string?, string?)
	local state = states[player]
	if not state then
		return nil, nil
	end
	return state.carry, state.carryFrom
end

-- Starts or ends carrying an egg (nil clears it). Slows or restores the runner.
function Session.setCarry(player: Player, tier: string?, from: string?)
	local state = states[player]
	if not state then
		return
	end
	state.carry = tier
	state.carryFrom = if tier then from else nil
	publish(state)
	Session.applySpeed(player)
end

-- Puts the carried egg in the player's base (it starts hatching) and pays Meme Points. Returns (ok, message).
function Session.deliver(player: Player): (boolean, string)
	local state = states[player]
	if not state or not state.carry then
		return false, "nothing to deliver"
	end
	if Base.firstFree(state.base) == nil then
		return false, "your base is full!"
	end
	local tier = state.carry
	Base.placeEgg(state.base, tier)
	local points = Progression.pointsForEgg(tier)
	state.mp += points
	state.carry, state.carryFrom = nil, nil
	Session.applySpeed(player)
	Session.changed(player)
	return true, `+{points} Meme Points!`
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
		passes = state.purchases.passes,
		receipts = state.purchases.receiptOrder,
		hatchTokens = state.purchases.hatchTokens,
		pendingLimited = state.purchases.pendingLimited,
	}
end

local function restore(state: State, saved: { [string]: any })
	state.coins = tonumber(saved.coins) or Config.Economy.StartCoins
	state.mp = math.max(tonumber(saved.mp) or 0, 0)
	state.speedXp = math.max(tonumber(saved.speedXp) or 0, 0)
	local purchases = state.purchases
	for key, owned in (if type(saved.passes) == "table" then saved.passes else {}) :: { [string]: any } do
		purchases.passes[key] = owned == true
	end
	for _, receipt in (if type(saved.receipts) == "table" then saved.receipts else {}) :: { any } do
		if type(receipt) == "string" and not purchases.receipts[receipt] then
			purchases.receipts[receipt] = true
			table.insert(purchases.receiptOrder, receipt)
		end
	end
	purchases.hatchTokens = math.max(tonumber(saved.hatchTokens) or 0, 0)
	for _, tier in (if type(saved.pendingLimited) == "table" then saved.pendingLimited else {}) :: { any } do
		if type(tier) == "string" and Eggs.tier(tier) then
			table.insert(purchases.pendingLimited, tier)
		end
	end
	state.base = Base.new(
		math.clamp(
			tonumber(saved.size) or Config.Economy.StartSlots,
			Config.Economy.StartSlots,
			Config.Economy.MaxSlots
		)
	)
	for key, item in (saved.slots or {}) :: { [string]: any } do
		local i = tonumber(key)
		if i and i >= 1 and i <= state.base.size and type(item) == "table" then
			if item.kind == "egg" and Eggs.tier(item.tier) then
				state.base.slots[i] = { kind = "egg", tier = item.tier, hatchLeft = tonumber(item.hatchLeft) or 1 }
			elseif item.kind == "char" and Eggs.character(item.id) then
				state.base.slots[i] = { kind = "char", id = item.id, mutation = item.mutation or "Normal" }
			end
		end
	end
	local away = clock() - (tonumber(saved.savedAt) or clock())
	state.coins += Economy.offline(Base.income(state.base, 1), away, Config.Economy.OfflineCapSeconds)
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
		purchases = Store.new(),
	}
	states[player] = state
	load(state)
	publish(state)
	for _, fn in loadedListeners do
		fn(player)
	end
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
			local hatched = Base.tick(state.base, step, function(tier)
				return Eggs.roll(tier, myLuck, rng)
			end, function()
				return Eggs.mutation(myLuck, rng)
			end)
			state.coins += Base.income(state.base, income * passIncome) * step
			publish(state)
			if #hatched > 0 then
				for _, fn in hatchListeners do
					fn(player, hatched)
				end
				Session.changed(player)
			end
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
