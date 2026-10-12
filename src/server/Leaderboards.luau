--!strict
-- Keeps the global top-10 boards: every minute each player's best Speed, Money and Rebirths are written to Roblox ordered data
-- stores (shared by every server), then the top 10 of each is read back and published on ReplicatedStorage ("Top_Speed",
-- "Top_Money", "Top_Rebirths") for the Trophy panel. Every call to Roblox is protected: if the data stores are down (or
-- Studio has no API access) the boards simply stay as they were.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DataStoreService = game:GetService("DataStoreService")

local TopList = require(ReplicatedStorage.Shared.Game.TopList)
local Session = require(script.Parent.Session)

local Leaderboards = {}

Leaderboards.PERIOD = 60
local stores: { [string]: any } = {}
local names: { [number]: string } = {}

local function store(board: string): any
	if not stores[board] then
		local ok, s = pcall(function()
			return DataStoreService:GetOrderedDataStore(`Top_{board}_v1`)
		end)
		stores[board] = if ok then s else false
	end
	return stores[board] or nil
end

-- What a player scores on each board right now.
function Leaderboards.values(player: Player): { [string]: number }
	local state = Session.get(player)
	return {
		Speed = (player:GetAttribute("SpeedStat") :: number?) or 0,
		Money = if state then state.coins else 0,
		Rebirths = if state then state.rebirths else 0,
	}
end

local function nameOf(userId: number): string
	if names[userId] then
		return names[userId]
	end
	local online = Players:GetPlayerByUserId(userId)
	local name = online and online.Name
	if not name then
		local ok, found = pcall(function()
			return Players:GetNameFromUserIdAsync(userId)
		end)
		name = if ok and typeof(found) == "string" then found else `Player{userId}`
	end
	names[userId] = name :: string
	return name :: string
end

-- Writes everyone's scores, then reads and publishes the three top-10 boards.
function Leaderboards.refresh()
	for _, player in Players:GetPlayers() do
		if Session.get(player) then
			for board, value in Leaderboards.values(player) do
				local s = store(board)
				if s then
					pcall(function()
						s:SetAsync(tostring(player.UserId), TopList.encode(value))
					end)
				end
			end
		end
	end
	for _, board in TopList.BOARDS do
		local s = store(board)
		if s then
			local ok, page = pcall(function()
				return s:GetSortedAsync(false, TopList.SIZE):GetCurrentPage()
			end)
			if ok and typeof(page) == "table" then
				local entries = {}
				for _, row in page do
					local userId = tonumber(row.key)
					if userId then
						table.insert(entries, { name = nameOf(userId), value = TopList.decode(row.value) })
					end
				end
				ReplicatedStorage:SetAttribute(`Top_{board}`, TopList.pack(entries))
			end
		end
	end
end

function Leaderboards.start()
	task.spawn(function()
		task.wait(5)
		while true do
			Leaderboards.refresh()
			task.wait(Leaderboards.PERIOD)
		end
	end)
	-- a player who leaves is written once more, so their score is never lost between refreshes
	Players.PlayerRemoving:Connect(function(player)
		for board, value in Leaderboards.values(player) do
			local s = store(board)
			if s then
				pcall(function()
					s:SetAsync(tostring(player.UserId), TopList.encode(value))
				end)
			end
		end
	end)
end

return Leaderboards
