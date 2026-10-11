--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Badges = require(script.Parent.Badges)
local BatTool = require(script.Parent.BatTool)
local Carry = require(script.Parent.Carry)
local Home = require(script.Parent.Home)
local LimitedService = require(script.Parent.LimitedService)
local LiveOps = require(script.Parent.LiveOps)
local Plots = require(script.Parent.Plots)
local PurchaseService = require(script.Parent.PurchaseService)
local Session = require(script.Parent.Session)
local Traps = require(script.Parent.Traps)
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
local leaveRemote = Instance.new("RemoteEvent")
leaveRemote.Name = "LeaveTreadmill"
leaveRemote.Parent = remotes
local slowRemote = Instance.new("RemoteEvent")
slowRemote.Name = "SlowMode"
slowRemote.Parent = remotes

-- the Eggs panel's Instant button (the same action as the prompt on the egg itself)
local baseRemote = Instance.new("RemoteEvent")
baseRemote.Name = "BaseAction"
baseRemote.Parent = remotes

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
Wilds.setNestRate(LiveOps.nestRate)
Traps.start(remotes, notify, sfx)
Badges.start()
BatTool.setHooks(notify, sfx)
BatTool.start()
Carry.start()
dropRemote.OnServerEvent:Connect(function(player: Player)
	Wilds.drop(player)
end)
-- a click or tap on the ground of your pen while carrying an egg puts it there (the server checks it is your pen)
local placeRemote = Instance.new("RemoteEvent")
placeRemote.Name = "PlaceEgg"
placeRemote.Parent = remotes
placeRemote.OnServerEvent:Connect(function(player: Player, at: any)
	if typeof(at) ~= "Vector3" or at.X ~= at.X or at.Z ~= at.Z or at.Magnitude > 1e6 then
		return
	end
	Home.placeEgg(player, at)
end)
baseRemote.OnServerEvent:Connect(function(player: Player, kind: any, slot: any)
	if typeof(slot) ~= "number" or slot ~= slot or slot % 1 ~= 0 or slot < 1 or slot > 12 then
		return
	end
	-- hatching can only be sped up with Robux (an Instant hatch, or a hatch token bought with them): never with coins
	if kind == "instant" then
		PurchaseService.instantHatch(player, slot)
	end
end)
leaveRemote.OnServerEvent:Connect(function(player: Player)
	Home.leave(player)
end)
slowRemote.OnServerEvent:Connect(function(player: Player, on: any)
	if typeof(on) == "boolean" then
		Session.setSlow(player, on)
	end
end)
LiveOps.start(remotes, notify, sfxAll)
LimitedService.start(remotes, notify, sfxAll)
Session.onHatched(function(player, slots)
	sfx(player, "hatch")
	Plots.hatchBurst(player, slots)
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
		-- every base is taken (the place is set to 8 players, but a stale setting could let more in): do not leave them
		-- standing around with no base; say so, then send them to find another server
		notify(player, "This server is full: no free base. Rejoin to get another server!")
		task.delay(6, function()
			if table.find(Players:GetPlayers(), player) and not Plots.of(player) then
				player:Kick("This server is full (8 bases). Please rejoin to get another server.")
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
