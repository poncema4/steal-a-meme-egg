--!strict
-- Builds the map out of parts: one long corridor with tall walls, a Safe Zone at the west end with a fenced pen for every
-- player, and (built by Wilds) the themed terrains going east. Every number that decides where things stand is here, so
-- Plots, Home and Wilds never guess. "Front" of a pen is east (+x), toward the red line and the Wilds.
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Zones = require(ReplicatedStorage.Shared.Game.Zones)

local World = {}

export type Plot = {
	model: Model,
	spawn: BasePart,
	slots: { BasePart },
	treadmill: BasePart,
	slotPad: BasePart,
	rebirthPad: BasePart,
	sign: TextLabel,
	index: number,
	center: Vector3,
}

World.PLOTS = 12
World.SAFE_BACK = -190 -- the west wall of the Safe Zone
World.SAFE_FRONT = Zones.List[1].startX -- the Safe Zone ends where the first terrain starts
World.WALL_HEIGHT = 60
World.PEN = 46 -- a pen is a square this big
local COLUMNS = 4 -- pens across the corridor (z)
local ROW_SPACING = 56 -- pens along the corridor (x)
local COLUMN_SPACING = 55

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
}

-- A sphere (or, with a taller part, an egg) that renders reliably at any size: a block wearing a sphere mesh. A Ball-shaped
-- part is only dependable when its three sizes match.
function World.roundify(p: Part)
	p.Shape = Enum.PartType.Block
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Sphere
	mesh.Parent = p
end

-- Where pen i sits: a grid of four across the corridor and three rows deep, the back row against the west wall.
function World.plotCenter(i: number): Vector3
	local column = (i - 1) % COLUMNS
	local row = (i - 1) // COLUMNS
	return Vector3.new(World.SAFE_BACK + 28 + row * ROW_SPACING, 0, (column - (COLUMNS - 1) / 2) * COLUMN_SPACING)
end

-- Local position of base slot n inside a pen (4 columns x 3 rows): x is to the pen's right, z toward its front.
function World.slotOffset(n: number): Vector3
	local column = (n - 1) % 4
	local row = (n - 1) // 4
	return Vector3.new((column - 1.5) * 9, 0.5, (row - 1) * 11 - 2)
end

-- Pen-local to world. A pen's own axes are (right, up, front); in the world front is +x and right is +z.
local function place(center: Vector3, right: number, up: number, front: number): Vector3
	return center + Vector3.new(front, up, right)
end

-- The same swap for a part's size, given as (right, up, front).
local function dims(right: number, up: number, front: number): Vector3
	return Vector3.new(front, up, right)
end

local function buildFence(model: Model, center: Vector3, color: Color3)
	local half = World.PEN / 2
	local posts = 8
	local function post(right: number, front: number)
		part("Post", Vector3.new(1.2, 6, 1.2), CFrame.new(place(center, right, 3, front)), color, model)
	end
	for k = 0, posts - 1 do
		local at = -half + World.PEN * k / (posts - 1)
		post(at, -half) -- the back
		if k > 0 then
			post(-half, -half + World.PEN * k / (posts - 1)) -- the two sides, from the back corner forward
			post(half, -half + World.PEN * k / (posts - 1))
		end
	end
	-- rails: the side rails start just in front of the back rail so no two rails overlap at a corner
	for _, rise in { 2, 4.5 } do
		part("Rail", dims(World.PEN, 0.5, 0.5), CFrame.new(place(center, 0, rise, -half)), color, model)
		for _, side in { -1, 1 } do
			part("Rail", dims(0.5, 0.5, World.PEN - 1), CFrame.new(place(center, side * half, rise, 0.5)), color, model)
		end
	end
end

local function buildPlot(index: number, parent: Instance): Plot
	local center = World.plotCenter(index)
	local color = PLOT_COLORS[(index - 1) % #PLOT_COLORS + 1]
	local model = Instance.new("Model")
	model.Name = `Plot_{index}`
	model:SetAttribute("Index", index)
	model:SetAttribute("OwnerUserId", 0)
	local floor = part(
		"Floor",
		dims(World.PEN, 1, World.PEN),
		CFrame.new(center + Vector3.new(0, -0.35, 0)),
		Color3.fromRGB(112, 214, 84),
		model
	)
	model.PrimaryPart = floor
	buildFence(model, center, color)
	local slots: { BasePart } = {}
	for n = 1, 12 do
		local offset = World.slotOffset(n)
		local pedestal = part(
			`Slot_{n}`,
			Vector3.new(7, 1, 7),
			CFrame.new(place(center, offset.X, offset.Y, offset.Z)),
			Color3.fromRGB(60, 60, 70),
			model
		)
		pedestal:SetAttribute("Slot", n)
		slots[n] = pedestal
	end
	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "Spawn"
	spawn.Size = Vector3.new(8, 1, 8)
	spawn.CFrame = CFrame.new(place(center, 0, 0.5, 17))
	spawn.Anchored = true
	spawn.Neutral = true
	spawn.Duration = 0
	spawn.Transparency = 0.5
	spawn.Color = Color3.fromRGB(255, 255, 255)
	spawn.Parent = model
	-- the treadmill trains speed while you run on it; the green pad buys another base slot; the purple one rebirths
	local treadmill =
		part("Treadmill", dims(5, 0.5, 18), CFrame.new(place(center, 20, 0.25, 0)), Color3.fromRGB(70, 70, 80), model)
	for k = -3, 3 do
		part(
			"TreadStripe",
			dims(4, 0.2, 1),
			CFrame.new(place(center, 20, 0.6, k * 2.4)),
			Color3.fromRGB(255, 220, 0),
			model
		)
	end
	local slotPad =
		part("SlotPad", dims(5, 0.5, 5), CFrame.new(place(center, -20, 0.25, 15)), Color3.fromRGB(60, 200, 90), model)
	local rebirthPad = part(
		"RebirthPad",
		dims(5, 0.5, 5),
		CFrame.new(place(center, -20, 0.25, -15)),
		Color3.fromRGB(170, 70, 255),
		model
	)
	-- the name board stands behind the pen, facing the front
	local sign = part(
		"SignPost",
		dims(14, 8, 1),
		CFrame.new(place(center, 0, 7, -World.PEN / 2 - 2)),
		Color3.fromRGB(35, 35, 45),
		model
	)
	local gui = Instance.new("SurfaceGui")
	gui.Name = "SignGui"
	gui.Face = Enum.NormalId.Right
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
		slotPad = slotPad,
		rebirthPad = rebirthPad,
		sign = label,
		index = index,
		center = center,
	}
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
	-- the red line that ends the Safe Zone, and SAFE ZONE written big on the ground in front of the pens
	part(
		"RedLine",
		Vector3.new(1.5, 0.3, Zones.WIDTH),
		CFrame.new(World.SAFE_FRONT - 6, 0.15, 0),
		Color3.fromRGB(235, 40, 40),
		map
	).Material =
		Enum.Material.Neon
	local writing = part(
		"SafeZoneText",
		Vector3.new(110, 0.2, 24),
		CFrame.new(World.SAFE_FRONT - 14, 0.1, 0) * CFrame.Angles(0, -math.pi / 2, 0),
		Color3.new(1, 1, 1),
		map
	)
	writing.Transparency = 1
	writing.CanCollide = false
	local gui = Instance.new("SurfaceGui")
	gui.Name = "Writing"
	gui.Face = Enum.NormalId.Top
	gui.Parent = writing
	local text = Instance.new("TextLabel")
	text.Size = UDim2.fromScale(1, 1)
	text.BackgroundTransparency = 1
	text.TextScaled = true
	text.Font = Enum.Font.LuckiestGuy
	text.TextColor3 = Color3.new(1, 1, 1)
	text.TextStrokeTransparency = 0
	text.TextStrokeColor3 = Color3.fromRGB(40, 70, 110)
	text.Text = "SAFE ZONE"
	text.Parent = gui
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
