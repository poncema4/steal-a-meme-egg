--!strict
-- Gives each player a base plot and keeps its parts in step with their Base state: eggs that count down, characters that
-- glow by mutation. Visuals are plain parts (no meshes) so Rojo carries everything.
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Economy = require(ReplicatedStorage.Shared.Game.Economy)
local Eggs = require(ReplicatedStorage.Shared.Game.Eggs)
local Look = require(script.Parent.Look)
local Models = require(script.Parent.Models)
local Session = require(script.Parent.Session)
local World = require(script.Parent.World)

local ROAM_RADIUS = 12 -- studs: pets roam the whole pen (it is 40 across; the front strip holds the pads and the spawn)
local ROAM_CENTRE_FRONT = -3 -- the roaming area's centre, a little behind the middle of the pen

local Plots = {}

local RARITY_COLORS: { [string]: Color3 } = {
	Common = Color3.fromRGB(200, 200, 200),
	Rare = Color3.fromRGB(80, 160, 255),
	Epic = Color3.fromRGB(190, 90, 255),
	Legendary = Color3.fromRGB(255, 170, 40),
	Mythic = Color3.fromRGB(255, 70, 90),
}

local plots: { World.Plot } = {}
local owned: { [Player]: World.Plot } = {}
local onInstant: (Player, number) -> () = function(_player: Player, _slot: number) end
local instantAvailable: (Player) -> boolean = function(_player: Player)
	return false
end

function Plots.setInstant(handler: (Player, number) -> (), available: (Player) -> boolean)
	onInstant = handler
	instantAvailable = available
end

function Plots.of(player: Player): World.Plot?
	return owned[player]
end

local function tag(parent: Instance, lines: { string }, offset: number): BillboardGui
	local gui = Instance.new("BillboardGui")
	gui.Name = "Tag"
	gui.Size = UDim2.fromOffset(180, 20 * #lines + 6)
	gui.StudsOffset = Vector3.new(0, offset, 0)
	gui.AlwaysOnTop = true
	gui.MaxDistance = 70
	gui.Parent = parent
	for i, text in lines do
		local label = Instance.new("TextLabel")
		label.Name = `L{i}`
		label.Size = UDim2.new(1, 0, 0, 20)
		label.Position = UDim2.fromOffset(0, (i - 1) * 20)
		label.BackgroundTransparency = 1
		label.Font = Enum.Font.FredokaOne
		label.TextScaled = true
		label.TextColor3 = Color3.new(1, 1, 1)
		label.TextStrokeTransparency = 0.3
		label.Text = text
		label.Parent = gui
	end
	return gui
end

local function clearSlot(pedestal: BasePart)
	local old = pedestal:FindFirstChild("Item")
	if old then
		old:Destroy()
	end
end

local function drawSlot(owner: Player, plot: World.Plot, n: number)
	local state = Session.get(owner)
	local pedestal = plot.slots[n]
	clearSlot(pedestal)
	if not state then
		return
	end
	pedestal.Transparency = if n > state.base.size then 0.8 else 0
	pedestal.CanCollide = true
	local item = state.base.slots[n]
	if not item then
		return
	end
	local model = Instance.new("Model")
	model.Name = "Item"
	local body = Instance.new("Part")
	body.Name = "Body"
	body.Anchored = true
	body.CanCollide = false
	if item.kind == "egg" and item.tier then
		World.roundify(body)
		body.Size = Vector3.new(4, 5, 4)
		local mutated = Look.isMutated(item.eggMutation)
		body.Color = Look.eggColor(item.tier, item.eggMutation)
		body.Material = if mutated then Enum.Material.Neon else Enum.Material.SmoothPlastic
		body.CFrame = pedestal.CFrame + Vector3.new(0, 3.2, 0)
		body.Parent = model
		if Models.has("Eggs", item.tier) then
			body.CFrame = pedestal.CFrame + Vector3.new(0, 3, 0) -- the model stands right on the pedestal
			Models.show(body, "Eggs", item.tier, item.eggMutation, plot.front)
			body.Transparency = 1
		end
		local tier = Eggs.tier(item.tier)
		tag(body, {
			(if mutated then `{item.eggMutation} ` else "") .. (if tier then tier.name else "Egg"),
			`hatching {math.ceil(item.hatchLeft or 0)}s`,
		}, 3.4)
		if tier then
			if instantAvailable(owner) then
				local instant = Instance.new("ProximityPrompt")
				instant.ActionText = "Instant hatch"
				instant.ObjectText = if Session.hatchTokens(owner) > 0
					then `{Session.hatchTokens(owner)} left`
					else "Robux"
				instant.KeyboardKeyCode = Enum.KeyCode.F
				instant.GamepadKeyCode = Enum.KeyCode.ButtonY
				instant.UIOffset = Vector2.new(0, 70)
				instant.HoldDuration = 0.4
				instant.MaxActivationDistance = 10
				instant.RequiresLineOfSight = false
				instant.Parent = body
				instant.Triggered:Connect(function(who)
					if who == owner then
						onInstant(owner, n)
					end
				end)
			end
		end
	else
		local c = Eggs.character(item.id or "")
		local art = (Config.PetIcons :: { [string]: string })[item.id or ""]
		local mutation = item.mutation or "Normal"
		local label = (if mutation ~= "Normal" then `{mutation} ` else "") .. (if c then c.name else "?")
		local per = if c then c.income * (Eggs.Mutations[mutation] or 1) else 0
		body.Size = Vector3.new(3.5, 4.5, 2.5)
		body.CFrame = pedestal.CFrame + Vector3.new(0, 3.2, 0)
		body.Parent = model
		if item.id and Models.has("Pets", item.id) then
			-- a pet is not tied to its pedestal: the pedestal disappears and the pet walks around the whole pen, standing on the
			-- grass (the pedestal top is a stud above the floor)
			pedestal.Transparency = 1
			pedestal.CanCollide = false
			body.CFrame = pedestal.CFrame + Vector3.new(0, 1.75, 0)
			Models.show(body, "Pets", item.id, mutation, plot.front)
			body.Transparency = 1
			tag(body, { label, `+{Economy.format(per)}/s` }, 7)
			-- every client works out the same walk from the shared clock (see client/Roam)
			model:SetAttribute("RoamSeed", n + 13 * plot.index)
			model:SetAttribute("RoamRadius", ROAM_RADIUS)
			model:SetAttribute("RoamCentre", plot.center + plot.front * ROAM_CENTRE_FRONT)
			model.Parent = pedestal
			CollectionService:AddTag(model, "RoamPet") -- tagged once it is in the world, so the client never sees it at the origin
			return
		end
		if art then
			-- the pet stands over its pedestal as its portrait, always facing the camera; a Gold or Rainbow pet gets a glow
			body.Transparency = 1
			body.Size = Vector3.new(1, 1, 1)
			body.CFrame = pedestal.CFrame + Vector3.new(0, 3.2, 0)
			body.Parent = model
			local card = Instance.new("BillboardGui")
			card.Name = "Portrait"
			card.Size = UDim2.fromScale(8, 8)
			card.StudsOffset = Vector3.new(0, 2.2, 0)
			card.MaxDistance = 160
			card.Parent = body
			local glowColor = if mutation == "Gold"
				then Color3.fromRGB(255, 205, 40)
				elseif mutation == "Rainbow" then Color3.fromRGB(255, 90, 220)
				else nil
			if glowColor then
				local glow = Instance.new("ImageLabel")
				glow.Name = "Glow"
				glow.BackgroundTransparency = 1
				glow.Size = UDim2.fromScale(1.14, 1.14)
				glow.Position = UDim2.fromScale(-0.07, -0.07)
				glow.Image = art
				glow.ImageColor3 = glowColor
				glow.ImageTransparency = 0.35
				glow.Parent = card
			end
			local picture = Instance.new("ImageLabel")
			picture.Name = "Picture"
			picture.BackgroundTransparency = 1
			picture.Size = UDim2.fromScale(1, 1)
			picture.Image = art
			picture.Parent = card
			tag(body, { label, `+{Economy.format(per)}/s` }, 7)
			model.Parent = pedestal
			return
		end
		body.Size = Vector3.new(3.5, 4.5, 2.5)
		body.Color = RARITY_COLORS[c and c.rarity or "Common"] or Color3.new(1, 1, 1)
		body.Material = if item.mutation == "Normal" then Enum.Material.SmoothPlastic else Enum.Material.Neon
		if item.mutation == "Gold" then
			body.Color = Color3.fromRGB(255, 210, 60)
		elseif item.mutation == "Rainbow" then
			body.Color = Color3.fromHSV((os.clock() * 0.2) % 1, 0.8, 1)
		end
		body.CFrame = pedestal.CFrame + Vector3.new(0, 3.2, 0)
		body.Parent = model
		local head = Instance.new("Part")
		head.Name = "Head"
		World.roundify(head)
		head.Size = Vector3.new(3, 3, 3)
		head.Anchored = true
		head.CanCollide = false
		head.Color = body.Color
		head.Material = body.Material
		head.CFrame = body.CFrame + Vector3.new(0, 3.6, 0)
		head.Parent = model
		tag(head, { label, `+{Economy.format(per)}/s` }, 3)
	end
	model.Parent = pedestal
end

function Plots.refresh(player: Player)
	local plot = owned[player]
	if not plot then
		return
	end
	for n = 1, 12 do
		drawSlot(player, plot, n)
	end
end

-- Counts down the hatching timers on screen without rebuilding every part.
-- A hatch pops: a burst of confetti over the pedestal and a flash of light, then it fades away.
function Plots.hatchBurst(player: Player, slots: { number })
	local plot = owned[player]
	if not plot then
		return
	end
	for _, n in slots do
		local pedestal = plot.slots[n]
		if pedestal then
			local spot = Instance.new("Part")
			spot.Name = "HatchBurst"
			spot.Anchored = true
			spot.CanCollide = false
			spot.CanTouch = false
			spot.CanQuery = false
			spot.Transparency = 1
			spot.Size = Vector3.new(1, 1, 1)
			spot.CFrame = pedestal.CFrame + Vector3.new(0, 4, 0)
			spot.Parent = pedestal
			local confetti = Instance.new("ParticleEmitter")
			confetti.Rate = 0
			confetti.Lifetime = NumberRange.new(1, 1.8)
			confetti.Speed = NumberRange.new(14, 26)
			confetti.SpreadAngle = Vector2.new(180, 180)
			confetti.Acceleration = Vector3.new(0, -24, 0)
			confetti.Size = NumberSequence.new(0.7, 0.2)
			confetti.LightEmission = 0.4
			confetti.Color = ColorSequence.new(Color3.fromRGB(255, 220, 60), Color3.fromRGB(255, 90, 200))
			confetti.Parent = spot
			local flash = Instance.new("PointLight")
			flash.Color = Color3.fromRGB(255, 240, 160)
			flash.Range = 24
			flash.Brightness = 3
			flash.Parent = spot
			pcall(function()
				(confetti :: any):Emit(50)
			end)
			task.delay(2.2, function()
				spot:Destroy()
			end)
		end
	end
end

function Plots.updateTimers(player: Player)
	local plot = owned[player]
	local state = Session.get(player)
	if not plot or not state then
		return
	end
	for n = 1, state.base.size do
		local item = state.base.slots[n]
		if item and item.kind == "egg" then
			local pedestal = plot.slots[n]
			local itemModel = pedestal:FindFirstChild("Item")
			local body = itemModel and itemModel:FindFirstChild("Body")
			local tagGui = body and body:FindFirstChild("Tag")
			local label = tagGui and tagGui:FindFirstChild("L2")
			if label and label:IsA("TextLabel") then
				label.Text = `hatching {math.ceil(item.hatchLeft or 0)}s`
			end
		end
	end
end

-- A base exists only while someone lives there: an empty one is parked far underground (and its spawn is switched off), and comes
-- back to its place on the arc when a player takes it. So a server with three players shows three bases, like the real game.
local PARK_DEPTH = 600
local homes: { [Model]: CFrame } = {}

function Plots.setActive(plot: World.Plot, on: boolean)
	local home = homes[plot.model]
	if not home then
		homes[plot.model] = plot.model:GetPivot()
		home = homes[plot.model]
	end
	plot.model:PivotTo(if on then home else home - Vector3.new(0, PARK_DEPTH, 0));
	(plot.spawn :: SpawnLocation).Enabled = on
end

-- Whoever joins first gets the middle of the arc, so a small server looks balanced instead of lopsided.
local FILL_ORDER = { 4, 5, 3, 6, 2, 7, 1, 8 }

-- A big tag floating over the base with the owner's round avatar headshot and name, readable from across the plaza.
local function ownerTag(plot: World.Plot, player: Player)
	local post = plot.model:FindFirstChild("SignPost")
	if not post then
		return
	end
	local old = post:FindFirstChild("OwnerTag")
	if old then
		old:Destroy()
	end
	local tagGui = Instance.new("BillboardGui")
	tagGui.Name = "OwnerTag"
	tagGui.Size = UDim2.fromScale(30, 18) -- studs, so it shrinks with distance like the rest of the world
	tagGui.StudsOffset = Vector3.new(0, 11, 0)
	tagGui.MaxDistance = 600
	tagGui.Parent = post
	local face = Instance.new("ImageLabel")
	face.Name = "Headshot"
	face.AnchorPoint = Vector2.new(0.5, 0)
	face.Position = UDim2.fromScale(0.5, 0)
	face.Size = UDim2.fromScale(0.5, 0.62)
	face.SizeConstraint = Enum.SizeConstraint.RelativeYY
	face.BackgroundColor3 = Color3.fromRGB(40, 40, 52)
	face.Image = `rbxthumb://type=AvatarHeadShot&id={player.UserId}&w=150&h=150`
	face.Parent = tagGui
	local round = Instance.new("UICorner")
	round.CornerRadius = UDim.new(1, 0)
	round.Parent = face
	local ring = Instance.new("UIStroke")
	ring.Thickness = 5
	ring.Color = Color3.new(0, 0, 0)
	ring.Parent = face
	local name = Instance.new("TextLabel")
	name.Name = "Name"
	name.AnchorPoint = Vector2.new(0.5, 1)
	name.Position = UDim2.fromScale(0.5, 1)
	name.Size = UDim2.fromScale(1, 0.34)
	name.BackgroundTransparency = 1
	name.Font = Enum.Font.FredokaOne
	name.TextScaled = true
	name.TextColor3 = Color3.new(1, 1, 1)
	name.TextStrokeTransparency = 0
	name.Text = player.DisplayName
	name.Parent = tagGui
end

function Plots.assign(player: Player): World.Plot?
	for _, index in FILL_ORDER do
		local plot = plots[index]
		if plot and plot.model:GetAttribute("OwnerUserId") == 0 then
			Plots.setActive(plot, true)
			plot.model:SetAttribute("OwnerUserId", player.UserId)
			plot.sign.Text = string.upper(player.DisplayName) .. "'S BASE"
			owned[player] = plot
			player.RespawnLocation = plot.spawn :: SpawnLocation
			ownerTag(plot, player)
			return plot
		end
	end
	return nil
end

function Plots.release(player: Player)
	local plot = owned[player]
	if not plot then
		return
	end
	owned[player] = nil
	plot.model:SetAttribute("OwnerUserId", 0)
	plot.sign.Text = "FREE BASE"
	local post = plot.model:FindFirstChild("SignPost")
	local tagGui = post and post:FindFirstChild("OwnerTag")
	if tagGui then
		tagGui:Destroy()
	end
	for n = 1, 12 do
		clearSlot(plot.slots[n])
	end
	Plots.setActive(plot, false)
end

function Plots.start(world: { plots: { World.Plot } })
	plots = world.plots
	-- every base starts parked; tools that want to see them all (the map preview, layout tests) set this on the workspace first
	if workspace:GetAttribute("ShowAllPlots") ~= true then
		for _, plot in plots do
			Plots.setActive(plot, false)
		end
	end
	Session.onChanged(Plots.refresh)
	task.spawn(function()
		while true do
			task.wait(1)
			for _, player in Players:GetPlayers() do
				Plots.updateTimers(player)
			end
		end
	end)
end

return Plots
