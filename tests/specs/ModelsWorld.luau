--!nocheck
-- The real models show up in the pens and nests, tinted by mutation, and the old look stays when a template is missing.
local Fake = require("../fake/Roblox")
local Zones = require("../../src/shared/Game/Zones")

local function template(world: any, kind: string, id: string)
	local Instance, Vector3, CFrame, Color3 = world.instance, world.Vector3, world.CFrame, world.Color3
	local storage = world.service("ServerStorage")
	local root = storage:FindFirstChild("Models") or Instance.new("Folder")
	root.Name = "Models"
	root.Parent = storage
	local folder = root:FindFirstChild(kind) or Instance.new("Folder")
	folder.Name = kind
	folder.Parent = root
	local model = Instance.new("Model")
	model.Name = id
	local rootPart = Instance.new("Part")
	rootPart.Name = "Root"
	rootPart.Size = Vector3.new(0.2, 0.2, 0.2)
	rootPart.Position = Vector3.new(0, 0, 0)
	rootPart.CFrame = CFrame.new(0, 0, 0)
	rootPart.Parent = model
	model.PrimaryPart = rootPart
	local blob = Instance.new("Part")
	blob.Name = "Blob"
	blob.Color = Color3.fromRGB(100, 100, 100)
	blob.Size = Vector3.new(2, 2, 2)
	blob.Position = Vector3.new(0, 1, 0)
	blob.CFrame = CFrame.new(0, 1, 0)
	blob.Parent = model
	model.Parent = folder
end

return function(t)
	local world = Fake.world()
	template(world, "Pets", "BonkBean")
	template(world, "Eggs", "Soggy")
	template(world, "Props", "Tree")
	template(world, "Props", "Nest")
	template(world, "Props", "TreadmillTopper")
	template(world, "Bosses", "BossMeadow")
	local ok, err = pcall(world.load, "src/server/main.server")
	t.check("the server starts with models", ok, tostring(err))
	if not ok then
		return
	end
	local session = world.load("src/server/Session")
	local plots = world.load("src/server/Plots")
	local ana = world.addPlayer("Ana", 71)
	world.advance(0.6)
	local plot = plots.of(ana)
	local base = session.get(ana).base
	base.slots[1] = { kind = "char", id = "BonkBean", mutation = "Normal" }
	base.slots[2] = { kind = "char", id = "BonkBean", mutation = "Gold" }
	base.slots[3] = { kind = "char", id = "GoldenGoose", mutation = "Normal" }
	session.changed(ana)
	world.advance(0.2)

	local Enum = world.enum
	local one = plot.slots[1]:FindFirstChild("Item", true) :: Instance
	local visual = one:FindFirstChild("Visual")
	t.check("a pet stands as its model", visual ~= nil and visual:IsA("Model"))
	local roamers = world.tags["RoamPet"] or {}
	t.equal("a pet with a model roams its patch (both BonkBeans, not the model-less goose)", #roamers, 2)
	t.check(
		"each roaming pet has its own walk",
		(roamers[1] :: Instance):GetAttribute("RoamSeed") ~= (roamers[2] :: Instance):GetAttribute("RoamSeed")
	)
	-- streaming: a pet must reach a client whole and pivot on its body, or Roam walks half of it out of the pen
	local roamer = roamers[1] :: any
	t.check("a roaming pet pivots on its body", roamer.PrimaryPart ~= nil and roamer.PrimaryPart.Name == "Body")
	t.check("a roaming pet streams as one piece", roamer.ModelStreamingMode == Enum.ModelStreamingMode.Atomic)
	local centre = roamer:GetAttribute("RoamCentre")
	local radius = roamer:GetAttribute("RoamRadius")
	local reach = math.sqrt((centre.X - plot.center.X) ^ 2 + (centre.Z - plot.center.Z) ^ 2)
	t.check("a pet's whole patch is inside the fence", reach + radius < 20 - 3)
	local picture = one:FindFirstChild("Picture", true)
	t.check("the portrait card is not used when the model exists", picture == nil)
	t.check("the pet still has its name tag", one:FindFirstChild("Tag", true) ~= nil)

	local gold = (plot.slots[2]:FindFirstChild("Visual", true) :: Instance):FindFirstChild("Blob") :: BasePart
	t.check("a gold pet glows", gold.Material == Enum.Material.Neon)
	local plain = (visual :: Instance):FindFirstChild("Blob") :: BasePart
	t.check("a normal pet keeps its material", plain.Material ~= Enum.Material.Neon)

	local missing = plot.slots[3]:FindFirstChild("Item", true) :: Instance
	t.check("a pet without a model keeps the old look", missing:FindFirstChild("Visual") == nil)

	-- the Wilds use the real models too: trees, twig nests and the terrain boss
	local wilds = world.workspace:FindFirstChild("Wilds") :: Instance
	local trees, nests = 0, 0
	for _, d in wilds:GetDescendants() do
		if d.Name == "Visual" then
			continue
		end
		if d:IsA("Model") and d.Name == "Tree" then
			trees += 1
		end
	end
	for _, d in wilds:GetDescendants() do
		if d:IsA("Model") and d.Name == "Nest" then
			nests += 1
		end
	end
	t.check("the Meadow has real tree models", trees > 5, tostring(trees))
	t.check("every nest sits in a twig nest model", nests == 5 * #Zones.List, tostring(nests))
	local boss = wilds:FindFirstChild("Boss_Meadow") :: Instance
	t.check("the Meadow boss is its brick model", boss:FindFirstChild("Visual") ~= nil)
	t.check(
		"a terrain without a boss model keeps the plain look",
		(wilds:FindFirstChild("Boss_Dune") :: Instance):FindFirstChild("Visual") == nil
	)
	-- the treadmill (Marco): no speedometer on top, round tubes instead of boxes, and small signs instead of floor pads
	t.check("the treadmill has no speedometer any more", plot.model:FindFirstChild("TreadmillTopper") == nil)
	local rail = plot.model:FindFirstChild("TreadRail") :: Part
	t.check("its rails are round tubes", rail ~= nil and rail.Shape == world.enum.PartType.Cylinder)
	t.check("a small UPGRADE sign stands by it", plot.model:FindFirstChild("UpgradeSign") ~= nil)
	t.check(
		"REBIRTH and BUY SLOT are small signs",
		(plot.model:FindFirstChild("RebirthPad") :: Part).Size.Y > 1
			and (plot.model:FindFirstChild("SlotPad") :: Part).Size.Y > 1
	)
	local spawnPart = plot.model:FindFirstChild("Spawn") :: Part
	t.check("the base spawn is invisible and thin", spawnPart.Transparency == 1 and spawnPart.Size.Y <= 0.3)

	-- a hatch pops with confetti over its pedestal, which then goes away
	base.slots[4] = { kind = "egg", tier = "Soggy", hatchLeft = 0 }
	session.hatchNow(ana)
	world.advance(0.1)
	t.check("a hatch pops with confetti", plot.slots[4]:FindFirstChild("HatchBurst") ~= nil)
	world.advance(3)
	t.check("and the confetti is cleaned up", plot.slots[4]:FindFirstChild("HatchBurst") == nil)

	-- a stolen egg rides on your head as its model
	world.spawnCharacter(ana)
	world.advance(0.6)
	local wildsMod = world.load("src/server/Wilds")
	local entry = wildsMod.entries()[1]
	entry.nest.tier = "Soggy"
	entry.nest.mutation = "Gold"
	world.root(ana).Position = world.Vector3.new(entry.egg.Position.X - 5, 3, entry.egg.Position.Z)
	entry.prompt.Triggered:Fire(ana)
	world.advance(0.3)
	local carried = (ana.Character :: Instance):FindFirstChild("CarryEgg") :: Instance
	t.check("a carried egg wears its model", carried ~= nil and carried:FindFirstChild("Visual") ~= nil)
	local blob = carried:FindFirstChild("Visual"):FindFirstChild("Blob") :: BasePart
	t.check("welded so it moves with you", blob:FindFirstChildOfClass("WeldConstraint") ~= nil and not blob.Anchored)
	t.check("a gold egg shines", blob.Material == Enum.Material.Neon)
end
