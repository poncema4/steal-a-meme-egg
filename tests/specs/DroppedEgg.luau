--!nocheck
-- A dropped egg stays on the ground where you let go, and you can SEE it: the real egg model stands on it (Marco: "when I drop
-- it the egg disappears"). Two eggs on the ground at once each keep their own model, and picking one up leaves no ghost behind.
local Fake = require("../fake/Roblox")
local Eggs = require("../../src/shared/Game/Eggs")

local function template(world: any, kind: string, id: string)
	local Instance, Vector3, CFrame = world.instance, world.Vector3, world.CFrame
	local storage = world.service("ServerStorage")
	local root = storage:FindFirstChild("Models") or Instance.new("Folder")
	root.Name = "Models"
	root.Parent = storage
	local folder = root:FindFirstChild(kind) or Instance.new("Folder")
	folder.Name = kind
	folder.Parent = root
	local model = Instance.new("Model")
	model.Name = id
	local shell = Instance.new("Part")
	shell.Name = "Shell"
	shell.Size = Vector3.new(3, 4, 3)
	shell.Position = Vector3.new(0, 2, 0)
	shell.CFrame = CFrame.new(0, 2, 0)
	shell.Parent = model
	model.PrimaryPart = shell
	model.Parent = folder
end

local function visualOf(dropped: any): any
	return dropped and dropped.holder and dropped.holder:FindFirstChild("Visual")
end

return function(t)
	local world = Fake.world()
	for _, tier in Eggs.Tiers do
		template(world, "Eggs", tier.id)
	end
	local ok, err = pcall(world.load, "src/server/main.server")
	t.check("the server starts with the egg models", ok, tostring(err))
	if not ok then
		return
	end
	local wilds = world.load("src/server/Wilds")
	local remotes = world.service("ReplicatedStorage"):FindFirstChild("Remotes")
	local drop = remotes:FindFirstChild("Drop")
	local ana = world.addPlayer("Ana", 71)
	local ben = world.addPlayer("Ben", 72)
	world.spawnCharacter(ana)
	world.spawnCharacter(ben)
	world.advance(0.6)
	local entries = wilds.entries()
	local function steal(player, entry)
		local root = world.root(player)
		root.Position = world.Vector3.new(entry.egg.Position.X - 5, 3, entry.egg.Position.Z)
		entry.prompt.Triggered:Fire(player)
	end

	steal(ana, entries[1])
	world.setLocal(ana)
	drop:FireServer()
	local first = entries[1].dropped
	t.check("Ana's egg lies on the ground", first ~= nil)
	t.check("and you can see it: the egg model stands there", visualOf(first) ~= nil)
	t.check("the model sits in the egg's own holder, in the world", first and first.holder.Parent ~= nil)

	steal(ben, entries[2])
	world.setLocal(ben)
	drop:FireServer()
	local second = entries[2].dropped
	t.check("Ben's egg lies on the ground too", second ~= nil and visualOf(second) ~= nil)
	t.check("and Ana's is still visible next to it", visualOf(first) ~= nil and first.holder.Parent ~= nil)

	local holder = first.holder
	first.part:FindFirstChildOfClass("ProximityPrompt").Triggered:Fire(ana)
	t.check("Ana picks hers up again", entries[1].thief == ana and entries[1].dropped == nil)
	t.check("and no ghost egg is left on the ground", holder.Parent == nil)

	local benHolder = second.holder
	world.advance(95)
	t.check("an egg left too long goes back to its nest", entries[2].dropped == nil)
	t.check("and takes its model with it", benHolder.Parent == nil)
end
