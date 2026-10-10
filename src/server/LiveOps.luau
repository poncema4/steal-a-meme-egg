--!strict
-- Live events and admin tools. Three ways an event starts: the half-hourly schedule (every server agrees because it only
-- needs the clock), an admin command in chat, or a message from another server so an admin's event reaches EVERY server.
-- What the events do (luck, income, egg rain) lives in Shared/Game/Events; who may run commands is Shared/Game/Admin.
local GroupService = game:GetService("GroupService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Admin = require(ReplicatedStorage.Shared.Game.Admin)
local Config = require(ReplicatedStorage.Shared.Config)
local Events = require(ReplicatedStorage.Shared.Game.Events)
local Session = require(script.Parent.Session)

local LiveOps = {}

local TOPIC = "RaidLive"
local state = Events.new()
local remotes: Folder? = nil
local crossServer = false
local sfxAll: (string) -> () = function(_name: string) end

function LiveOps.state(): Events.State
	return state
end

function LiveOps.luck(): number
	local luck = Events.multipliers(state, Session.now())
	return luck
end

function LiveOps.income(): number
	local _, income = Events.multipliers(state, Session.now())
	return income
end

-- Egg Rain makes empty nests grow their eggs back six times as fast.
function LiveOps.nestRate(): number
	for _, id in Events.active(state, Session.now()) do
		if Events.Defs[id].eggRain then
			return 6
		end
	end
	return 1
end

local function announce(text: string)
	sfxAll("horn")
	local folder = remotes
	if folder then
		local remote = folder:FindFirstChild("Announce")
		if remote and remote:IsA("RemoteEvent") then
			remote:FireAllClients(text)
		end
	end
end

local function publish()
	local parts = {}
	for _, id in Events.active(state, Session.now()) do
		table.insert(parts, `{id}:{state.ends[id]}`)
	end
	ReplicatedStorage:SetAttribute("ActiveEvents", table.concat(parts, ","))
	local nextId, wait = Events.nextAfter(Session.now(), Config.Events.PeriodSeconds)
	ReplicatedStorage:SetAttribute("NextEvent", `{nextId}:{Session.now() + wait}`)
end

-- Applies an action on THIS server.
local function apply(action: { [string]: any })
	local kind = action.kind
	if kind == "event" then
		local id = tostring(action.id)
		if Events.start(state, id, Session.now(), tonumber(action.seconds)) then
			announce(`{Events.Defs[id].name} has started!`)
		end
	elseif kind == "giveAll" then
		local coins = tonumber(action.coins) or 0
		for _, player in Players:GetPlayers() do
			Session.add(player, coins)
		end
		announce(`Giveaway! Everyone got {coins} coins`)
	elseif kind == "announce" then
		announce(tostring(action.text))
	elseif kind == "clearEvents" then
		Events.clear(state)
	end
	publish()
end

-- Sends an action to every server (or just applies it here when cross-server messaging is not available).
local function dispatch(action: { [string]: any })
	if crossServer then
		local MessagingService = game:GetService("MessagingService")
		local ok = pcall(function()
			MessagingService:PublishAsync(TOPIC, action)
		end)
		if ok then
			return
		end
	end
	apply(action)
end
LiveOps.dispatch = dispatch

function LiveOps.isAdmin(player: Player): boolean
	if RunService:IsStudio() then
		return true -- solo testing in Studio: you are the owner
	end
	local rank = 0
	local ok, groups = pcall(function()
		return GroupService:GetGroupsAsync(player.UserId)
	end)
	if ok then
		for _, group in groups do
			if group.Id == Config.GroupId then
				rank = group.Rank
			end
		end
	end
	return Admin.isAdmin(player.UserId, rank, Config.Admin.MinGroupRank, Config.Admin.UserIds)
end

-- Runs one chat line from a player; returns the reply to show them.
function LiveOps.command(player: Player, text: string): string
	local result = Admin.run(text, LiveOps.isAdmin(player))
	local action = result.action
	if result.ok and action then
		if action.kind == "give" then
			Session.add(player, action.coins)
		elseif action.kind ~= "help" then
			dispatch(action :: any)
		end
	end
	return result.message
end

local function registerChat(tell: (Player, string) -> ())
	local ok, TextChatService = pcall(function()
		return game:GetService("TextChatService")
	end)
	if not ok or typeof(TextChatService) ~= "Instance" then
		return
	end
	for _, name in { "event", "give", "giveall", "announce", "clear", "help" } do
		local command = Instance.new("TextChatCommand")
		command.Name = `RaidAdmin_{name}`
		command.PrimaryAlias = `/{name}`
		command.Parent = TextChatService
		command.Triggered:Connect(function(source, text)
			local player = Players:GetPlayerByUserId(source.UserId)
			if player then
				tell(player, LiveOps.command(player, text))
			end
		end)
	end
end

function LiveOps.start(remoteFolder: Folder, tell: (Player, string) -> (), sfxAllFn: (string) -> ())
	remotes = remoteFolder
	sfxAll = sfxAllFn
	Session.setMultipliers(function()
		return LiveOps.luck(), LiveOps.income()
	end)
	local okSub = pcall(function()
		local MessagingService = game:GetService("MessagingService")
		MessagingService:SubscribeAsync(TOPIC, function(message)
			local data = message.Data
			if type(data) == "table" then
				apply(data)
			end
		end)
	end)
	crossServer = okSub
	registerChat(tell)
	-- the schedule: start whatever the clock says should be running, once a second
	task.spawn(function()
		while true do
			local now = Session.now()
			local id, ends = Events.scheduledAt(now, Config.Events.PeriodSeconds, Config.Events.ClaimSeconds)
			if id and not state.ends[id] then
				Events.start(state, id, now, ends - now)
				announce(`{Events.Defs[id].name} has started!`)
			end
			publish()
			task.wait(1)
		end
	end)
end

return LiveOps
