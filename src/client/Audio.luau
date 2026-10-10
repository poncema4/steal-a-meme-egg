--!strict
-- Sound on the client: a quiet looping tune, and the effects the server asks for by NAME (the server never sends an asset id;
-- the ids live in Config.Sounds). One remote, "Sfx", carries every effect.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")

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

function Audio.start()
	local music = Instance.new("Sound")
	music.Name = "Music"
	music.SoundId = sounds.music
	music.Volume = MUSIC_VOLUME
	music.Looped = true
	music.Parent = SoundService
	music:Play()

	local remotes = ReplicatedStorage:WaitForChild("Remotes")
	local sfx = remotes:WaitForChild("Sfx") :: RemoteEvent
	sfx.OnClientEvent:Connect(function(name: any)
		if typeof(name) == "string" then
			play(name)
		end
	end)
end

return Audio
