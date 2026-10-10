--!strict
-- Sound on the client: a quiet looping tune, and the effects the server asks for by NAME (the server never sends an asset id;
-- the ids live in Config.Sounds). One remote, "Sfx", carries every effect.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config)

local Audio = {}

local MUSIC_VOLUME = 0.22
local SFX_VOLUME = 0.7

local sounds = Config.Sounds :: { [string]: string }

local function play(name: string)
	local id = sounds[name]
	if not id then
		return
	end
	local sound = Instance.new("Sound")
	sound.Name = `Sfx_{name}`
	sound.SoundId = id
	sound.Volume = SFX_VOLUME
	sound.Parent = SoundService
	sound:Play()
	task.delay(5, function()
		sound:Destroy()
	end)
end

function Audio.play(name: string)
	play(name)
end

-- The tune follows where you are: a calm loop in the Safe Zone, a driving one out in the Wilds; they cross-fade.
function Audio.start()
	local function loop(name: string, id: string, volume: number): Sound
		local music = Instance.new("Sound")
		music.Name = name
		music.SoundId = id
		music.Volume = volume
		music.Looped = true
		music.Parent = SoundService
		return music
	end
	local safe = loop("Music", sounds.music, MUSIC_VOLUME)
	local wilds = loop("MusicWilds", sounds.musicWilds or sounds.music, 0)
	safe:Play()
	wilds:Play()
	local player = Players.LocalPlayer
	local function follow()
		local inWilds = player ~= nil
			and player:GetAttribute("Zone") ~= nil
			and player:GetAttribute("Zone") ~= "Safe Zone"
		TweenService:Create(safe, TweenInfo.new(1.5), { Volume = if inWilds then 0 else MUSIC_VOLUME }):Play()
		TweenService:Create(wilds, TweenInfo.new(1.5), { Volume = if inWilds then MUSIC_VOLUME else 0 }):Play()
	end
	if player then
		player:GetAttributeChangedSignal("Zone"):Connect(follow)
	end

	local remotes = ReplicatedStorage:WaitForChild("Remotes")
	local sfx = remotes:WaitForChild("Sfx") :: RemoteEvent
	sfx.OnClientEvent:Connect(function(name: any)
		if typeof(name) == "string" then
			play(name)
		end
	end)
end

return Audio
