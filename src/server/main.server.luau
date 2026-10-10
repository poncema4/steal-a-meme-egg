--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Conveyor = require(script.Parent.Conveyor)
local Home = require(script.Parent.Home)
local LimitedService = require(script.Parent.LimitedService)
local LiveOps = require(script.Parent.LiveOps)
local Plots = require(script.Parent.Plots)
local PurchaseService = require(script.Parent.PurchaseService)
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
Home.setHooks(notify, function(player)
	local _, _, train = Session.passMultipliers(player)
	return train
end)
Home.start(world.plots)
Plots.setHandlers(Raid.steal, Raid.lock)
Plots.setNotify(notify)
Raid.setNotify(notify)
Conveyor.setHooks(notify, LiveOps.luck, LiveOps.beltRate)
Conveyor.start()
LiveOps.start(remotes, notify)
LimitedService.start(remotes, notify)
PurchaseService.start(remotes, notify)
Plots.setInstant(PurchaseService.instantHatch, PurchaseService.instantAvailable)

Session.start(function(player)
	local plot = Plots.assign(player)
	if not plot then
		notify(player, "Server full: you have no base. Rejoin another server.")
	else
		-- the first character may already have spawned at someone else's plot while the save loaded: bring it home
		local character = player.Character
		if character then
			character:PivotTo(plot.spawn.CFrame + Vector3.new(0, 5, 0))
		end
	end
	Plots.refresh(player)
end, function(player)
	Plots.release(player)
end)

Players.CharacterAutoLoads = true
