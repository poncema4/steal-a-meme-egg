--!strict
local Eggs = require("../../src/shared/Game/Eggs")
local Progression = require("../../src/shared/Game/Progression")

return function(t)
	t.equal("zero XP is level 0", (Progression.levelFor(0)), 0)
	t.equal("just under the first threshold is still 0", (Progression.levelFor(Progression.xpForNext(0) - 1)), 0)
	t.equal("the first threshold reaches level 1", (Progression.levelFor(Progression.xpForNext(0))), 1)
	local level, left = Progression.levelFor(Progression.xpForNext(0) + 5)
	t.check("leftover XP carries inside the level", level == 1 and left == 5)
	t.equal("negative XP is level 0", (Progression.levelFor(-50)), 0)
	t.equal("a huge XP stops at the cap", (Progression.levelFor(1e12)), Progression.MAX_LEVEL)

	local increasing = true
	for n = 1, Progression.MAX_LEVEL do
		if Progression.xpForNext(n) <= Progression.xpForNext(n - 1) then
			increasing = false
		end
	end
	t.check("every speed level needs more XP than the last", increasing)
	local costs = true
	for n = 1, Progression.MAX_TREADMILL do
		if Progression.treadmillCost(n) <= Progression.treadmillCost(n - 1) then
			costs = false
		end
	end
	t.check("every treadmill upgrade costs more than the last", costs)
	t.equal("the first treadmill upgrade is cheap", Progression.treadmillCost(0), 100)
	t.equal(
		"the cost stops growing at the top level",
		Progression.treadmillCost(99),
		Progression.treadmillCost(Progression.MAX_TREADMILL)
	)
	local faster = true
	for n = 1, Progression.MAX_TREADMILL do
		if Progression.trainRate(n, 1) <= Progression.trainRate(n - 1, 1) then
			faster = false
		end
	end
	t.check("every treadmill level trains faster than the last", faster)
	t.equal("a negative level trains like level 0", Progression.trainRate(-5, 1), Progression.trainRate(0, 1))
	t.equal(
		"the top level rate is capped",
		Progression.trainRate(99, 1),
		Progression.trainRate(Progression.MAX_TREADMILL, 1)
	)

	t.equal("level 0 walks at the base speed", Progression.walkSpeed(0), Progression.BASE_SPEED)
	t.check("each level is faster", Progression.walkSpeed(5) > Progression.walkSpeed(4))
	t.equal("speed stops growing at the cap", Progression.walkSpeed(99), Progression.walkSpeed(Progression.MAX_LEVEL))
	t.check("a negative level is just the base speed", Progression.walkSpeed(-3) == Progression.BASE_SPEED)

	-- the treadmill should be slow but real: level 1 in well under a minute, level 10 not in a few minutes
	local perSecond = Progression.trainRate(0, 1)
	t.check("the first level takes under a minute on the treadmill", Progression.xpForNext(0) / perSecond < 60)
	local to10 = 0
	for n = 0, 9 do
		to10 += Progression.xpForNext(n)
	end
	t.check("level 10 takes at least 10 minutes of treadmill", to10 / perSecond >= 600, tostring(to10 / perSecond))
	t.equal("a training multiplier scales the rate", Progression.trainRate(0, 2), perSecond * 2)

	t.equal("carrying an egg is 10% slower", Progression.carrySpeed(20, true), 18)
	t.equal("not carrying is full speed", Progression.carrySpeed(20, false), 20)
	-- even carrying, a maxed player still outruns the fastest guardian (27)
	t.check(
		"a maxed carrier outruns the fastest guardian",
		Progression.carrySpeed(Progression.walkSpeed(Progression.MAX_LEVEL), true) > 27
	)

	-- Meme Points: every egg is worth something and rarer is worth more
	local last = 0
	local worth = true
	for _, tier in Eggs.Tiers do
		local p = Progression.pointsForEgg(tier.id)
		if p <= last then
			worth = false
		end
		last = p
	end
	t.check("every egg gives points and rarer eggs give more", worth)
	t.equal("an unknown egg gives nothing", Progression.pointsForEgg("Nope"), 0)
end
