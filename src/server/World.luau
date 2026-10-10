--!strict
-- Builds the map out of parts: one long walled corridor, a Safe Zone at its west end where 8 fenced pens (one per player)
-- stand in a semicircle around a plaza, and (built by Wilds) the themed terrains going east. Every number that decides where
-- things stand is here, so Plots, Home and Wilds never guess.
--
-- Each pen has a "frame": its centre, the direction its open front faces (toward the plaza) and its right. Parts are placed
-- with CFrame.lookAt(position, position + front), so a part's size is always (right, up, front) and signs on a part's Front
-- face read correctly for anyone standing in front of the pen. (A part's Front face points along its LookVector.)
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Zones = require(ReplicatedStorage.Shared.Game.Zones)

local World = {}

export type Plot = {
	model: Model,
	spawn: BasePart,
	slots: { BasePart },
	treadmill: BasePart,
	display: { title: TextLabel, level: TextLabel, rate: TextLabel },
	slotPad: BasePart,
	rebirthPad: BasePart,
	sign: TextLabel,
	index: number,
	center: Vector3,
	front: Vector3, -- unit vector from the pen toward the plaza (the open side)
	right: Vector3, -- unit vector to the right of someone standing in the pen looking out
}

World.PLOTS = 8
World.SAFE_BACK = -200 -- the west wall of the Safe Zone
World.SAFE_FRONT = Zones.List[1].startX -- the Safe Zone ends where the first terrain starts
World.WALL_HEIGHT = 60
World.PEN = 40 -- a pen is a square this big
World.PLAZA = Vector3.new(-20, 0, 0) -- the middle of the semicircle
World.RADIUS = 135 -- how far the pens stand from it
World.ARC = math.rad(75) -- the pens span from -ARC to +ARC around the west

local function part(name: string, size: Vector3, cframe: CFrame, color: Color3, parent: Instance): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = cframe
	p.Color = color
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

local PLOT_COLORS = {
	Color3.fromRGB(255, 99, 132),
	Color3.fromRGB(54, 162, 235),
	Color3.fromRGB(255, 206, 86),
	Color3.fromRGB(75, 192, 120),
	Color3.fromRGB(153, 102, 255),
	Color3.fromRGB(255, 159, 64),
	Color3.fromRGB(80, 220, 230),
	Color3.fromRGB(240, 110, 190),
}

-- A sphere (or, with a taller part, an egg) that renders reliably at any size: a block wearing a sphere mesh. A Ball-shaped
-- part is only dependable when its three sizes match.
function World.roundify(p: Part)
	p.Shape = Enum.PartType.Block
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Sphere
	mesh.Parent = p
end

-- Pen i's angle around the plaza: pen 1 is in the north-west, pen 8 in the south-west.
function World.plotAngle(i: number): number
	return -World.ARC + (i - 1) * (2 * World.ARC / (World.PLOTS - 1))
end

function World.plotCenter(i: number): Vector3
	local a = World.plotAngle(i)
	return Vector3.new(World.PLAZA.X - World.RADIUS * math.cos(a), 0, World.PLAZA.Z + World.RADIUS * math.sin(a))
end

-- Local position of base slot n inside a pen (4 columns x 3 rows): x is to the pen's right, z toward its front.
function World.slotOffset(n: number): Vector3
	local column = (n - 1) % 4
	local row = (n - 1) // 4
	return Vector3.new((column - 1.5) * 8.5, 0.5, (row - 1) * 10 - 2)
end

type Frame = { center: Vector3, front: Vector3, right: Vector3 }

local function frameOf(i: number): Frame
	local center = World.plotCenter(i)
	local front = (World.PLAZA - center).Unit
	return { center = center, front = front, right = Vector3.new(-front.Z, 0, front.X) }
end

-- A pen-local (right, up, front) position in the world.
local function at(f: Frame, right: number, up: number, front: number): Vector3
	return f.center + f.right * right + f.front * front + Vector3.new(0, up, 0)
end

-- A CFrame at a pen-local position that faces the pen's front.
local function cf(f: Frame, right: number, up: number, front: number): CFrame
	local p = at(f, right, up, front)
	return CFrame.lookAt(p, p + f.front)
end

local function buildFence(model: Model, f: Frame, color: Color3)
	local half = World.PEN / 2
	local posts = 8
	local function post(right: number, front: number)
		part("Post", Vector3.new(1.2, 6, 1.2), cf(f, right, 3, front), color, model)
	end
	for k = 0, posts - 1 do
		local along = -half + World.PEN * k / (posts - 1)
		post(along, -half) -- the back
		if k > 0 then
			post(-half, along) -- the two sides, from the back corner forward
			post(half, along)
		end
	end
	-- rails: the side rails start just in front of the back rail so no two rails overlap at a corner
	for _, rise in { 2, 4.5 } do
		part("Rail", Vector3.new(World.PEN, 0.5, 0.5), cf(f, 0, rise, -half), color, model)
		for _, side in { -1, 1 } do
			part("Rail", Vector3.new(0.5, 0.5, World.PEN - 1), cf(f, side * half, rise, 0.5), color, model)
		end
	end
end

World.TREAD_LENGTH = 20
World.TREAD_RIDGES = 10

type TreadmillDisplay = { title: TextLabel, level: TextLabel, rate: TextLabel }

local function screenLabel(
	parent: Instance,
	name: string,
	size: UDim2,
	position: UDim2,
	textSize: number,
	color: Color3
): TextLabel
	local label = Instance.new("TextLabel")
	label.Name = name
	label.Size = size
	label.Position = position
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.TextSize = textSize
	label.TextColor3 = color
	label.Text = ""
	label.Parent = parent
	return label
end

-- A real-looking treadmill: a dark belt with lighter tread ridges (the client slides them while someone runs), rollers at both
-- ends, side rails in the pen's colour, and an upright console with handrails and a display at the front. The belt is the part
-- you stand on and upgrade; everything is positioned in the pen's own (right, up, front) frame.
local function buildTreadmill(model: Model, f: Frame, accent: Color3): (Part, TreadmillDisplay)
	local ahead = World.PEN / 2 + 13
	local length = World.TREAD_LENGTH
	local steel = Color3.fromRGB(150, 156, 172)
	local dark = Color3.fromRGB(34, 36, 44)
	local belt =
		part("Treadmill", Vector3.new(6.4, 0.5, length), cf(f, 0, 0.65, ahead), Color3.fromRGB(30, 30, 36), model)
	belt.Material = Enum.Material.SmoothPlastic
	for i = 0, World.TREAD_RIDGES - 1 do
		local ridge = part(
			"Ridge",
			Vector3.new(6.0, 0.1, 0.7),
			cf(f, 0, 0.95, ahead - length / 2 + (i + 0.5) * length / World.TREAD_RIDGES),
			Color3.fromRGB(74, 76, 90),
			model
		)
		ridge.CanCollide = false
		ridge:SetAttribute("Slot", i)
	end
	for _, side in { -1, 1 } do
		part("TreadRail", Vector3.new(0.9, 1.1, length + 0.6), cf(f, side * 3.85, 0.55, ahead), accent, model)
		-- the console legs and the handrail along each side
		part("ConsoleLeg", Vector3.new(0.6, 4.4, 0.6), cf(f, side * 3.85, 3.3, ahead + length / 2 - 0.6), steel, model)
		part("Handrail", Vector3.new(0.4, 0.4, 9), cf(f, side * 3.85, 3.7, ahead + length / 2 - 5.1), steel, model)
	end
	for _, end_ in { -1, 1 } do
		local roller =
			part("Roller", Vector3.new(6.6, 1.3, 1.3), cf(f, 0, 0.65, ahead + end_ * (length / 2 + 0.3)), steel, model)
		roller.Shape = Enum.PartType.Cylinder
	end
	part("ConsoleBar", Vector3.new(8.1, 0.5, 0.5), cf(f, 0, 5.7, ahead + length / 2 - 0.6), steel, model)
	-- the display faces the runner (back toward the pen): a part's Front face points along its LookVector
	local screenAt = at(f, 0, 4.4, ahead + length / 2 - 0.2)
	local screen = part("Console", Vector3.new(5.6, 2.4, 0.4), CFrame.lookAt(screenAt, screenAt - f.front), dark, model)
	local gui = Instance.new("SurfaceGui")
	gui.Name = "ConsoleGui"
	gui.Face = Enum.NormalId.Front
	gui.Parent = screen
	local title =
		screenLabel(gui, "Title", UDim2.fromScale(1, 0.3), UDim2.fromScale(0, 0.03), 20, Color3.fromRGB(120, 230, 255))
	local level = screenLabel(gui, "Level", UDim2.fromScale(1, 0.35), UDim2.fromScale(0, 0.32), 30, Color3.new(1, 1, 1))
	local rate =
		screenLabel(gui, "Rate", UDim2.fromScale(1, 0.3), UDim2.fromScale(0, 0.68), 20, Color3.fromRGB(90, 255, 110))
	title.Text = "TREADMILL"
	level.Text = "LEVEL 0"
	return belt, { title = title, level = level, rate = rate }
end

local function buildPlot(index: number, parent: Instance): Plot
	local f = frameOf(index)
	local color = PLOT_COLORS[(index - 1) % #PLOT_COLORS + 1]
	local model = Instance.new("Model")
	model.Name = `Plot_{index}`
	model:SetAttribute("Index", index)
	model:SetAttribute("OwnerUserId", 0)
	local floor =
		part("Floor", Vector3.new(World.PEN, 1, World.PEN), cf(f, 0, -0.3, 0), Color3.fromRGB(112, 214, 84), model)
	model.PrimaryPart = floor
	buildFence(model, f, color)
	local slots: { BasePart } = {}
	for n = 1, 12 do
		local offset = World.slotOffset(n)
		local pedestal = part(
			`Slot_{n}`,
			Vector3.new(6.5, 1, 6.5),
			cf(f, offset.X, offset.Y + 0.2, offset.Z),
			Color3.fromRGB(60, 60, 70),
			model
		)
		pedestal:SetAttribute("Slot", n)
		slots[n] = pedestal
	end
	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "Spawn"
	spawn.Size = Vector3.new(7, 1, 7)
	spawn.CFrame = cf(f, 0, 0.7, 17)
	spawn.Anchored = true
	spawn.Neutral = true
	spawn.Duration = 0
	spawn.Transparency = 0.5
	spawn.Color = Color3.fromRGB(255, 255, 255)
	spawn.Parent = model
	-- the treadmill lies in front of the pen, in the plaza; you run toward the plaza on it to train speed
	local treadmill, display = buildTreadmill(model, f, color)
	-- the green pad buys another base slot; the purple one rebirths (both inside the pen, at the front corners)
	local slotPad = part("SlotPad", Vector3.new(5, 0.5, 5), cf(f, -14, 0.45, 16), Color3.fromRGB(60, 200, 90), model)
	local rebirthPad =
		part("RebirthPad", Vector3.new(5, 0.5, 5), cf(f, 14, 0.45, 16), Color3.fromRGB(170, 70, 255), model)
	-- the name board stands behind the pen and faces its front, so you read it from the plaza
	local sign =
		part("SignPost", Vector3.new(14, 8, 1), cf(f, 0, 8, -World.PEN / 2 - 2), Color3.fromRGB(35, 35, 45), model)
	local gui = Instance.new("SurfaceGui")
	gui.Name = "SignGui"
	gui.Face = Enum.NormalId.Front
	gui.Parent = sign
	local label = Instance.new("TextLabel")
	label.Name = "Owner"
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.TextScaled = true
	label.Font = Enum.Font.FredokaOne
	label.TextColor3 = Color3.new(1, 1, 1)
	label.Text = "FREE BASE"
	label.Parent = gui
	model.Parent = parent
	return {
		model = model,
		spawn = spawn,
		slots = slots,
		treadmill = treadmill,
		display = display,
		slotPad = slotPad,
		rebirthPad = rebirthPad,
		sign = label,
		index = index,
		center = f.center,
		front = f.front,
		right = f.right,
	}
end

-- A gateway over the red line: a wide board on two legs. Its Front face looks into the Safe Zone, its Back face into the Wilds.
local function buildGate(map: Instance)
	local x = World.SAFE_FRONT - 6
	local board = part(
		"GateSign",
		Vector3.new(130, 16, 2),
		CFrame.lookAt(Vector3.new(x, 32, 0), Vector3.new(x - 1, 32, 0)),
		Color3.fromRGB(30, 110, 200),
		map
	)
	for _, side in { -1, 1 } do
		part("GateLeg", Vector3.new(4, 26, 4), CFrame.new(x, 13, side * 62), Color3.fromRGB(70, 70, 84), map)
	end
	for face, text in { [Enum.NormalId.Front] = "SAFE ZONE", [Enum.NormalId.Back] = "THE WILDS  >>>" } do
		local gui = Instance.new("SurfaceGui")
		gui.Face = face
		gui.Parent = board
		local label = Instance.new("TextLabel")
		label.Name = "GateText"
		label.Size = UDim2.fromScale(1, 1)
		label.BackgroundTransparency = 1
		label.TextScaled = true
		label.Font = Enum.Font.LuckiestGuy
		label.TextColor3 = Color3.new(1, 1, 1)
		label.TextStrokeTransparency = 0
		label.Text = text
		label.Parent = gui
	end
end

-- The long corridor: a floor for the Safe Zone, tall two-tone walls on both sides with a grass lip, a back wall and an end
-- cap. The terrain floors themselves are built by Wilds.
local function buildCorridor(map: Instance)
	local endX = Zones.endX(Zones.List[#Zones.List])
	local length = endX - World.SAFE_BACK
	local half = Zones.WIDTH / 2
	local band = 20
	for k = 0, math.ceil((World.SAFE_FRONT - World.SAFE_BACK) / band) - 1 do
		local x0 = World.SAFE_BACK + k * band
		local x1 = math.min(x0 + band, World.SAFE_FRONT)
		part(
			"SafeFloor",
			Vector3.new(x1 - x0, 2, Zones.WIDTH),
			CFrame.new((x0 + x1) / 2, -1, 0),
			if k % 2 == 0 then Color3.fromRGB(104, 208, 72) else Color3.fromRGB(92, 192, 62),
			map
		)
	end
	-- the round plaza in the middle of the semicircle (a flat disc; a Roblox cylinder runs along X, so it is turned upright)
	local plaza = part(
		"Plaza",
		Vector3.new(0.2, World.RADIUS * 1.8, World.RADIUS * 1.8),
		CFrame.new(World.PLAZA.X, 0.06, World.PLAZA.Z) * CFrame.Angles(0, 0, math.pi / 2),
		Color3.fromRGB(150, 232, 110),
		map
	)
	plaza.Shape = Enum.PartType.Cylinder
	local tans = { Color3.fromRGB(205, 150, 98), Color3.fromRGB(190, 136, 86) }
	local segments = math.ceil(length / band)
	for _, side in { -1, 1 } do
		for k = 0, segments - 1 do
			local x0 = World.SAFE_BACK + k * band
			local x1 = math.min(x0 + band, endX)
			part(
				"Wall",
				Vector3.new(x1 - x0, World.WALL_HEIGHT, 4),
				CFrame.new((x0 + x1) / 2, World.WALL_HEIGHT / 2, side * (half + 2)),
				tans[k % 2 + 1],
				map
			)
		end
		part(
			"WallLip",
			Vector3.new(length + 8, 1.5, 7),
			CFrame.new((World.SAFE_BACK + endX) / 2, World.WALL_HEIGHT + 0.75, side * (half + 2)),
			Color3.fromRGB(90, 200, 60),
			map
		)
	end
	for _, x in { World.SAFE_BACK - 2, endX + 2 } do
		part(
			"EndWall",
			Vector3.new(4, World.WALL_HEIGHT, Zones.WIDTH + 8),
			CFrame.new(x, World.WALL_HEIGHT / 2, 0),
			tans[1],
			map
		)
	end
	-- the red line that ends the Safe Zone
	part(
		"RedLine",
		Vector3.new(1.5, 0.3, Zones.WIDTH),
		CFrame.new(World.SAFE_FRONT - 6, 0.15, 0),
		Color3.fromRGB(235, 40, 40),
		map
	).Material =
		Enum.Material.Neon
	buildGate(map)
end

function World.build(): { plots: { Plot } }
	Lighting.ClockTime = 14
	Lighting.Brightness = 3
	Lighting.Ambient = Color3.fromRGB(120, 120, 130)
	local existing = workspace:FindFirstChild("Baseplate")
	if existing then
		existing:Destroy() -- the template baseplate would z-fight with our floors
	end
	local map = Instance.new("Folder")
	map.Name = "Map"
	map.Parent = workspace
	buildCorridor(map)
	local plots = {}
	for i = 1, World.PLOTS do
		plots[i] = buildPlot(i, map)
	end
	return { plots = plots }
end

return World
