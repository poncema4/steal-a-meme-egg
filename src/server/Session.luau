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

local Session = {}

export type State = { player: Player, coins: number, base: Base.Base, loaded: boolean }

local states: { [Player]: State } = {}
local listeners: { (Player) -> () } = {}
local hatchListeners: { (Player, { number }) -> () } = {}
local store: DataStore? = nil
local multipliers: () -> (number, number) = function()
	return 1, 1
end
local clock: () -> number = os.time

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
	state.player:SetAttribute("Coins", math.floor(state.coins))
	state.player:SetAttribute("Income", Base.income(state.base, income))
	state.player:SetAttribute("Slots", state.base.size)
end

function Session.changed(player: Player)
	local state = states[player]
	if state then
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
	return { coins = state.coins, size = state.base.size, slots = slots, savedAt = clock() }
end

local function restore(state: State, saved: { [string]: any })
	state.coins = tonumber(saved.coins) or Config.Economy.StartCoins
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

function Session.save(player: Player)
	local state = states[player]
	local data = store
	if not state or not data or not state.loaded then
		return
	end
	local ok, err = pcall(function()
		data:UpdateAsync(`u{player.UserId}`, function()
			return serialise(state)
		end)
	end)
	if not ok then
		warn(`[Session] save failed for {player.Name}: {err}`)
	end
end

local function add(player: Player, onJoin: (Player) -> ())
	local state: State = {
		player = player,
		coins = Config.Economy.StartCoins,
		base = Base.new(Config.Economy.StartSlots),
		loaded = false,
	}
	states[player] = state
	load(state)
	publish(state)
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
			local hatched = Base.tick(state.base, step, function(tier)
				return Eggs.roll(tier, luck, rng)
			end, function()
				return Eggs.mutation(luck, rng)
			end)
			state.coins += Base.income(state.base, income) * step
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
