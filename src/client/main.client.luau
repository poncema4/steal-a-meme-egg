--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Audio = require(script.Parent.Audio)
local Hud = require(script.Parent.Hud)
local Shop = require(script.Parent.Shop)

print(`{Config.GameName} client v{Config.Version} started`)
Hud.start(Players.LocalPlayer)
Audio.start()
Shop.start(Players.LocalPlayer)
