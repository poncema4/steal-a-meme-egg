--!strict
-- What happens on your own base: the treadmill (train speed by running on it; its prompt upgrades it), the buy-slot and rebirth pads, and
-- delivering a stolen egg when you run home with it. The rules (costs, XP) are in Shared/Game/Progression and Economy.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local Economy = require(ReplicatedStorage.Shared.Game.Economy)
local Progression = require(ReplicatedStorage.Shared.Game.Progression)
local Rebirth = require(ReplicatedStorage.Shared.Game.Rebirth)
local Plots = require(script.Parent.Plots)
local Session = require(script.Parent.Session)
local World = require(script.Parent.World)

local Home = {}

local notify: (Player, string) -> () = function(_player: Player, _text: string) end
local sfx: (Player, string) -> () = function(_player: Player, _name: string) end
local trainMultiplier: (Player) -> number = function(_player: Player)
	return 1
end

function Home.setHooks(notifyFn: (Player, string) -> (), sfxFn: (Player, string) -> (), train: (Player) -> number)
	notify = notifyFn
	sfx = sfxFn
	trainMultiplier = train
end

-- Is this player standing on this plot's treadmill?
local function onTreadmill(root: BasePart, plot: World.Plot): boolean
	local s = plot.treadmill.Size
	local d = root.Position - plot.treadmill.Position
	-- the treadmill is turned with its pen: measure along the pen's own right and front directions
	local across = d.X * plot.right.X + d.Z * plot.right.Z
	local along = d.X * plot.front.X + d.Z * plot.front.Z
	return math.abs(across) <= s.X / 2 and math.abs(along) <= s.Z / 2 and d.Y >= 0 and d.Y <= 6
end

-- Is this player inside the walls of their own base?
local function insidePlot(root: BasePart, plot: World.Plot): boolean
	local d = root.Position - plot.center
	local across = d.X * plot.right.X + d.Z * plot.right.Z
	local along = d.X * plot.front.X + d.Z * plot.front.Z
	local half = World.PEN / 2 + 2
	return math.abs(across) <= half and math.abs(along) <= half
end

local function addPrompt(parent: BasePart, action: string, object: string, hold: number): ProximityPrompt
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = action
	prompt.ObjectText = object
	prompt.HoldDuration = hold
	prompt.MaxActivationDistance = 10
	prompt.RequiresLineOfSight = false
	prompt.Parent = parent
	return prompt
end

-- Keeps the prompts' price text right for whoever owns the plot.
local function refreshLabels(player: Player)
	local plot = Plots.of(player)
	local state = Session.get(player)
	if not plot or not state then
		return
	end
	local speed = plot.treadmill:FindFirstChildOfClass("ProximityPrompt")
	if speed then
		speed.ObjectText = if state.treadmill >= Progression.MAX_TREADMILL
			then "fully upgraded"
			else `level {state.treadmill + 1}: {Economy.format(Progression.treadmillCost(state.treadmill))} coins`
	end
	plot.display.level.Text = if state.treadmill >= Progression.MAX_TREADMILL
		then "MAX LEVEL"
		else `LEVEL {state.treadmill}`
	plot.display.rate.Text = `+{Economy.format(Progression.trainRate(state.treadmill, 1))} speed/s`
	local reborn = plot.rebirthPad:FindFirstChildOfClass("ProximityPrompt")
	if reborn then
		reborn.ObjectText = if state.rebirths >= Rebirth.MAX
			then "fully reborn"
			else `{Economy.format(Rebirth.cost(state.rebirths))} coins, x{Rebirth.multiplier(state.rebirths + 1)}`
	end
	local slot = plot.slotPad:FindFirstChildOfClass("ProximityPrompt")
	if slot then
		slot.ObjectText = if state.base.size >= Config.Economy.MaxSlots
			then "all slots"
			else `slot {state.base.size + 1}: {Economy.format(
				Economy.slotCost(state.base.size, Config.Economy.StartSlots, Config.Economy.SlotCostBase)
			)}`
	end
end

function Home.start(plots: { World.Plot })
	for _, plot in plots do
		local speed = addPrompt(plot.treadmill, "Upgrade treadmill", "", 0.4)
		speed.Triggered:Connect(function(who)
			if Plots.of(who) ~= plot then
				return
			end
			local ok, message = Session.upgradeTreadmill(who)
			notify(who, message)
			if ok then
				sfx(who, "coin")
			end
		end)
		local reborn = addPrompt(plot.rebirthPad, "Rebirth", "", 1.2)
		reborn.Triggered:Connect(function(who)
			if Plots.of(who) ~= plot then
				return
			end
			local ok, message = Session.rebirth(who)
			notify(who, message)
			if ok then
				sfx(who, "limited")
			end
		end)
		local slot = addPrompt(plot.slotPad, "Buy slot", "", 0.3)
		slot.Triggered:Connect(function(who)
			if Plots.of(who) ~= plot then
				return
			end
			local _, message = Session.buySlot(who)
			notify(who, message)
		end)
	end
	Session.onChanged(refreshLabels)

	local carry = 0
	RunService.Heartbeat:Connect(function(dt)
		carry += dt
		if carry < 0.25 then
			return
		end
		local step = carry
		carry = 0
		for _, player in Players:GetPlayers() do
			local plot = Plots.of(player)
			local character = player.Character
			local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
			if plot and root then
				local humanoid = character and character:FindFirstChildOfClass("Humanoid")
				local running = humanoid ~= nil and humanoid.MoveDirection.Magnitude > 0.1
				if onTreadmill(root, plot) then
					-- the belt carries you backward at about your own walking pace, so you have to keep running to stay on it
					local pace = if humanoid then humanoid.WalkSpeed * 0.9 else 0
					plot.treadmill.AssemblyLinearVelocity = Vector3.new(-plot.front.X * pace, 0, -plot.front.Z * pace)
					plot.treadmill:SetAttribute("BeltSpeed", if running then pace else 0)
					if running then
						Session.addSpeedXp(
							player,
							Progression.trainRate(Session.treadmillLevel(player), trainMultiplier(player)) * step
						)
					end
				else
					plot.treadmill.AssemblyLinearVelocity = Vector3.zero
					plot.treadmill:SetAttribute("BeltSpeed", 0)
				end
				if Session.carrying(player) and insidePlot(root, plot) then
					local ok, message = Session.deliver(player)
					notify(player, message)
					if ok then
						sfx(player, "deliver")
						Session.changed(player)
					end
				end
			end
		end
	end)
end

Home.onTreadmill = onTreadmill
Home.insidePlot = insidePlot

return Home
