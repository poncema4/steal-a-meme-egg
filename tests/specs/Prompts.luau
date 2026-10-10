--!strict
-- What each player's screen shows: only your own base shows its pads.
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
		"all the owner actions follow the same rule",
		Prompts.visible("Skip hatch", 5, 5)
			and not Prompts.visible("Buy slot", 6, 5)
			and not Prompts.visible("Upgrade treadmill", 6, 5)
	)

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
	t.equal(
		"characters in a base cannot be stolen: there is no Steal prompt",
		#world.prompts(world.workspace, "Steal"),
		0
	)
	t.equal("and there is no lock pad", #world.prompts(world.workspace, "Lock base"), 0)
	t.check("Ana sees her own rebirth pad", world.prompts(anaPlot, "Rebirth")[1].Enabled)
	t.check("Ana does not see Ben's rebirth pad", not world.prompts(benPlot, "Rebirth")[1].Enabled)

	-- a new prompt appearing later is filtered too
	session.grantEgg(ben, "Soggy")
	local skips = world.prompts(benPlot, "Skip hatch")
	local allHidden = #skips >= 1
	for _, p in skips do
		if p.Enabled then
			allHidden = false
		end
	end
	t.check("Ben's skip-hatch prompt that appears later is hidden from Ana", allHidden)

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
	-- a guardian is its portrait (a billboard on its invisible body), not a box and a ball
	local portrait = find(world.workspace:FindFirstChild("Wilds") :: Instance, "Portrait") :: Instance
	t.check("a guardian is shown as its portrait", portrait ~= nil and portrait:IsA("BillboardGui"))
	local picture = find(portrait, "Picture") :: ImageLabel
	t.check("a real image", string.find(picture.Image, "rbxassetid://", 1, true) == 1)
	local guardianBody = portrait.Parent :: Part
	t.equal("the body behind it is invisible (it only carries the picture)", guardianBody.Transparency, 1)
	t.equal("and is the guardian's body", guardianBody.Name, "Body")
end
