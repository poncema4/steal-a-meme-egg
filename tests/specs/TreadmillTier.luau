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
	-- each tier is more splendid than the last: the light only goes up, and only the top ones sparkle
	local rising, last = true, 0
	for _, tier in TreadmillTier.List do
		if tier.light < last then
			rising = false
		end
		last = tier.light
	end
	t.check("the shine only grows tier by tier", rising)
	t.check(
		"the first tier is rusty corroded metal and unlit",
		TreadmillTier.of(0).material == "CorrodedMetal" and TreadmillTier.of(0).light == 0
	)
	t.check(
		"the last is a glowing divine one",
		TreadmillTier.of(12).material == "Neon" and TreadmillTier.of(12).sparkles
	)

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
	local rail0 = plot.model:FindFirstChild("TreadRail") :: BasePart
	t.check("a new treadmill's frame is rusty corroded metal", rail0.Material == world.enum.Material.CorrodedMetal)
	t.check("with its light strips off", (plot.model:FindFirstChild("TierGlow") :: BasePart).Transparency == 1)
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
	-- the whole machine is repainted, not only the ridges
	local rail = plot.model:FindFirstChild("TreadRail") :: BasePart
	t.check("level 9: the frame is dark metal", rail.Material == world.enum.Material.Metal)
	local strip = plot.model:FindFirstChild("TierGlow") :: BasePart
	t.check(
		"level 9: the light strips are lit",
		strip.Transparency < 0.5 and strip.Material == world.enum.Material.Neon
	)
	local lamp = plot.treadmill:FindFirstChild("TierLight") :: PointLight
	t.check("and the lamp is on", lamp.Brightness > 1)
	for _ = 1, 3 do
		session.upgradeTreadmill(ana)
	end
	world.advance(0.3)
	t.equal("level 12 is Divine", plot.display.title.Text, "DIVINE TREADMILL")
	t.check("its frame glows", rail.Material == world.enum.Material.Neon)
	t.check("and it sparkles", (plot.treadmill:FindFirstChild("TierSparkles") :: ParticleEmitter).Enabled == true)
end
