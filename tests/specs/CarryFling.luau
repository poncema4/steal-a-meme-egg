--!strict
-- What you carry and what a catch does: the egg floats above your head with a trail while you run, Gold and Rainbow ones
-- shine, it goes away when you deliver, drop it or are caught, and a catch flings you back like a rag doll.
local Fake = require("../fake/Roblox")

local function has(root: Instance, name: string): Instance?
	return root:FindFirstChild(name, true)
end

return function(t)
	local world = Fake.world()
	local V3 = world.Vector3
	local ok, err = pcall(world.load, "src/server/main.server")
	t.check("the server starts", ok, tostring(err))
	if not ok then
		return
	end
	local wilds = world.load("src/server/Wilds")
	local session = world.load("src/server/Session")
	local plots = world.load("src/server/Plots")
	local remotes = world.service("ReplicatedStorage"):FindFirstChild("Remotes") :: Instance
	local ana = world.addPlayer("Ana", 41)
	world.spawnCharacter(ana)
	world.advance(0.6)
	world.setLocal(ana)
	local entry = wilds.entries()[1]
	local function steal(mutation: string)
		entry.nest.mutation = mutation
		entry.nest.tier = "Soggy"
		world.root(ana).Position = V3.new(entry.egg.Position.X - 5, 3, entry.egg.Position.Z)
		entry.prompt.Triggered:Fire(ana)
		world.root(ana).Position = V3.new(entry.egg.Position.X - 141, 3, entry.egg.Position.Z)
		world.advance(0.2)
	end

	t.check("nothing is carried at first", has(ana.Character, "CarryEgg") == nil)
	steal("Normal")
	local egg = has(ana.Character, "CarryEgg") :: Part
	t.check("stealing puts an egg above your head", egg ~= nil)
	t.check("it is welded to you so it moves with you", egg ~= nil and egg:FindFirstChildOfClass("Weld") ~= nil)
	t.check("it does not weigh you down or block you", egg ~= nil and egg.Massless and not egg.CanCollide)
	t.check("and a speed trail streams behind you", has(ana.Character, "CarryTrail") ~= nil)
	t.check("the egg is not gold", egg ~= nil and egg.Color ~= world.Color3.fromRGB(255, 205, 40))

	-- dropping removes it all
	remotes:FindFirstChild("Drop"):FireServer()
	world.advance(0.2)
	t.check("dropping removes the egg", has(ana.Character, "CarryEgg") == nil)
	t.check("and the trail", has(ana.Character, "CarryTrail") == nil)
	t.check("and the trail's anchor points", has(ana.Character, "TrailTop") == nil)

	-- a Gold egg shines
	world.advance(1)
	steal("Gold")
	local gold = has(ana.Character, "CarryEgg") :: Part
	t.check("a Gold egg is gold-coloured", gold ~= nil and gold.Color == world.Color3.fromRGB(255, 205, 40))
	t.check("and glows", gold ~= nil and gold.Material == world.enum.Material.Neon)

	-- respawning mid-run brings the egg back
	world.spawnCharacter(ana)
	world.advance(0.3)
	t.check("a new character is still carrying the egg", has(ana.Character, "CarryEgg") ~= nil)

	-- delivering removes it
	local plot = plots.of(ana)
	world.root(ana).Position = V3.new(plot.center.X, 3, plot.center.Z)
	world.advance(1)
	t.equal("delivered", ana:GetAttribute("Carrying"), "")
	t.check("the egg above your head is gone", has(ana.Character, "CarryEgg") == nil)

	-- getting caught flings you
	world.advance(1)
	steal("Normal")
	local root = world.root(ana)
	root.Position = V3.new(entry.guardian.x, 3, entry.guardian.z)
	root.AssemblyLinearVelocity = V3.new(0, 0, 0)
	world.advance(0.3)
	t.equal("caught: you let go of the egg", ana:GetAttribute("Carrying"), "")
	t.check("it leaves your head", has(ana.Character, "CarryEgg") == nil)
	t.check(
		"you are flung back toward the Safe Zone",
		root.AssemblyLinearVelocity.X < -50,
		tostring(root.AssemblyLinearVelocity)
	)
	t.check("and thrown up into the air", root.AssemblyLinearVelocity.Y > 30)
	t.check("you tumble like a rag doll", world.humanoid(ana).PlatformStand == true)
	world.advance(2)
	t.check("then you get back up", world.humanoid(ana).PlatformStand == false)
	t.check("your carried speed is back to normal", world.humanoid(ana).WalkSpeed >= 16)

	-- a drop does not fling
	world.advance(1)
	steal("Normal")
	root.AssemblyLinearVelocity = V3.new(0, 0, 0)
	remotes:FindFirstChild("Drop"):FireServer()
	world.advance(0.3)
	t.check("dropping is gentle: no fling", root.AssemblyLinearVelocity.Magnitude < 1)
	t.check("and no tumbling", world.humanoid(ana).PlatformStand ~= true)
	t.equal("nothing carried again", session.get(ana).carry, nil)
end
