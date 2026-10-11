--!strict
-- Limited eggs: the egg on sale this half hour, its shared stock, and buying it. Stock is one counter per rotation in
-- MemoryStore (shared by every server); if MemoryStore is unavailable (Studio, an outage) each server keeps its own count.
-- The rules (which egg, how stock moves) are in Shared/Game/Limited; this file only talks to Roblox.
local MemoryStoreService = game:GetService("MemoryStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

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

-- Hands out a limited egg paid for with Robux (the receipt already proved payment). Returns true if it was placed.
function LimitedService.grantPaid(player: Player, tierId: string): boolean
	-- a paid egg takes one from the shared stock (the button is hidden once it is sold out; a purchase already paid for is always
	-- honoured, even if the last one went in the meantime)
	local now = rotation()
	if now.tier == tierId then
		LimitedService.claimStock(now.key)
	end
	return Session.grantEgg(player, tierId)
end

local function publish()
	local now = rotation()
	ReplicatedStorage:SetAttribute("LimitedTier", now.tier)
	ReplicatedStorage:SetAttribute("LimitedEnds", now.endsAt)
	ReplicatedStorage:SetAttribute("LimitedLeft", readStock(now.key))
end

function LimitedService.start(_remotes: Folder, notifyFn: (Player, string) -> (), sfxAll: (string) -> ())
	notify = notifyFn
	local ok, result = pcall(function()
		return MemoryStoreService:GetHashMap("StealAMemeEgg_Limited")
	end)
	map = if ok and typeof(result) == "Instance" then result :: any else nil
	-- limited eggs are sold for Robux only (Marco): there is no coin purchase
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
