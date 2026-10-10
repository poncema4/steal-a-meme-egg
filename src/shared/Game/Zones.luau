--!strict
-- The Wilds map: a long strip of themed terrains going east from the home bases. Each terrain has an unlock cost in Meme
-- Points, the eggs its guardians sit on, and how fast they chase. Pure data and lookups; the server builds the parts.
local Zones = {}

export type Zone = {
	id: string,
	name: string,
	mp: number, -- Meme Points needed to enter
	startX: number, -- the terrain covers startX to startX + length along the map
	length: number,
	nests: number, -- guarded eggs in this terrain
	guardianSpeed: number, -- studs per second
	eggs: { string }, -- egg tiers its nests grow (the first is the common one)
	ground: { number }, -- r, g, b (0-255) of the floor
	sky: { number },
}

Zones.WIDTH = 320 -- every terrain is this wide (z from -WIDTH/2 to WIDTH/2)
Zones.GATE_DEPTH = 6

Zones.List = {
	{
		id = "Meadow",
		name = "Meme Meadow",
		mp = 0,
		startX = 10,
		length = 240,
		nests = 5,
		guardianSpeed = 12,
		eggs = { "Soggy", "Disco" },
		ground = { 86, 190, 90 },
		sky = { 120, 190, 255 },
	},
	{
		id = "Dune",
		name = "Dune Desert",
		mp = 25,
		startX = 250,
		length = 240,
		nests = 5,
		guardianSpeed = 17,
		eggs = { "Disco", "Spicy" },
		ground = { 240, 190, 90 },
		sky = { 255, 210, 140 },
	},
	{
		id = "Volcano",
		name = "Lava Lands",
		mp = 250,
		startX = 490,
		length = 240,
		nests = 5,
		guardianSpeed = 21,
		eggs = { "Spicy", "Golden" },
		ground = { 70, 40, 40 },
		sky = { 90, 40, 40 },
	},
	{
		id = "Frost",
		name = "Frozen Peaks",
		mp = 2500,
		startX = 730,
		length = 240,
		nests = 5,
		guardianSpeed = 25,
		eggs = { "Golden", "Cosmic" },
		ground = { 220, 240, 255 },
		sky = { 170, 210, 255 },
	},
	{
		id = "Cosmic",
		name = "Cosmic Void",
		mp = 20000,
		startX = 970,
		length = 240,
		nests = 5,
		guardianSpeed = 29,
		eggs = { "Cosmic", "Divine" },
		ground = { 40, 30, 90 },
		sky = { 20, 10, 50 },
	},
} :: { Zone }

local byId: { [string]: Zone } = {}
for _, zone in Zones.List do
	byId[zone.id] = zone
end

function Zones.get(id: string): Zone?
	return byId[id]
end

-- The terrain covering this x position, or nil (the home area and the gap before the first terrain have none).
function Zones.at(x: number): Zone?
	for _, zone in Zones.List do
		if x >= zone.startX and x < zone.startX + zone.length then
			return zone
		end
	end
	return nil
end

function Zones.unlocked(zone: Zone, mp: number): boolean
	return mp >= zone.mp
end

-- The furthest terrain this many Meme Points reaches.
function Zones.furthest(mp: number): Zone
	local best = Zones.List[1]
	for _, zone in Zones.List do
		if mp >= zone.mp then
			best = zone
		end
	end
	return best
end

-- The next terrain still locked, or nil if everything is open.
function Zones.nextLocked(mp: number): Zone?
	for _, zone in Zones.List do
		if mp < zone.mp then
			return zone
		end
	end
	return nil
end

-- Which egg a nest grows: the common one most of the time, the rarer one 1 time in 4.
function Zones.eggFor(zone: Zone, rng: () -> number): string
	return if rng() < 0.75 then zone.eggs[1] else zone.eggs[2]
end

-- The first x that is NOT inside terrain `zone` going east: where the next gate stands.
function Zones.endX(zone: Zone): number
	return zone.startX + zone.length
end

-- Where a player standing at x should be pushed back to if they are in a terrain they have not unlocked: just
-- before that terrain's entrance. Returns nil if x is fine.
function Zones.pushBack(x: number, mp: number): number?
	local zone = Zones.at(x)
	if zone and not Zones.unlocked(zone, mp) then
		return zone.startX - 4
	end
	return nil
end

return Zones
