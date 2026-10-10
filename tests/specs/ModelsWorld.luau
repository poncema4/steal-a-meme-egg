--!nocheck
-- The real models show up in the pens and nests, tinted by mutation, and the old look stays when a template is missing.
local Fake = require("../fake/Roblox")

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
	local picture = one:FindFirstChild("Picture", true)
	t.check("the portrait card is not used when the model exists", picture == nil)
	t.check("the pet still has its name tag", one:FindFirstChild("Tag", true) ~= nil)

	local gold = (plot.slots[2]:FindFirstChild("Visual", true) :: Instance):FindFirstChild("Blob") :: BasePart
	t.check("a gold pet glows", gold.Material == Enum.Material.Neon)
	local plain = (visual :: Instance):FindFirstChild("Blob") :: BasePart
	t.check("a normal pet keeps its material", plain.Material ~= Enum.Material.Neon)

	local missing = plot.slots[3]:FindFirstChild("Item", true) :: Instance
	t.check("a pet without a model keeps the old look", missing:FindFirstChild("Visual") == nil)
end
