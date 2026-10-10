--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Hud = require(script.Parent.Hud)
local Shop = require(script.Parent.Shop)

print(`{Config.GameName} client v{Config.Version} started`)
Hud.start(Players.LocalPlayer)
Shop.start(Players.LocalPlayer)
