--!strict
-- Every treadmill level has a name and a look, and an upgrade repaints the belt.
local Fake = require("../fake/Roblox")
local Progression = require("../../src/shared/Game/Progression")
local TreadmillTier = require("../../src/shared/Game/TreadmillTier")

return function(t)
	t.equal("a tier for every level, 0 to the maximum", #TreadmillTier.List, Progression.MAX_TREADMILL + 1)
	local names, distinct = {}, true
	for _, tier in TreadmillTier.List do
		if names[tier.name] then
			distinct = false
		end
		names[tier.name] = true
	end
	t.check("every tier has its own name", distinct)
	t.equal("level 0 is Rusty", TreadmillTier.of(0).name, "Rusty")
	t.equal("the top level is Divine", TreadmillTier.of(Progression.MAX_TREADMILL).name, "Divine")
	t.equal("a level past the top stays the top", TreadmillTier.of(99).name, "Divine")
	t.equal("a negative level is the first", TreadmillTier.of(-3).name, "Rusty")
	t.check("only the high tiers glow", not TreadmillTier.of(5).glow and TreadmillTier.of(10).glow)

	local world = Fake.world()
	local ok, err = pcall(world.load, "src/server/main.server")
	t.check("the server starts", ok, tostring(err))
	if not ok then
		return
	end
	local plots = world.load("src/server/Plots")
	local session = world.load("src/server/Session")
	local ana = world.addPlayer("Ana", 601)
	world.advance(0.6)
	local plot = plots.of(ana)
	t.equal("a new treadmill is Rusty", plot.display.title.Text, "RUSTY TREADMILL")
	local ridge = plot.model:FindFirstChild("Ridge") :: BasePart
	local before = ridge.Color
	session.add(ana, 1e9)
	t.check("the first upgrade works", (session.upgradeTreadmill(ana)))
	world.advance(0.3)
	t.equal("the console names the new tier", plot.display.title.Text, "BASIC TREADMILL")
	t.check("and the belt's ridges take its colour", ridge.Color ~= before)
	for _ = 1, 8 do
		session.upgradeTreadmill(ana)
	end
	world.advance(0.3)
	t.equal("level 9 is Neon", plot.display.title.Text, "NEON TREADMILL")
	t.check("and it glows", ridge.Material == world.enum.Material.Neon)
end
