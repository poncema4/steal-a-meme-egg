--!strict
-- The egg and character tables, and the hatch roll. Pure: the caller passes the random function and a luck multiplier,
-- so tests can force any outcome. Characters are our own cast; names are jokes, not anyone else's characters.
local Eggs = {}

export type Entry = { id: string, weight: number }
export type Tier = { id: string, name: string, price: number, hatchSeconds: number, pool: { Entry } }
export type Character = { id: string, name: string, rarity: string, income: number }

local COMMON, RARE, EPIC = "Common", "Rare", "Epic"

-- pool entries are ordered from most common to rarest: luck makes the later ones likelier
Eggs.Tiers = {
	{
		id = "Soggy",
		name = "Soggy Egg",
		price = 100,
		hatchSeconds = 8,
		pool = {
			{ id = "SoggyToast", weight = 60 },
			{ id = "BonkBean", weight = 30 },
			{ id = "SleepySock", weight = 10 },
		},
	},
	{
		id = "Disco",
		name = "Disco Egg",
		price = 1000,
		hatchSeconds = 15,
		pool = {
			{ id = "DiscoPickle", weight = 60 },
			{ id = "GigachadGoose", weight = 30 },
			{ id = "MoonwalkMoth", weight = 10 },
		},
	},
	{
		id = "Spicy",
		name = "Spicy Egg",
		price = 10000,
		hatchSeconds = 30,
		pool = {
			{ id = "ChiliChihuahua", weight = 60 },
			{ id = "LavaLatte", weight = 30 },
			{ id = "VolcanoVicar", weight = 10 },
		},
	},
	{
		id = "Golden",
		name = "Golden Egg",
		price = 100000,
		hatchSeconds = 60,
		pool = {
			{ id = "PharaohPancake", weight = 60 },
			{ id = "SphinxSneaker", weight = 30 },
			{ id = "CleoCroissant", weight = 10 },
		},
	},
	{
		id = "Cosmic",
		name = "Cosmic Egg",
		price = 1000000,
		hatchSeconds = 120,
		pool = {
			{ id = "NebulaNoodle", weight = 60 },
			{ id = "QuasarQuokka", weight = 30 },
			{ id = "BlackHoleBagel", weight = 10 },
		},
	},
	{
		id = "Divine",
		name = "Divine Egg",
		price = 100000000,
		hatchSeconds = 300,
		pool = {
			{ id = "TaxAngel", weight = 70 },
			{ id = "FinalBossHamster", weight = 25 },
			{ id = "OmegaMeme", weight = 5 },
		},
	},
	{
		id = "Slime",
		name = "Slime Egg",
		price = 10000000000,
		hatchSeconds = 360,
		pool = {
			{ id = "GloopGoblin", weight = 60 },
			{ id = "BogBurrito", weight = 30 },
			{ id = "SwampSensei", weight = 10 },
		},
	},
	{
		id = "Candy",
		name = "Candy Egg",
		price = 1000000000000,
		hatchSeconds = 420,
		pool = {
			{ id = "SprinkleSloth", weight = 60 },
			{ id = "GummyGolem", weight = 30 },
			{ id = "TaffyTitan", weight = 10 },
		},
	},
	{
		id = "Neon",
		name = "Neon Egg",
		price = 100000000000000,
		hatchSeconds = 480,
		pool = {
			{ id = "PixelPigeon", weight = 60 },
			{ id = "SynthSquid", weight = 30 },
			{ id = "VaporVulture", weight = 10 },
		},
	},
	{
		id = "Cursed",
		name = "Cursed Egg",
		price = 1e16,
		hatchSeconds = 540,
		pool = {
			{ id = "BooBanana", weight = 60 },
			{ id = "MummyMuffin", weight = 30 },
			{ id = "LichLasagna", weight = 10 },
		},
	},
	{
		id = "Cloud",
		name = "Cloud Egg",
		price = 1e18,
		hatchSeconds = 600,
		pool = {
			{ id = "NimbusNugget", weight = 60 },
			{ id = "StormSandwich", weight = 30 },
			{ id = "ZeusZucchini", weight = 10 },
		},
	},
	{
		id = "Toy",
		name = "Toy Egg",
		price = 1e20,
		hatchSeconds = 660,
		pool = {
			{ id = "BrickBuddy", weight = 60 },
			{ id = "WobblyWindup", weight = 30 },
			{ id = "RubberDuckLord", weight = 10 },
		},
	},
	{
		id = "Pirate",
		name = "Pirate Egg",
		price = 1e22,
		hatchSeconds = 720,
		pool = {
			{ id = "CaptainCrouton", weight = 60 },
			{ id = "KrakenKebab", weight = 30 },
			{ id = "DavyJonesDonut", weight = 10 },
		},
	},
	{
		id = "Robot",
		name = "Robot Egg",
		price = 1e24,
		hatchSeconds = 780,
		pool = {
			{ id = "ToasterTron", weight = 60 },
			{ id = "MicrowaveMike", weight = 30 },
			{ id = "OmniOven", weight = 10 },
		},
	},
	{
		id = "Jungle",
		name = "Jungle Egg",
		price = 1e26,
		hatchSeconds = 840,
		pool = {
			{ id = "BananaBandit", weight = 60 },
			{ id = "TikiTaco", weight = 30 },
			{ id = "TempleTofu", weight = 10 },
		},
	},
	{
		id = "Throne",
		name = "Throne Egg",
		price = 1e28,
		hatchSeconds = 900,
		pool = {
			{ id = "CrownCookie", weight = 60 },
			{ id = "RoyalRamen", weight = 30 },
			{ id = "EmperorEggplant", weight = 10 },
		},
	},
} :: { Tier }

-- Limited eggs: not in the Wilds. One rotates in every half hour with a shared stock (Shared/Game/Limited).
Eggs.LimitedTiers = {
	{
		id = "GooseGold",
		name = "Golden Goose Egg",
		price = 1e29,
		hatchSeconds = 600,
		pool = {
			{ id = "GoldenGoose", weight = 60 },
			{ id = "PlatinumGoose", weight = 30 },
			{ id = "MythicGoose", weight = 10 },
		},
	},
	{
		id = "CatCosmic",
		name = "Cosmic Cat Egg",
		price = 1e29,
		hatchSeconds = 600,
		pool = {
			{ id = "CosmicKitten", weight = 60 },
			{ id = "NebulaCat", weight = 30 },
			{ id = "GalaxyTiger", weight = 10 },
		},
	},
	{
		id = "MemeLord",
		name = "Meme Lord Egg",
		price = 1e29,
		hatchSeconds = 600,
		pool = {
			{ id = "MemeLordJr", weight = 60 },
			{ id = "MemeLordPrime", weight = 30 },
			{ id = "MemeLordOmega", weight = 10 },
		},
	},
} :: { Tier }

local function char(id: string, name: string, rarity: string, income: number): Character
	return { id = id, name = name, rarity = rarity, income = income }
end

Eggs.Characters = {
	SoggyToast = char("SoggyToast", "Soggy Toast", COMMON, 1),
	BonkBean = char("BonkBean", "Bonk Bean", RARE, 2),
	SleepySock = char("SleepySock", "Sleepy Sock", EPIC, 4),
	DiscoPickle = char("DiscoPickle", "Disco Pickle", COMMON, 12),
	GigachadGoose = char("GigachadGoose", "Gigachad Goose", RARE, 25),
	MoonwalkMoth = char("MoonwalkMoth", "Moonwalk Moth", EPIC, 50),
	ChiliChihuahua = char("ChiliChihuahua", "Chili Chihuahua", COMMON, 150),
	LavaLatte = char("LavaLatte", "Lava Latte", RARE, 300),
	VolcanoVicar = char("VolcanoVicar", "Volcano Vicar", EPIC, 600),
	PharaohPancake = char("PharaohPancake", "Pharaoh Pancake", COMMON, 2000),
	SphinxSneaker = char("SphinxSneaker", "Sphinx Sneaker", RARE, 4000),
	CleoCroissant = char("CleoCroissant", "Cleo Croissant", EPIC, 8000),
	NebulaNoodle = char("NebulaNoodle", "Nebula Noodle", COMMON, 30000),
	QuasarQuokka = char("QuasarQuokka", "Quasar Quokka", RARE, 60000),
	BlackHoleBagel = char("BlackHoleBagel", "Black Hole Bagel", EPIC, 120000),
	TaxAngel = char("TaxAngel", "Tax Angel", "Legendary", 1500000),
	FinalBossHamster = char("FinalBossHamster", "Final Boss Hamster", "Legendary", 4000000),
	OmegaMeme = char("OmegaMeme", "Omega Meme", "Mythic", 12000000),
	GloopGoblin = char("GloopGoblin", "Gloop Goblin", COMMON, 80000000),
	BogBurrito = char("BogBurrito", "Bog Burrito", RARE, 240000000),
	SwampSensei = char("SwampSensei", "Swamp Sensei", EPIC, 800000000),
	SprinkleSloth = char("SprinkleSloth", "Sprinkle Sloth", COMMON, 8000000000),
	GummyGolem = char("GummyGolem", "Gummy Golem", RARE, 24000000000),
	TaffyTitan = char("TaffyTitan", "Taffy Titan", EPIC, 80000000000),
	PixelPigeon = char("PixelPigeon", "Pixel Pigeon", COMMON, 800000000000),
	SynthSquid = char("SynthSquid", "Synth Squid", RARE, 2400000000000),
	VaporVulture = char("VaporVulture", "Vapor Vulture", EPIC, 8000000000000),
	BooBanana = char("BooBanana", "Boo Banana", COMMON, 80000000000000),
	MummyMuffin = char("MummyMuffin", "Mummy Muffin", RARE, 240000000000000),
	LichLasagna = char("LichLasagna", "Lich Lasagna", EPIC, 800000000000000),
	NimbusNugget = char("NimbusNugget", "Nimbus Nugget", COMMON, 8000000000000000),
	StormSandwich = char("StormSandwich", "Storm Sandwich", RARE, 2.4e16),
	ZeusZucchini = char("ZeusZucchini", "Zeus Zucchini", EPIC, 8e16),
	BrickBuddy = char("BrickBuddy", "Brick Buddy", COMMON, 8e17),
	WobblyWindup = char("WobblyWindup", "Wobbly Windup", RARE, 2.4e18),
	RubberDuckLord = char("RubberDuckLord", "Rubber Duck Lord", EPIC, 8e18),
	CaptainCrouton = char("CaptainCrouton", "Captain Crouton", COMMON, 8e19),
	KrakenKebab = char("KrakenKebab", "Kraken Kebab", RARE, 2.4e20),
	DavyJonesDonut = char("DavyJonesDonut", "Davy Jones Donut", EPIC, 8e20),
	ToasterTron = char("ToasterTron", "Toaster Tron", COMMON, 8e21),
	MicrowaveMike = char("MicrowaveMike", "Microwave Mike", RARE, 2.4e22),
	OmniOven = char("OmniOven", "Omni Oven", EPIC, 8e22),
	BananaBandit = char("BananaBandit", "Banana Bandit", COMMON, 8e23),
	TikiTaco = char("TikiTaco", "Tiki Taco", RARE, 2.4e24),
	TempleTofu = char("TempleTofu", "Temple Tofu", EPIC, 8e24),
	CrownCookie = char("CrownCookie", "Crown Cookie", COMMON, 8e25),
	RoyalRamen = char("RoyalRamen", "Royal Ramen", RARE, 2.4e26),
	EmperorEggplant = char("EmperorEggplant", "Emperor Eggplant", EPIC, 8e26),
	GoldenGoose = char("GoldenGoose", "Golden Goose", "Limited", 1.5e27),
	PlatinumGoose = char("PlatinumGoose", "Platinum Goose", "Limited", 3e27),
	MythicGoose = char("MythicGoose", "Mythic Goose", "Limited", 6e27),
	CosmicKitten = char("CosmicKitten", "Cosmic Kitten", "Limited", 1.8e27),
	NebulaCat = char("NebulaCat", "Nebula Cat", "Limited", 3.6e27),
	GalaxyTiger = char("GalaxyTiger", "Galaxy Tiger", "Limited", 7e27),
	MemeLordJr = char("MemeLordJr", "Meme Lord Jr", "Limited", 2e27),
	MemeLordPrime = char("MemeLordPrime", "Meme Lord Prime", "Limited", 4e27),
	MemeLordOmega = char("MemeLordOmega", "Meme Lord Omega", "Limited", 8e27),
} :: { [string]: Character }

-- a mutated character earns more
Eggs.Mutations = { Normal = 1, Gold = 2, Rainbow = 5 } :: { [string]: number }

local tierIndex: { [string]: Tier } = {}
for _, tier in Eggs.Tiers do
	tierIndex[tier.id] = tier
end
for _, tier in Eggs.LimitedTiers do
	tierIndex[tier.id] = tier
end

function Eggs.tier(id: string): Tier?
	return tierIndex[id]
end

function Eggs.character(id: string): Character?
	return Eggs.Characters[id]
end

-- Picks a character from the egg's pool. `luck` is a multiplier (1 = normal, 2 = Lucky Hour): the n-th rarest entry's
-- weight is multiplied by luck^(n-1), so more luck shifts the odds toward the rare end. `rng` returns [0, 1).
function Eggs.roll(tierId: string, luck: number, rng: () -> number): string
	local tier = tierIndex[tierId]
	assert(tier, `unknown egg tier {tierId}`)
	local weights, total = {}, 0
	for i, entry in tier.pool do
		local w = entry.weight * math.max(luck, 1) ^ (i - 1)
		weights[i] = w
		total += w
	end
	local pick = rng() * total
	for i, entry in tier.pool do
		pick -= weights[i]
		if pick < 0 then
			return entry.id
		end
	end
	return tier.pool[#tier.pool].id
end

-- 1 in 20 is Gold (x2), 1 in 100 is Rainbow (x5); luck helps a little.
-- A nest egg's mutation. `depth` is the terrain number (1 = Meadow): deeper terrains grow Gold and Rainbow eggs more often.
-- The egg keeps it all the way home and its pet is born with it.
function Eggs.nestMutation(depth: number, rng: () -> number): string
	local d = math.max(depth, 1)
	local rainbow = math.min(0.02 + 0.015 * (d - 1), 0.12)
	local gold = math.min(0.08 + 0.04 * (d - 1), 0.4)
	local r = rng()
	if r < rainbow then
		return "Rainbow"
	elseif r < rainbow + gold then
		return "Gold"
	end
	return "Normal"
end

function Eggs.mutation(luck: number, rng: () -> number): string
	local r = rng() * math.max(luck, 1)
	if r > 0.99 then
		return "Rainbow"
	elseif r > 0.95 then
		return "Gold"
	end
	return "Normal"
end

-- A character's aura: the number shown in a face-off. Grows with income, so rarer is always stronger.
function Eggs.aura(characterId: string, mutation: string?): number
	local c = Eggs.Characters[characterId]
	if not c then
		return 0
	end
	return math.floor(math.sqrt(c.income * (Eggs.Mutations[mutation or "Normal"] or 1)) * 10)
end

return Eggs
