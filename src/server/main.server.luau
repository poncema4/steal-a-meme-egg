--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Conveyor = require(script.Parent.Conveyor)
local Home = require(script.Parent.Home)
local LiveOps = require(script.Parent.LiveOps)
local Plots = require(script.Parent.Plots)
local Raid = require(script.Parent.Raid)
local Session = require(script.Parent.Session)
local Wilds = require(script.Parent.Wilds)
local World = require(script.Parent.World)

print(`{Config.GameName} server v{Config.Version} started`)

local remotes = Instance.new("Folder")
remotes.Name = "Remotes"
remotes.Parent = ReplicatedStorage
local noticeRemote = Instance.new("RemoteEvent")
noticeRemote.Name = "Notice"
noticeRemote.Parent = remotes
local announceRemote = Instance.new("RemoteEvent")
announceRemote.Name = "Announce"
announceRemote.Parent = remotes

local function notify(player: Player, text: string)
	noticeRemote:FireClient(player, text)
end

Session.setClock(function()
	return workspace:GetServerTimeNow()
end)

local world = World.build()
Plots.start(world)
Wilds.build()
Wilds.setNotify(notify)
Wilds.start()
Home.setHooks(notify, function()
	return 1
end)
Home.start(world.plots)
Plots.setHandlers(Raid.steal, Raid.lock)
Raid.setNotify(notify)
Conveyor.setHooks(notify, LiveOps.luck, LiveOps.beltRate)
Conveyor.start()
LiveOps.start(remotes, notify)

Session.start(function(player)
	if not Plots.assign(player) then
		notify(player, "Server full: you have no base. Rejoin another server.")
	end
	Plots.refresh(player)
end, function(player)
	Plots.release(player)
end)

Players.CharacterAutoLoads = true
