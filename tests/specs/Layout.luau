--!strict
local Layout = require("../../src/shared/Game/Layout")
local Rng = require("../../src/shared/Game/Rng")
local Zones = require("../../src/shared/Game/Zones")

return function(t)
	-- the generator
	local a, b = Rng.new(42), Rng.new(42)
	local same = true
	for _ = 1, 100 do
		if Rng.next(a) ~= Rng.next(b) then
			same = false
		end
	end
	t.check("the same seed gives the same numbers", same)
	local c, d = Rng.new(1), Rng.new(2)
	local differs = false
	for _ = 1, 10 do
		if Rng.next(c) ~= Rng.next(d) then
			differs = true
		end
	end
	t.check("different seeds give different numbers", differs)
	local r = Rng.new(7)
	local sum, inside = 0, true
	local n = 20000
	for _ = 1, n do
		local v = Rng.next(r)
		sum += v
		if v < 0 or v >= 1 or v ~= v then
			inside = false
		end
	end
	t.check("every number is in [0, 1)", inside)
	t.check("and they average about one half", math.abs(sum / n - 0.5) < 0.01, tostring(sum / n))
	local ranged = true
	for _ = 1, 1000 do
		local v = Rng.range(r, 5, 9)
		if v < 5 or v >= 9 then
			ranged = false
		end
	end
	t.check("range stays inside its bounds", ranged)
	local weirdSeeds = true
	for _, seed in { 0, -1, 1.5, 2 ^ 31, 1e12, 0 / 0 } do
		local g = Rng.new(seed)
		local v = Rng.next(g)
		if v ~= v or v < 0 or v >= 1 then
			weirdSeeds = false
		end
	end
	t.check("strange seeds still work", weirdSeeds)

	-- the layout of every terrain
	for _, zone in Zones.List do
		local nests = Layout.nests(zone)
		t.equal(`{zone.id}: the right number of nests`, #nests, zone.nests)
		local again = Layout.nests(zone)
		local identical = #again == #nests
		for i, nest in nests do
			if again[i].x ~= nest.x or again[i].z ~= nest.z or again[i].tier ~= nest.tier then
				identical = false
			end
		end
		t.check(`{zone.id}: the layout is the same every time`, identical)

		local inBounds, tiersOk, farApart, guardiansOk = true, true, true, true
		for i, nest in nests do
			if
				nest.x < zone.startX + 10
				or nest.x > Zones.endX(zone) - 10
				or math.abs(nest.z) > Zones.WIDTH / 2 - 15
			then
				inBounds = false
			end
			local gx = nest.x + Layout.GUARDIAN_OFFSET
			if gx > Zones.endX(zone) - 5 or math.abs(nest.z) > Zones.WIDTH / 2 - 10 then
				guardiansOk = false
			end
			if not table.find(zone.eggs, nest.tier) then
				tiersOk = false
			end
			for j = i + 1, #nests do
				if math.sqrt((nest.x - nests[j].x) ^ 2 + (nest.z - nests[j].z) ^ 2) < 30 then
					farApart = false
				end
			end
		end
		t.check(`{zone.id}: every nest is well inside its terrain and the walls`, inBounds)
		t.check(`{zone.id}: every guardian stands inside the terrain too`, guardiansOk)
		t.check(`{zone.id}: nests are at least 30 studs apart`, farApart)
		t.check(`{zone.id}: nests only grow that terrain's eggs`, tiersOk)

		local props = Layout.scenery(zone, nests)
		t.check(`{zone.id}: there is scenery`, #props >= 20, tostring(#props))
		local clear, boundsOk, gateClear = true, true, true
		for _, prop in props do
			for _, nest in nests do
				for _, spot in { nest.x, nest.x + Layout.GUARDIAN_OFFSET } do
					if math.sqrt((prop.x - spot) ^ 2 + (prop.z - nest.z) ^ 2) < Layout.CLEAR then
						clear = false
					end
				end
			end
			if prop.x < zone.startX or prop.x > Zones.endX(zone) or math.abs(prop.z) > Zones.WIDTH / 2 then
				boundsOk = false
			end
			if prop.x < zone.startX + 14 then
				gateClear = false
			end
			local boss = Layout.bossSpot(zone)
			if math.sqrt((prop.x - boss.x) ^ 2 + (prop.z - boss.z) ^ 2) < Layout.BOSS_CLEAR then
				clear = false
			end
		end
		t.check(`{zone.id}: no scenery on top of a nest or its guardian`, clear)
		t.check(`{zone.id}: scenery stays inside the terrain`, boundsOk)
		t.check(`{zone.id}: the gate is not blocked by scenery`, gateClear)
	end
end
