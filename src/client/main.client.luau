--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local AdminCommands = require(script.Parent.AdminCommands)
local Audio = require(script.Parent.Audio)
local CarryPose = require(script.Parent.CarryPose)
local Floaters = require(script.Parent.Floaters)
local Hud = require(script.Parent.Hud)
local Panels = require(script.Parent.Panels)
local PlaceEgg = require(script.Parent.PlaceEgg)
local Prompts = require(script.Parent.Prompts)
local Roam = require(script.Parent.Roam)
local Shop = require(script.Parent.Shop)
local TreadmillRun = require(script.Parent.TreadmillRun)
local Treadmills = require(script.Parent.Treadmills)

print(`{Config.GameName} client v{Config.Version} started`)
Prompts.start(Players.LocalPlayer)
Audio.start()
AdminCommands.start(Players.LocalPlayer)
CarryPose.start()
Treadmills.start()
Floaters.start()
Roam.start()
PlaceEgg.start(Players.LocalPlayer)
TreadmillRun.start(Players.LocalPlayer)
Shop.start(Players.LocalPlayer)
local panels = Panels.start(Players.LocalPlayer)
Hud.start(
	Players.LocalPlayer,
	{ shop = Shop.toggle, index = panels.index, eggs = panels.eggs, pets = panels.pets, trophy = panels.trophy }
)
