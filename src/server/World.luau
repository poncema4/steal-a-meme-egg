--!strict
-- Builds the simple v0 world out of parts: a big lawn, a conveyor belt down the middle, and a row of base plots on
-- each side. Layout numbers are here so the Plots/Conveyor code never guesses where things are.
local Lighting = game:GetService("Lighting")

local World = {}

export type Plot = {
	model: Model,
	spawn: BasePart,
	slots: { BasePart },
	lockPad: BasePart,
	sign: TextLabel,
	index: number,
}

World.PLOTS = 12
World.BELT_LENGTH = 320
World.BELT_WIDTH = 10
World.BELT_Z = 0

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

-- Where plot i sits: two rows of six, facing the belt.
function World.plotCenter(i: number): Vector3
	local column = (i - 1) % 6
	local row = (i - 1) // 6
	return Vector3.new((column - 2.5) * 52, 0, if row == 0 then -62 else 62)
end

-- Local position of base slot n inside a plot (4 columns x 3 rows).
function World.slotOffset(n: number): Vector3
	local column = (n - 1) % 4
	local row = (n - 1) // 4
	return Vector3.new((column - 1.5) * 9, 0.5, (row - 1) * 11 - 2)
end

local function buildPlot(index: number, parent: Instance): Plot
	local center = World.plotCenter(index)
	local facing = if center.Z < 0 then 1 else -1 -- +1: the belt is toward +z
	local color = PLOT_COLORS[(index - 1) % #PLOT_COLORS + 1]
	local model = Instance.new("Model")
	model.Name = `Plot_{index}`
	model:SetAttribute("Index", index)
	model:SetAttribute("OwnerUserId", 0)
	local floor = part("Floor", Vector3.new(46, 1, 46), CFrame.new(center + Vector3.new(0, -0.5, 0)), color, model)
	model.PrimaryPart = floor
	local slots: { BasePart } = {}
	for n = 1, 12 do
		local offset = World.slotOffset(n)
		local pedestal = part(
			`Slot_{n}`,
			Vector3.new(7, 1, 7),
			CFrame.new(center + Vector3.new(offset.X, offset.Y, offset.Z * facing)),
			Color3.fromRGB(60, 60, 70),
			model
		)
		pedestal:SetAttribute("Slot", n)
		slots[n] = pedestal
	end
	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "Spawn"
	spawn.Size = Vector3.new(8, 1, 8)
	spawn.CFrame = CFrame.new(center + Vector3.new(0, 0.5, 17 * facing))
	spawn.Anchored = true
	spawn.Neutral = true
	spawn.Duration = 0
	spawn.Transparency = 0.5
	spawn.Color = Color3.fromRGB(255, 255, 255)
	spawn.Parent = model
	-- the lock pad sits at the belt side of the plot
	local lockPad = part(
		"LockPad",
		Vector3.new(8, 1, 3),
		CFrame.new(center + Vector3.new(14, 0.5, 21 * facing)),
		Color3.fromRGB(230, 60, 60),
		model
	)
	local sign = part(
		"SignPost",
		Vector3.new(14, 8, 1),
		CFrame.new(center + Vector3.new(0, 5, -22 * facing)),
		Color3.fromRGB(35, 35, 45),
		model
	)
	local gui = Instance.new("SurfaceGui")
	gui.Name = "SignGui"
	gui.Face = if facing == 1 then Enum.NormalId.Front else Enum.NormalId.Back
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
	return { model = model, spawn = spawn, slots = slots, lockPad = lockPad, sign = label, index = index }
end

function World.build(): { plots: { Plot }, belt: BasePart }
	Lighting.ClockTime = 14
	Lighting.Brightness = 3
	Lighting.Ambient = Color3.fromRGB(120, 120, 130)
	local existing = workspace:FindFirstChild("Baseplate")
	if existing then
		existing:Destroy() -- the template baseplate would z-fight with our lawn
	end
	local map = Instance.new("Folder")
	map.Name = "Map"
	map.Parent = workspace
	part("Lawn", Vector3.new(420, 2, 260), CFrame.new(0, -1, 0), Color3.fromRGB(86, 190, 90), map)
	local belt = part(
		"Belt",
		Vector3.new(World.BELT_LENGTH, 0.6, World.BELT_WIDTH),
		CFrame.new(0, 0.3, World.BELT_Z),
		Color3.fromRGB(40, 40, 46),
		map
	)
	for k = -7, 7 do -- stripes so the belt reads as moving
		part(
			"Stripe",
			Vector3.new(2, 0.05, World.BELT_WIDTH),
			CFrame.new(k * 20, 0.62, World.BELT_Z),
			Color3.fromRGB(255, 220, 0),
			map
		)
	end
	local plots = {}
	for i = 1, World.PLOTS do
		plots[i] = buildPlot(i, map)
	end
	return { plots = plots, belt = belt }
end

return World
