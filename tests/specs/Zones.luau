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
	t.check("the first terrain starts east of the Safe Zone's back wall", Zones.List[1].startX > -190)

	-- unlock costs, speeds and eggs only go up with distance
	local rising = true
	for i = 2, #Zones.List do
		local a, b = Zones.List[i - 1], Zones.List[i]
		if b.level <= a.level or b.guardianSpeed <= a.guardianSpeed then
			rising = false
		end
		local ta, tb = Eggs.tier(a.eggs[2]), Eggs.tier(b.eggs[1])
		if not ta or not tb or tb.price < ta.price then
			rising = false
		end
	end
	t.check("deeper terrains cost more, chase faster and hold better eggs", rising)
	t.equal("the first terrain is free", Zones.List[1].level, 0)
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
	t.equal("the Safe Zone is no terrain", Zones.at(Zones.List[1].startX - 1), nil)
	t.equal("x inside the first terrain", (Zones.at(Zones.List[1].startX + 100) :: Zones.Zone).id, "Meadow")
	t.equal("the start is inclusive", (Zones.at(Zones.List[1].startX) :: Zones.Zone).id, "Meadow")
	t.equal("the boundary belongs to the next terrain", (Zones.at(Zones.List[2].startX) :: Zones.Zone).id, "Dune")
	t.equal("past the last terrain is nothing", Zones.at(Zones.endX(Zones.List[#Zones.List]) + 5), nil)
	t.check("there are ten worlds", #Zones.List == 10)
	t.equal("speed level 0 is a Meadow player", Zones.furthest(0).id, "Meadow")
	t.equal("level 3 reaches the Dune's recommended speed", Zones.furthest(3).id, "Dune")
	t.equal("level 2 does not", Zones.furthest(2).id, "Meadow")
	t.equal("the last world is reached at the top", Zones.furthest(1e9).id, "Sky")
	t.equal("the next world to aim for after the Meadow", (Zones.nextTarget(0) :: Zones.Zone).id, "Dune")
	t.equal("nothing is left to aim for at the top", Zones.nextTarget(1e9), nil)
	t.check(
		"nothing blocks anyone: there is no way to be refused entry",
		Zones.unlocked == nil and Zones.pushBack == nil
	)

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

	-- balance: the recommended level is about when you can outrun the boss while carrying an egg, and it only goes up
	local previous = -1
	for _, zone in Zones.List do
		local carry = Progression.carrySpeed(Progression.walkSpeed(zone.level), true)
		t.check(
			`{zone.id}: at its recommended level you outrun its boss`,
			carry > zone.guardianSpeed,
			`{carry} vs {zone.guardianSpeed}`
		)
		t.check(`{zone.id}: its recommended level is above the previous one`, zone.level >= previous)
		previous = zone.level
		-- and a player a few levels short really is slower than it
		if zone.level >= 8 then
			local short = Progression.carrySpeed(Progression.walkSpeed(zone.level - 8), true)
			t.check(
				`{zone.id}: eight levels short you are slower than its boss`,
				short < zone.guardianSpeed,
				`{short} vs {zone.guardianSpeed}`
			)
		end
	end
	t.equal(
		"a new player can outrun the first terrain's guardians",
		Progression.carrySpeed(Progression.walkSpeed(0), true) > Zones.List[1].guardianSpeed,
		true
	)
	-- the deepest boss is still slower than the fastest a body can run, so the end can be reached (but takes a very high level)
	t.check(
		"even the last boss can be outrun by the fastest runner",
		Zones.List[#Zones.List].guardianSpeed < Progression.TOP_SPEED * Progression.CARRY_FACTOR
	)
	t.check(
		"but it takes a very high speed: the last recommended level is 50 or more",
		Zones.List[#Zones.List].level >= 50
	)

	-- the Index groups characters by the world their egg belongs to
	t.equal("the Soggy egg belongs to the Meadow", (Zones.forTier("Soggy") :: Zones.Zone).id, "Meadow")
	t.equal("the Disco egg to the Dune", (Zones.forTier("Disco") :: Zones.Zone).id, "Dune")
	t.equal("the Divine egg to the Cosmic Void", (Zones.forTier("Divine") :: Zones.Zone).id, "Cosmic")
	t.equal("the Cloud egg to the Sky Kingdom", (Zones.forTier("Cloud") :: Zones.Zone).id, "Sky")
	t.equal("limited eggs belong to no world", Zones.forTier("GooseGold"), nil)
	local homes = true
	for _, tier in Eggs.Tiers do
		if not Zones.forTier(tier.id) then
			homes = false
		end
	end
	t.check("every regular egg has a world", homes)
end
