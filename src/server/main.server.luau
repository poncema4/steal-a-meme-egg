--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Home = require(script.Parent.Home)
local LimitedService = require(script.Parent.LimitedService)
local LiveOps = require(script.Parent.LiveOps)
local Plots = require(script.Parent.Plots)
local PurchaseService = require(script.Parent.PurchaseService)
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

-- the client asks to drop its egg or switch Slow Mode; the server checks both
local dropRemote = Instance.new("RemoteEvent")
dropRemote.Name = "Drop"
dropRemote.Parent = remotes
local slowRemote = Instance.new("RemoteEvent")
slowRemote.Name = "SlowMode"
slowRemote.Parent = remotes

local sfxRemote = Instance.new("RemoteEvent")
sfxRemote.Name = "Sfx"
sfxRemote.Parent = remotes

-- sounds are sent by NAME; the client looks the asset id up in Config.Sounds
local function sfx(player: Player, name: string)
	sfxRemote:FireClient(player, name)
end

local function sfxAll(name: string)
	sfxRemote:FireAllClients(name)
end

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
Wilds.setSfx(sfx)
Wilds.start()
Home.setHooks(notify, sfx, function(player)
	local _, _, train = Session.passMultipliers(player)
	return train
end)
Home.start(world.plots)
Plots.setNotify(notify)
Wilds.setNestRate(LiveOps.nestRate)
dropRemote.OnServerEvent:Connect(function(player: Player)
	Wilds.drop(player)
end)
slowRemote.OnServerEvent:Connect(function(player: Player, on: any)
	if typeof(on) == "boolean" then
		Session.setSlow(player, on)
	end
end)
LiveOps.start(remotes, notify, sfxAll)
LimitedService.start(remotes, notify, sfxAll)
Session.onHatched(function(player)
	sfx(player, "hatch")
end)
Session.onDaily(function(player, streak, coins, egg)
	notify(player, `Daily reward, day {streak}: +{coins} coins{if egg then " and a free egg!" else ""}`)
	sfx(player, "deliver")
end)
PurchaseService.start(remotes, notify)
Plots.setInstant(PurchaseService.instantHatch, PurchaseService.instantAvailable)

Session.start(function(player)
	local plot = Plots.assign(player)
	if not plot then
		-- every base is taken (the place is set to 12 players, but a stale setting could let more in): do not leave them
		-- standing around with no base; say so, then send them to find another server
		notify(player, "This server is full: no free base. Rejoin to get another server!")
		task.delay(6, function()
			if table.find(Players:GetPlayers(), player) and not Plots.of(player) then
				player:Kick("This server is full (12 bases). Please rejoin to get another server.")
			end
		end)
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
