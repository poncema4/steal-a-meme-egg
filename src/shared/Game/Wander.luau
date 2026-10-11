--!strict
-- How a pet roams its patch of the pen. Pure and deterministic: where a pet is depends only on its seed and the clock, so every
-- player sees the same walk without the server sending a thing, and a test can check that it is smooth and never leaves the patch.
local Wander = {}

Wander.LEG = 7 -- seconds per leg: a rest, then a walk to the next spot
Wander.REST = 0.32 -- the fraction of a leg spent standing still before walking

-- A tiny integer hash to a number in [0, 1): different per seed and per leg, the same every time.
local function unit(seed: number, leg: number, salt: number): number
	local n = (seed * 73856093 + leg * 19349663 + salt * 83492791) % 2147483647
	n = (n * 1103515245 + 12345) % 2147483647
	n = (n * 1103515245 + 12345) % 2147483647
	return n / 2147483647
end

-- The spot a pet stands at the start of leg `leg`, inside a disc of `radius` around its home.
local function spot(seed: number, leg: number, radius: number): (number, number)
	local angle = unit(seed, leg, 1) * math.pi * 2
	local distance = math.sqrt(unit(seed, leg, 2)) * radius
	return math.cos(angle) * distance, math.sin(angle) * distance
end

export type Pose = { x: number, z: number, dirX: number, dirZ: number, walking: boolean, stride: number }

-- Where the pet is at time `t` (seconds), as an offset from home, which way it is heading, and whether its legs are moving.
-- `stride` runs 0 to 1 over each step, for the bob.
function Wander.pose(seed: number, t: number, radius: number): Pose
	local leg = math.floor(t / Wander.LEG)
	local into = (t - leg * Wander.LEG) / Wander.LEG
	local ax, az = spot(seed, leg, radius)
	local bx, bz = spot(seed, leg + 1, radius)
	local dx, dz = bx - ax, bz - az
	local length = math.sqrt(dx * dx + dz * dz)
	local dirX, dirZ = 1, 0
	if length > 1e-6 then
		dirX, dirZ = dx / length, dz / length
	end
	if into < Wander.REST then
		return { x = ax, z = az, dirX = dirX, dirZ = dirZ, walking = false, stride = 0 }
	end
	local k = (into - Wander.REST) / (1 - Wander.REST)
	local eased = k * k * (3 - 2 * k) -- starts and stops gently
	local steps = math.max(length / 1.6, 1) -- about one step every 1.6 studs
	return {
		x = ax + dx * eased,
		z = az + dz * eased,
		dirX = dirX,
		dirZ = dirZ,
		walking = true,
		stride = (k * steps) % 1,
	}
end

-- The fastest a pet ever moves, in studs per second, for a patch of this radius (a test checks they never zoom).
function Wander.topSpeed(radius: number): number
	return 2 * radius * 1.5 / (Wander.LEG * (1 - Wander.REST))
end

return Wander
