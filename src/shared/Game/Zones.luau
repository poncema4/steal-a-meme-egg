--!strict
-- The Wilds map: a long strip of themed terrains going east from the home bases. Each terrain has an unlock cost in Meme
-- Speed level, the eggs its guardians sit on, and how fast they chase. Pure data and lookups; the server builds the parts.
local Economy = require("./Economy")
local Progression = require("./Progression")

local Zones = {}

export type Zone = {
	id: string,
	name: string,
	level: number, -- the Speed level that is RECOMMENDED here: about when you can outrun this terrain's boss. Nothing blocks you.
	startX: number, -- the terrain covers startX to startX + length along the map
	length: number,
	nests: number, -- guarded eggs in this terrain
	guardianSpeed: number, -- studs per second
	boss: string, -- the meme character that guards the whole terrain (its model is Models.Bosses.Boss<id>)
	eggs: { string }, -- egg tiers its nests grow (the first is the common one)
	ground: { number }, -- r, g, b (0-255) of the floor
	sky: { number },
}

Zones.WIDTH = 320 -- every terrain is this wide (z from -WIDTH/2 to WIDTH/2)

-- Fifteen worlds, each 240 studs long, going east from the Safe Zone. Everyone may walk into any of them; the deeper ones simply have
-- bosses you can only outrun with a lot of speed, so the game does not end quickly.
Zones.List = {
	{
		id = "Meadow",
		boss = "SoggyToast",
		name = "Meme Meadow",
		level = 0,
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
		boss = "PharaohPancake",
		name = "Dune Desert",
		level = 3,
		startX = 250,
		length = 240,
		nests = 5,
		guardianSpeed = 20,
		eggs = { "Disco", "Spicy" },
		ground = { 240, 190, 90 },
		sky = { 255, 210, 140 },
	},
	{
		id = "Volcano",
		boss = "VolcanoVicar",
		name = "Lava Lands",
		level = 8,
		startX = 490,
		length = 240,
		nests = 5,
		guardianSpeed = 30,
		eggs = { "Spicy", "Golden" },
		ground = { 70, 40, 40 },
		sky = { 90, 40, 40 },
	},
	{
		id = "Frost",
		boss = "SleepySock",
		name = "Frozen Peaks",
		level = 14,
		startX = 730,
		length = 240,
		nests = 5,
		guardianSpeed = 42,
		eggs = { "Golden", "Cosmic" },
		ground = { 220, 240, 255 },
		sky = { 170, 210, 255 },
	},
	{
		id = "Cosmic",
		boss = "FinalBossHamster",
		name = "Cosmic Void",
		level = 22,
		startX = 970,
		length = 240,
		nests = 5,
		guardianSpeed = 56,
		eggs = { "Cosmic", "Divine" },
		ground = { 40, 30, 90 },
		sky = { 20, 10, 50 },
	},
	{
		id = "Swamp",
		boss = "SwampSensei",
		name = "Slime Swamp",
		level = 25,
		startX = 1210,
		length = 240,
		nests = 5,
		guardianSpeed = 60,
		eggs = { "Slime", "Candy" },
		ground = { 62, 112, 58 },
		sky = { 90, 130, 90 },
	},
	{
		id = "Candy",
		boss = "TaffyTitan",
		name = "Candy Canyon",
		level = 30,
		startX = 1450,
		length = 240,
		nests = 5,
		guardianSpeed = 64,
		eggs = { "Candy", "Neon" },
		ground = { 255, 150, 205 },
		sky = { 255, 205, 235 },
	},
	{
		id = "Neon",
		boss = "VaporVulture",
		name = "Neon City",
		level = 36,
		startX = 1690,
		length = 240,
		nests = 5,
		guardianSpeed = 68,
		eggs = { "Neon", "Cursed" },
		ground = { 36, 36, 62 },
		sky = { 60, 30, 110 },
	},
	{
		id = "Haunted",
		boss = "LichLasagna",
		name = "Haunted Hollow",
		level = 44,
		startX = 1930,
		length = 240,
		nests = 5,
		guardianSpeed = 72,
		eggs = { "Cursed", "Cloud" },
		ground = { 92, 72, 104 },
		sky = { 58, 40, 84 },
	},
	{
		id = "Sky",
		boss = "ZeusZucchini",
		name = "Sky Kingdom",
		level = 62,
		startX = 2170,
		length = 240,
		nests = 5,
		guardianSpeed = 76,
		eggs = { "Cloud", "Cloud" },
		ground = { 244, 250, 255 },
		sky = { 140, 200, 255 },
	},
	{
		id = "Toy",
		boss = "RubberDuckLord",
		name = "Toy Town",
		level = 68,
		startX = 2410,
		length = 240,
		nests = 5,
		guardianSpeed = 77,
		eggs = { "Toy", "Pirate" },
		ground = { 250, 96, 96 },
		sky = { 255, 230, 170 },
	},
	{
		id = "Pirate",
		boss = "DavyJonesDonut",
		name = "Pirate Cove",
		level = 73,
		startX = 2650,
		length = 240,
		nests = 5,
		guardianSpeed = 77.4,
		eggs = { "Pirate", "Robot" },
		ground = { 214, 188, 120 },
		sky = { 120, 200, 240 },
	},
	{
		id = "Robot",
		boss = "OmniOven",
		name = "Robot Factory",
		level = 80,
		startX = 2890,
		length = 240,
		nests = 5,
		guardianSpeed = 77.9,
		eggs = { "Robot", "Jungle" },
		ground = { 112, 118, 134 },
		sky = { 150, 160, 184 },
	},
	{
		id = "Jungle",
		boss = "TempleTofu",
		name = "Jungle Ruins",
		level = 87,
		startX = 3130,
		length = 240,
		nests = 5,
		guardianSpeed = 78.3,
		eggs = { "Jungle", "Throne" },
		ground = { 42, 124, 62 },
		sky = { 110, 172, 122 },
	},
	{
		id = "Throne",
		boss = "EmperorEggplant",
		name = "Meme Throne",
		level = 96,
		startX = 3370,
		length = 240,
		nests = 5,
		guardianSpeed = 78.6,
		eggs = { "Throne", "Throne" },
		ground = { 255, 214, 92 },
		sky = { 255, 236, 172 },
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

-- The deepest terrain whose recommended speed this Speed level has reached.
function Zones.furthest(level: number): Zone
	local best = Zones.List[1]
	for _, zone in Zones.List do
		if level >= zone.level then
			best = zone
		end
	end
	return best
end

-- The next terrain to aim for (its recommended speed is still ahead of you), or nil once you have passed them all.
function Zones.nextTarget(level: number): Zone?
	for _, zone in Zones.List do
		if level < zone.level then
			return zone
		end
	end
	return nil
end

-- The world an egg tier belongs to (for the Index): the terrain where it is the common egg, else the first that grows it. Limited
-- eggs belong to no terrain.
function Zones.forTier(tierId: string): Zone?
	for _, zone in Zones.List do
		if zone.eggs[1] == tierId then
			return zone
		end
	end
	for _, zone in Zones.List do
		if table.find(zone.eggs, tierId) then
			return zone
		end
	end
	return nil
end

-- The Speed number (as the HUD shows it) you reach at the level that is recommended for this terrain: "Recommended speed: 4.3K".
function Zones.speedLabel(zone: Zone): string
	return Economy.speed(Progression.speedStat(zone.level))
end

-- Which egg a nest grows: the common one most of the time, the rarer one 1 time in 4.
function Zones.eggFor(zone: Zone, rng: () -> number): string
	return if rng() < 0.75 then zone.eggs[1] else zone.eggs[2]
end

-- The first x that is NOT inside terrain `zone` going east: where the next gate stands.
function Zones.endX(zone: Zone): number
	return zone.startX + zone.length
end

-- The corridor walls in each terrain wear its theme: the wall colour and the lip along its top (the Safe Zone keeps tan and grass).
Zones.WallTheme = table.freeze({
	Safe = { wall = { 205, 150, 98 }, lip = { 90, 200, 60 } },
	Meadow = { wall = { 196, 142, 92 }, lip = { 90, 200, 60 } },
	Dune = { wall = { 226, 190, 120 }, lip = { 246, 218, 150 } },
	Volcano = { wall = { 72, 52, 52 }, lip = { 255, 110, 30 } },
	Frost = { wall = { 170, 210, 240 }, lip = { 245, 250, 255 } },
	Cosmic = { wall = { 62, 42, 112 }, lip = { 90, 230, 255 } },
	Swamp = { wall = { 86, 96, 60 }, lip = { 72, 140, 60 } },
	Candy = { wall = { 255, 160, 200 }, lip = { 255, 240, 250 } },
	Neon = { wall = { 32, 32, 64 }, lip = { 255, 60, 220 } },
	Haunted = { wall = { 92, 86, 102 }, lip = { 140, 90, 170 } },
	Sky = { wall = { 228, 238, 255 }, lip = { 255, 220, 120 } },
	Toy = { wall = { 60, 120, 230 }, lip = { 255, 210, 40 } },
	Pirate = { wall = { 140, 95, 55 }, lip = { 220, 190, 130 } },
	Robot = { wall = { 130, 140, 160 }, lip = { 250, 200, 30 } },
	Jungle = { wall = { 150, 140, 105 }, lip = { 60, 150, 60 } },
	Throne = { wall = { 150, 30, 50 }, lip = { 255, 200, 60 } },
})

-- The wall theme at position x along the corridor.
function Zones.wallThemeAt(x: number): { wall: { number }, lip: { number } }
	local zone = Zones.at(x)
	return Zones.WallTheme[if zone then zone.id else "Safe"] or Zones.WallTheme.Safe
end

return Zones
