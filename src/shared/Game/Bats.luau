--!strict
-- The bat every player carries. Everyone starts with the Wooden Bat; completing a world's Index unlocks the next, better bat.
-- A swing knocks another player back and stuns them for a moment, and a runner who is hit drops the egg they carry where they
-- stand. Pure data and rules: the server does the swinging, the models are built by art/brick/bats.py.
local Bats = {}

export type Bat = {
	id: string,
	name: string,
	knock: number, -- studs a second the victim is thrown
	stun: number, -- seconds they stay down
	range: number, -- studs the swing reaches
	cooldown: number, -- seconds between swings
	head: { number }, -- r, g, b of the hitting end
	handle: { number },
}

type Look = { name: string, head: { number }, handle: { number } }
local LOOKS: { Look } = {
	{ name = "Wooden", head = { 190, 140, 80 }, handle = { 120, 80, 40 } },
	{ name = "Foam", head = { 255, 120, 190 }, handle = { 255, 230, 120 } },
	{ name = "Rubber", head = { 90, 200, 120 }, handle = { 40, 120, 70 } },
	{ name = "Stone", head = { 150, 150, 160 }, handle = { 90, 90, 100 } },
	{ name = "Iron", head = { 170, 180, 200 }, handle = { 80, 85, 100 } },
	{ name = "Silver", head = { 225, 230, 245 }, handle = { 120, 130, 160 } },
	{ name = "Golden", head = { 255, 205, 60 }, handle = { 190, 130, 20 } },
	{ name = "Ruby", head = { 235, 50, 80 }, handle = { 120, 20, 40 } },
	{ name = "Emerald", head = { 60, 220, 130 }, handle = { 20, 110, 70 } },
	{ name = "Frost", head = { 170, 225, 255 }, handle = { 90, 150, 220 } },
	{ name = "Lava", head = { 255, 130, 30 }, handle = { 120, 30, 20 } },
	{ name = "Neon", head = { 60, 240, 255 }, handle = { 255, 60, 240 } },
	{ name = "Ghost", head = { 235, 235, 255 }, handle = { 130, 110, 200 } },
	{ name = "Cloud", head = { 255, 255, 255 }, handle = { 150, 205, 255 } },
	{ name = "Galaxy", head = { 140, 90, 255 }, handle = { 40, 30, 110 } },
	{ name = "Divine", head = { 255, 245, 190 }, handle = { 255, 205, 60 } },
}

Bats.List = {} :: { Bat }
for tier, look in LOOKS do
	local k = tier - 1
	table.insert(Bats.List, {
		id = string.lower(look.name),
		name = `{look.name} Bat`,
		knock = 38 + 5 * k,
		stun = math.min(0.6 + 0.05 * k, 1.35),
		range = 7 + 0.25 * k,
		cooldown = math.max(0.9 - 0.03 * k, 0.45),
		head = look.head,
		handle = look.handle,
	})
end

Bats.MAX_TIER = #Bats.List - 1 -- tiers run from 0 (the starting bat) to this

-- The bat tier for this many completed worlds.
function Bats.tierFor(completed: number): number
	if completed ~= completed then
		return 0
	end
	return math.clamp(math.floor(completed), 0, Bats.MAX_TIER)
end

function Bats.get(tier: number): Bat
	return Bats.List[Bats.tierFor(tier) + 1]
end

-- Can a swing from `from` hit `to`? Both are positions in the world; `facing` is the swinger's look direction (flat). The target has to
-- be within reach and in the half-space in front of the swinger.
function Bats.reaches(
	bat: Bat,
	fromX: number,
	fromZ: number,
	facingX: number,
	facingZ: number,
	toX: number,
	toZ: number
): boolean
	local dx, dz = toX - fromX, toZ - fromZ
	local distance = math.sqrt(dx * dx + dz * dz)
	if distance > bat.range or distance ~= distance then
		return false
	end
	if distance < 1e-6 then
		return true
	end
	local flat = math.sqrt(facingX * facingX + facingZ * facingZ)
	if flat < 1e-6 then
		return false
	end
	local dot = (dx * facingX + dz * facingZ) / (distance * flat)
	return dot > 0.25
end

return Bats
