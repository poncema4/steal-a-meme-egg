--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Audio = require(script.Parent.Audio)
local Hud = require(script.Parent.Hud)
local Panels = require(script.Parent.Panels)
local Prompts = require(script.Parent.Prompts)
local Shop = require(script.Parent.Shop)

print(`{Config.GameName} client v{Config.Version} started`)
Prompts.start(Players.LocalPlayer)
Audio.start()
Shop.start(Players.LocalPlayer)
local panels = Panels.start(Players.LocalPlayer)
Hud.start(Players.LocalPlayer, { shop = Shop.toggle, index = panels.index, eggs = panels.eggs, pets = panels.pets })
