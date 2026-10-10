--!strict
-- The belt: eggs ride from one end to the other and anyone can buy the one in front of them. Prices and odds come
-- from Shared/Game/Eggs; this file only moves parts and takes the money.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Base = require(ReplicatedStorage.Shared.Game.Base)
local Config = require(ReplicatedStorage.Shared.Config)
local Economy = require(ReplicatedStorage.Shared.Game.Economy)
local Eggs = require(ReplicatedStorage.Shared.Game.Eggs)
local Session = require(script.Parent.Session)
local World = require(script.Parent.World)

local Conveyor = {}

type Riding = { part: BasePart, born: number, tier: string }

local COLORS: { [string]: Color3 } = {
	Soggy = Color3.fromRGB(235, 225, 190),
	Disco = Color3.fromRGB(255, 120, 220),
	Spicy = Color3.fromRGB(255, 90, 40),
	Golden = Color3.fromRGB(255, 205, 40),
	Cosmic = Color3.fromRGB(110, 90, 255),
	Divine = Color3.fromRGB(255, 255, 255),
}

local riding: { Riding } = {}
local notify: (Player, string) -> () = function(_player: Player, _text: string) end
local luckOf: () -> number = function()
	return 1
end
local rateOf: () -> number = function()
	return 1
end

function Conveyor.setHooks(notifyFn: (Player, string) -> (), luck: () -> number, rate: () -> number)
	notify = notifyFn
	luckOf = luck
	rateOf = rate
end

local function buy(player: Player, egg: Riding)
	local tier = Eggs.tier(egg.tier)
	local state = Session.get(player)
	if not tier or not state or not egg.part.Parent then
		return
	end
	if Base.firstFree(state.base) == nil then
		notify(player, "Your base is full! Buy a slot or steal less.")
		return
	end
	if not Session.spend(player, tier.price) then
		notify(player, `You need {Economy.format(tier.price)} coins`)
		return
	end
	Base.placeEgg(state.base, egg.tier)
	egg.part:Destroy()
	Session.changed(player)
end

function Conveyor.spawn(tierId: string?)
	if #riding >= Config.Conveyor.MaxEggs then
		return
	end
	local id = tierId or Eggs.conveyorTier(luckOf(), math.random)
	local tier = Eggs.tier(id)
	if not tier then
		return
	end
	local part = Instance.new("Part")
	part.Name = "BeltEgg"
	part.Shape = Enum.PartType.Ball
	part.Size = Vector3.new(4, 5, 4)
	part.Color = COLORS[id] or Color3.new(1, 1, 1)
	part.Anchored = true
	part.CanCollide = false
	part.CFrame = CFrame.new(-World.BELT_LENGTH / 2, 3.5, World.BELT_Z)
	part.Parent = workspace
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(170, 44)
	gui.StudsOffset = Vector3.new(0, 4, 0)
	gui.AlwaysOnTop = true
	gui.MaxDistance = 60
	gui.Parent = part
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextStrokeTransparency = 0.3
	label.Text = `{tier.name}\n{Economy.format(tier.price)}`
	label.Parent = gui
	local entry: Riding = { part = part, born = os.clock(), tier = id }
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Buy"
	prompt.ObjectText = tier.name
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 12
	prompt.RequiresLineOfSight = false
	prompt.Parent = part
	prompt.Triggered:Connect(function(who)
		buy(who, entry)
	end)
	table.insert(riding, entry)
end

function Conveyor.count(): number
	return #riding
end

function Conveyor.start()
	local sinceSpawn = 0
	RunService.Heartbeat:Connect(function(dt)
		sinceSpawn += dt
		if sinceSpawn >= Config.Conveyor.SpawnSeconds / math.max(rateOf(), 0.1) then
			sinceSpawn = 0
			Conveyor.spawn()
		end
		local now = os.clock()
		for i = #riding, 1, -1 do
			local egg = riding[i]
			local t = (now - egg.born) / Config.Conveyor.TravelSeconds
			if t >= 1 or not egg.part.Parent then
				egg.part:Destroy()
				table.remove(riding, i)
			else
				egg.part.CFrame = CFrame.new(-World.BELT_LENGTH / 2 + World.BELT_LENGTH * t, 3.5, World.BELT_Z)
			end
		end
	end)
end

return Conveyor
