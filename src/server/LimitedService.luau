--!strict
-- Limited eggs: the egg on sale this half hour, its shared stock, and buying it. Stock is one counter per rotation in
-- MemoryStore (shared by every server); if MemoryStore is unavailable (Studio, an outage) each server keeps its own count.
-- The rules (which egg, how stock moves) are in Shared/Game/Limited; this file only talks to Roblox.
local MemoryStoreService = game:GetService("MemoryStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Base = require(ReplicatedStorage.Shared.Game.Base)
local Eggs = require(ReplicatedStorage.Shared.Game.Eggs)
local Limited = require(ReplicatedStorage.Shared.Game.Limited)
local Session = require(script.Parent.Session)

local LimitedService = {}

local localStock: { [string]: number } = {}
local map: MemoryStoreHashMap? = nil
local notify: (Player, string) -> () = function(_player: Player, _text: string) end
local lastSeen = -1

local function rotation(): Limited.Rotation
	return Limited.current(Session.now())
end

-- Takes one from the shared stock. Returns the stock left after, or nil if it was sold out.
function LimitedService.claimStock(key: string): number?
	local shared = map
	if shared then
		local ok, result = pcall(function()
			return shared:UpdateAsync(key, Limited.claim, Limited.PERIOD * 2)
		end)
		if ok then
			return result
		end
		warn(`[Limited] shared stock failed, using this server's: {result}`)
	end
	local after = Limited.claim(localStock[key])
	if after ~= nil then
		localStock[key] = after
	end
	return after
end

local function releaseStock(key: string)
	local shared = map
	if shared then
		local ok = pcall(function()
			return shared:UpdateAsync(key, Limited.release, Limited.PERIOD * 2)
		end)
		if ok then
			return
		end
	end
	localStock[key] = Limited.release(localStock[key])
end

local function readStock(key: string): number
	local shared = map
	if shared then
		local ok, result = pcall(function()
			return shared:GetAsync(key)
		end)
		if ok then
			return if result == nil then Limited.STOCK else tonumber(result) or Limited.STOCK
		end
	end
	local own = localStock[key]
	return if own == nil then Limited.STOCK else own
end

-- Buys the current limited egg with coins. Returns (ok, message).
function LimitedService.buyWithCoins(player: Player): (boolean, string)
	local state = Session.get(player)
	if not state then
		return false, "not ready"
	end
	local now = rotation()
	local tier = Eggs.tier(now.tier)
	if not tier then
		return false, "no limited egg right now"
	end
	if state.coins < tier.price then
		return false, "not enough coins"
	end
	if Base.firstFree(state.base) == nil then
		return false, "your base is full!"
	end
	if LimitedService.claimStock(now.key) == nil then
		return false, "sold out! A new egg arrives soon"
	end
	-- the stock is taken; if paying fails now (coins spent while we waited), put the stock back
	if not Session.spend(player, tier.price) then
		releaseStock(now.key)
		return false, "not enough coins"
	end
	if not Session.grantEgg(player, tier.id) then
		Session.add(player, tier.price)
		releaseStock(now.key)
		return false, "your base is full!"
	end
	return true, `You got a {tier.name}!`
end

-- Hands out a limited egg paid for with Robux (the receipt already proved payment). Returns true if it was placed.
function LimitedService.grantPaid(player: Player, tierId: string): boolean
	return Session.grantEgg(player, tierId)
end

local function publish()
	local now = rotation()
	ReplicatedStorage:SetAttribute("LimitedTier", now.tier)
	ReplicatedStorage:SetAttribute("LimitedEnds", now.endsAt)
	ReplicatedStorage:SetAttribute("LimitedLeft", readStock(now.key))
end

function LimitedService.start(remotes: Folder, notifyFn: (Player, string) -> (), sfxAll: (string) -> ())
	notify = notifyFn
	local ok, result = pcall(function()
		return MemoryStoreService:GetHashMap("StealAMemeEgg_Limited")
	end)
	map = if ok and typeof(result) == "Instance" then result :: any else nil
	local buy = Instance.new("RemoteEvent")
	buy.Name = "BuyLimited"
	buy.Parent = remotes
	local last: { [Player]: number } = {}
	buy.OnServerEvent:Connect(function(player: Player)
		local t = os.clock()
		if t - (last[player] or -10) < 1 then
			return
		end
		last[player] = t
		local _, message = LimitedService.buyWithCoins(player)
		notify(player, message)
		publish()
	end)
	task.spawn(function()
		while true do
			local now = rotation()
			if now.index ~= lastSeen then
				local lastSeenBefore = if lastSeen >= 0 then lastSeen else nil
				lastSeen = now.index
				local tier = Eggs.tier(now.tier)
				if tier then
					if lastSeenBefore ~= nil then
						sfxAll("limited")
					end
					for _, player in game:GetService("Players"):GetPlayers() do
						notify(player, `New limited egg: {tier.name}!`)
					end
				end
			end
			publish()
			task.wait(5)
		end
	end)
end

return LimitedService
