--!strict
local Eggs = require("../../src/shared/Game/Eggs")
local Progression = require("../../src/shared/Game/Progression")
local Zones = require("../../src/shared/Game/Zones")

return function(t)
	-- the terrains form one continuous strip with no gaps or overlaps, going outward
	local contiguous = true
	for i = 2, #Zones.List do
		if Zones.List[i].startX ~= Zones.endX(Zones.List[i - 1]) then
			contiguous = false
		end
	end
	t.check("terrains follow each other with no gaps", contiguous)
	t.check("the first terrain starts past the home area", Zones.List[1].startX >= 200)

	-- unlock costs, speeds and eggs only go up with distance
	local rising = true
	for i = 2, #Zones.List do
		local a, b = Zones.List[i - 1], Zones.List[i]
		if b.mp <= a.mp or b.guardianSpeed <= a.guardianSpeed then
			rising = false
		end
		local ta, tb = Eggs.tier(a.eggs[2]), Eggs.tier(b.eggs[1])
		if not ta or not tb or tb.price < ta.price then
			rising = false
		end
	end
	t.check("deeper terrains cost more, chase faster and hold better eggs", rising)
	t.equal("the first terrain is free", Zones.List[1].mp, 0)
	local real = true
	for _, zone in Zones.List do
		for _, id in zone.eggs do
			if not Eggs.tier(id) then
				real = false
			end
		end
	end
	t.check("every egg a terrain grows exists", real)

	-- lookups
	t.equal("the home area is no terrain", Zones.at(0), nil)
	t.equal("x inside the first terrain", (Zones.at(300) :: Zones.Zone).id, "Meadow")
	t.equal("the start is inclusive", (Zones.at(200) :: Zones.Zone).id, "Meadow")
	t.equal("the boundary belongs to the next terrain", (Zones.at(440) :: Zones.Zone).id, "Dune")
	t.equal("past the last terrain is nothing", Zones.at(1500), nil)
	t.equal("zero points opens only the Meadow", Zones.furthest(0).id, "Meadow")
	t.equal("25 points opens the Dune", Zones.furthest(25).id, "Dune")
	t.equal("24 points does not", Zones.furthest(24).id, "Meadow")
	t.equal("everything open at the top", Zones.furthest(1e9).id, "Cosmic")
	t.equal("the next locked terrain after the Meadow", (Zones.nextLocked(0) :: Zones.Zone).id, "Dune")
	t.equal("nothing is locked at the top", Zones.nextLocked(1e9), nil)

	-- pushing back players who are somewhere they have not unlocked
	t.equal("a player in an unlocked terrain stays", Zones.pushBack(300, 0), nil)
	t.equal("a player in the home area stays", Zones.pushBack(50, 0), nil)
	t.equal("a player in a locked terrain is pushed to its entrance", Zones.pushBack(500, 0), 436)
	t.equal("with enough points they stay", Zones.pushBack(500, 25), nil)

	-- which egg a nest grows
	local meadow = Zones.List[1]
	t.equal(
		"a low roll grows the common egg",
		Zones.eggFor(meadow, function()
			return 0.1
		end),
		"Soggy"
	)
	t.equal(
		"a high roll grows the rarer egg",
		Zones.eggFor(meadow, function()
			return 0.9
		end),
		"Disco"
	)

	-- balance: the speed level a terrain demands (to outrun its guardians while carrying an egg) is reachable and rises
	local previous = -1
	for _, zone in Zones.List do
		local need = 0
		while
			need <= Progression.MAX_LEVEL
			and Progression.carrySpeed(Progression.walkSpeed(need), true) <= zone.guardianSpeed
		do
			need += 1
		end
		t.check(
			`{zone.id} can be outrun by level {need}`,
			need <= Progression.MAX_LEVEL and need >= previous,
			tostring(need)
		)
		previous = need
	end
	t.equal(
		"a new player can outrun the first terrain's guardians",
		Progression.carrySpeed(Progression.walkSpeed(0), true) > Zones.List[1].guardianSpeed,
		true
	)
	-- ...and the last chaser is slower than a maxed player
	local top = Progression.walkSpeed(Progression.MAX_LEVEL)
	for _, zone in Zones.List do
		t.check(
			`{zone.id} guardians can be outrun at max speed`,
			zone.guardianSpeed < top,
			`{zone.guardianSpeed} vs {top}`
		)
	end
end
