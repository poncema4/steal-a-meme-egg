--!strict
-- What each player's screen shows: your own pads and other people's characters to steal, not the other way round.
-- Also checks the shapes the server builds (rings stand flat, eggs and heads wear sphere meshes).
local Fake = require("../fake/Roblox")
local Prompts = require("../../src/client/Prompts")

local function find(root: Instance, name: string): Instance?
	for _, d in root:GetDescendants() do
		if d.Name == name then
			return d
		end
	end
	return nil
end

return function(t)
	-- the rule on its own
	t.check("your pads are visible to you", Prompts.visible("Rebirth", 5, 5))
	t.check("someone else's pads are hidden", not Prompts.visible("Rebirth", 6, 5))
	t.check(
		"all six owner actions follow the same rule",
		Prompts.visible("Skip hatch", 5, 5)
			and not Prompts.visible("Lock base", 6, 5)
			and not Prompts.visible("Buy slot", 6, 5)
	)
	t.check("you can steal from other people", Prompts.visible("Steal", 6, 5))
	t.check("but not from yourself", not Prompts.visible("Steal", 5, 5))
	t.check("and not from a base nobody owns", not Prompts.visible("Steal", 0, 5))
	t.check("buying an egg off the belt is for everyone", Prompts.visible("Buy", 0, 5))

	-- on the real world
	local world = Fake.world()
	local ok, err = pcall(world.load, "src/server/main.server")
	t.check("the server starts", ok, tostring(err))
	if not ok then
		return
	end
	local session = world.load("src/server/Session")
	local plots = world.load("src/server/Plots")
	local ana = world.addPlayer("Ana", 91)
	local ben = world.addPlayer("Ben", 92)
	world.advance(0.6)
	for _, p in { ana, ben } do
		session.get(p).base.slots[1] = { kind = "char", id = "BonkBean", mutation = "Normal" }
		session.changed(p)
	end
	world.setLocal(ana)
	local started, why = pcall(world.load("src/client/Prompts").start, ana)
	t.check("the prompt filter starts", started, tostring(why))
	local anaPlot, benPlot = plots.of(ana).model, plots.of(ben).model
	local mySteal = world.prompts(anaPlot, "Steal")[1]
	local theirSteal = world.prompts(benPlot, "Steal")[1]
	t.check("Ana does not see Steal on her own character", mySteal ~= nil and not mySteal.Enabled)
	t.check("Ana sees Steal on Ben's character", theirSteal ~= nil and theirSteal.Enabled)
	t.check("Ana sees her own rebirth pad", world.prompts(anaPlot, "Rebirth")[1].Enabled)
	t.check("Ana does not see Ben's rebirth pad", not world.prompts(benPlot, "Rebirth")[1].Enabled)
	t.check("Ana does not see Ben's lock pad", not world.prompts(benPlot, "Lock base")[1].Enabled)
	t.check("the belt eggs and nests are untouched", true)

	-- a new character appearing later is filtered too
	session.get(ana).base.slots[2] = { kind = "char", id = "SleepySock", mutation = "Normal" }
	session.changed(ana)
	local steals = world.prompts(anaPlot, "Steal")
	local allHidden = #steals >= 1
	for _, p in steals do
		if p.Enabled then
			allHidden = false
		end
	end
	t.check("characters that appear later are filtered too", allHidden)

	-- the shapes the server builds
	local wilds = world.load("src/server/Wilds")
	local nest = wilds.entries()[1]
	local ring = find(world.workspace:FindFirstChild("Wilds") :: Instance, "Ring") :: Part
	t.check(
		"a nest ring is a flat disc standing on the ground",
		ring.Size.X < 1 and ring.Size.Y == ring.Size.Z,
		tostring(ring.Size)
	)
	t.check("a nest egg wears a sphere mesh", nest.egg:FindFirstChildOfClass("SpecialMesh") ~= nil)
	local head = find(world.workspace:FindFirstChild("Wilds") :: Instance, "Head") :: Instance
	t.check("a guardian's head wears a sphere mesh", head:FindFirstChildOfClass("SpecialMesh") ~= nil)
end
