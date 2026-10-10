--!strict
-- A small deterministic random generator (Park-Miller). The world's scenery and nest positions come from this instead of
-- Roblox's Random, so the map is identical on every server, in the tests and in the layout preview: what a test checks is
-- exactly what players get.
local Rng = {}

export type Rng = { state: number }

local MODULUS = 2147483647
local MULTIPLIER = 48271

function Rng.new(seed: number): Rng
	-- NaN and infinity would poison every number after them, so they fall back to a fixed seed.
	if seed ~= seed or seed == math.huge or seed == -math.huge then
		seed = 1
	end
	local s = math.floor(math.abs(seed)) % (MODULUS - 1) + 1
	return { state = s }
end

-- The next number in [0, 1).
function Rng.next(r: Rng): number
	r.state = (r.state * MULTIPLIER) % MODULUS
	return (r.state - 1) / (MODULUS - 1)
end

-- A number in [lo, hi).
function Rng.range(r: Rng, lo: number, hi: number): number
	return lo + Rng.next(r) * (hi - lo)
end

return Rng
