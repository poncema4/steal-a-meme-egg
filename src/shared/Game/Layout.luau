--!strict
-- Where things stand in the Wilds: the nests and the scenery, computed from the zone alone with the deterministic Rng. Every
-- server, every test and the layout preview get exactly the same map, and the rules about it (nests far apart, scenery never
-- on top of a nest or its guardian) are tested here instead of hoped for.
local Rng = require("./Rng")
local Zones = require("./Zones")

local Layout = {}

export type Nest = { x: number, z: number, tier: string }
export type Prop = { x: number, z: number, size: number, extra: number }

Layout.GUARDIAN_OFFSET = 9 -- a guardian sits this far east of its egg
Layout.CLEAR = 16 -- scenery stays at least this far from a nest and its guardian
Layout.PROPS = 28
Layout.BOSS_CLEAR = 20 -- scenery and nests stay this far from the terrain's boss

-- Where the terrain's boss stands: the middle of the strip.
function Layout.bossSpot(zone: Zones.Zone): { x: number, z: number }
	return { x = zone.startX + zone.length / 2, z = 0 }
end

function Layout.nests(zone: Zones.Zone): { Nest }
	local rng = Rng.new(zone.startX + 7)
	local list = {}
	for i = 1, zone.nests do
		local x = zone.startX + 25 + (i - 1) * ((zone.length - 50) / math.max(zone.nests - 1, 1))
		local side = if i % 2 == 0 then 1 else -1
		local z = side * (22 + Rng.next(rng) * 55)
		local tier = Zones.eggFor(zone, function()
			return Rng.next(rng)
		end)
		table.insert(list, { x = x, z = z, tier = tier })
	end
	return list
end

local function nearNest(x: number, z: number, nests: { Nest }, zone: Zones.Zone): boolean
	local boss = Layout.bossSpot(zone)
	if math.sqrt((x - boss.x) ^ 2 + (z - boss.z) ^ 2) < Layout.BOSS_CLEAR then
		return true
	end
	for _, n in nests do
		for _, spot in { n.x, n.x + Layout.GUARDIAN_OFFSET } do
			if math.sqrt((x - spot) ^ 2 + (z - n.z) ^ 2) < Layout.CLEAR then
				return true
			end
		end
	end
	return false
end

-- The scenery props of a terrain. Each is tried a few times so it can be moved off a nest or the gate.
function Layout.scenery(zone: Zones.Zone, nests: { Nest }): { Prop }
	local rng = Rng.new(zone.startX)
	local list = {}
	for _ = 1, Layout.PROPS do
		for _ = 1, 8 do
			local x = zone.startX + 12 + Rng.next(rng) * (zone.length - 24)
			local z = (Rng.next(rng) - 0.5) * (Zones.WIDTH - 20)
			local size = 3 + Rng.next(rng) * 5
			local extra = Rng.next(rng)
			if not nearNest(x, z, nests, zone) and x > zone.startX + Zones.GATE_DEPTH + 8 then
				table.insert(list, { x = x, z = z, size = size, extra = extra })
				break
			end
		end
	end
	return list
end

return Layout
