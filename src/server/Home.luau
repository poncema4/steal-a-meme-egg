--!strict
-- What happens on your own base: the treadmill (train speed by running on it; its prompt upgrades it), the buy-slot and rebirth pads, and
-- delivering a stolen egg when you run home with it. The rules (costs, XP) are in Shared/Game/Progression and Economy.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local Economy = require(ReplicatedStorage.Shared.Game.Economy)
local Belt = require(ReplicatedStorage.Shared.Game.Belt)
local Progression = require(ReplicatedStorage.Shared.Game.Progression)
local Rebirth = require(ReplicatedStorage.Shared.Game.Rebirth)
local Plots = require(script.Parent.Plots)
local Session = require(script.Parent.Session)
local TreadmillPaint = require(script.Parent.TreadmillPaint)
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
local function insidePen(position: Vector3, plot: World.Plot, margin: number): boolean
	local d = position - plot.center
	local across = d.X * plot.right.X + d.Z * plot.right.Z
	local along = d.X * plot.front.X + d.Z * plot.front.Z
	local half = World.PEN / 2 + margin
	return math.abs(across) <= half and math.abs(along) <= half
end

local function insidePlot(root: BasePart, plot: World.Plot): boolean
	return insidePen(root.Position, plot, 2)
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
	TreadmillPaint.apply(plot, state.treadmill)
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

-- The treadmill lock: while you are on your belt the game runs for you (no keys to hold) until you jump off.
local locked: { [Player]: boolean } = {}
local freeUntil: { [Player]: number } = {}
local JUMP_OFF_SPEED = 12 -- upward studs per second that count as a jump
local GROUNDED_SPEED = 8 -- you cannot be locked while flying through the air
local RELOCK_SECONDS = 1.6 -- after jumping off you can walk over the belt without being caught again at once

local function lock(player: Player, plot: World.Plot, root: BasePart)
	locked[player] = true
	-- put the runner on the middle of the belt, facing the front, so the belt carries them straight
	local belt = plot.treadmill
	local d = root.Position - belt.Position
	local along = d.X * plot.front.X + d.Z * plot.front.Z
	local spot = belt.Position
		+ Vector3.new(plot.front.X * along, root.Position.Y - belt.Position.Y, plot.front.Z * along)
	root.CFrame = CFrame.lookAt(spot, spot + plot.front)
	player:SetAttribute("TreadmillFront", plot.front)
	player:SetAttribute("TreadmillLocked", true)
end

function Home.unlock(player: Player)
	locked[player] = nil
	freeUntil[player] = os.clock() + RELOCK_SECONDS
	player:SetAttribute("TreadmillLocked", false)
end

function Home.isLocked(player: Player): boolean
	return locked[player] == true
end

-- The client asked to jump off (a jump key or the Jump off button): only counts if they really are on the belt.
function Home.leave(player: Player)
	if not locked[player] then
		return
	end
	Home.unlock(player)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local plot = Plots.of(player)
	if root and plot then
		root.AssemblyLinearVelocity = Vector3.new(plot.front.X * 12, 55, plot.front.Z * 12)
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
		if carry < 0.1 then
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
				local now = os.clock()
				-- stepping onto your belt locks you on it; carrying an egg, dying or a jump takes you off
				if locked[player] then
					local alive = humanoid ~= nil and humanoid.Health > 0
					if
						not alive
						or not onTreadmill(root, plot)
						or Session.carrying(player) ~= nil
						or root.AssemblyLinearVelocity.Y > JUMP_OFF_SPEED
					then
						Home.unlock(player)
					end
				elseif
					onTreadmill(root, plot)
					and humanoid ~= nil
					and humanoid.Health > 0
					and now >= (freeUntil[player] or 0)
					and Session.carrying(player) == nil
					and root.AssemblyLinearVelocity.Y < GROUNDED_SPEED
				then
					lock(player, plot, root)
				end
				if locked[player] then
					-- the belt carries you backward exactly as fast as you run (a little more when you creep toward the front edge, a
					-- little less when you slip back), so you stay in the middle and train for as long as you like
					local belt = plot.treadmill
					local away = root.Position - belt.Position
					local ahead = away.X * plot.front.X + away.Z * plot.front.Z
					local pace = if humanoid then Belt.pace(humanoid.WalkSpeed, ahead) else 0
					plot.treadmill.AssemblyLinearVelocity = Vector3.new(-plot.front.X * pace, 0, -plot.front.Z * pace)
					plot.treadmill:SetAttribute("BeltSpeed", pace)
					Session.addSpeedXp(
						player,
						Progression.trainRate(Session.treadmillLevel(player), trainMultiplier(player)) * step
					)
				else
					plot.treadmill.AssemblyLinearVelocity = Vector3.zero
					plot.treadmill:SetAttribute("BeltSpeed", 0)
				end
				-- in your own pen the egg is NOT put down by itself: you pick the spot and press Place egg (Home.placeEgg)
				local inPen = insidePlot(root, plot)
				if player:GetAttribute("InPen") ~= inPen then
					player:SetAttribute("InPen", inPen)
				end
			end
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		locked[player] = nil
		freeUntil[player] = nil
	end)
end

-- The player clicked or tapped a spot in their pen while carrying an egg (`at` is where the click hit the ground; nil means
-- where they stand): the egg goes down there. Only inside their own pen and only while they are in it; eggs never overlap (a
-- spot too close to another egg moves to the nearest clear one). Returns true if the egg was placed.
function Home.placeEgg(player: Player, at: Vector3?): boolean
	local plot = Plots.of(player)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not plot or not root or not Session.carrying(player) or not insidePlot(root, plot) then
		return false
	end
	local point = at or root.Position
	if not insidePen(point, plot, 0) then
		notify(player, "Put the egg inside your pen!")
		return false
	end
	local d = point - plot.center
	local ok, message = Session.deliver(player, {
		x = d.X * plot.right.X + d.Z * plot.right.Z,
		z = d.X * plot.front.X + d.Z * plot.front.Z,
	})
	notify(player, message)
	if ok then
		sfx(player, "deliver")
		Session.changed(player)
	end
	return ok
end

Home.onTreadmill = onTreadmill
Home.insidePlot = insidePlot

return Home
