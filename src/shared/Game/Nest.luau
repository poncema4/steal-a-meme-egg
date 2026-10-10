--!strict
-- A guarded nest holding one egg. Stealing empties it; it grows a new egg after a delay. Pure: the caller passes the
-- random function, so a test can pick the egg.
local Nest = {}

export type Nest = { tier: string?, regrow: number }

function Nest.new(tier: string): Nest
	return { tier = tier, regrow = 0 }
end

function Nest.hasEgg(n: Nest): boolean
	return n.tier ~= nil
end

-- Takes the egg out. Returns its tier, or nil if the nest is empty.
function Nest.take(n: Nest, regrowSeconds: number): string?
	local tier = n.tier
	if tier then
		n.tier = nil
		n.regrow = regrowSeconds
	end
	return tier
end

-- Puts a recovered egg back (the thief was caught).
function Nest.giveBack(n: Nest, tier: string)
	n.tier = tier
	n.regrow = 0
end

-- Counts down the regrow timer; when it ends the nest gets a new egg from `pick()`. Returns true on the tick it regrows.
function Nest.tick(n: Nest, dt: number, pick: () -> string): boolean
	if n.tier == nil then
		n.regrow -= dt
		if n.regrow <= 0 then
			n.tier = pick()
			n.regrow = 0
			return true
		end
	end
	return false
end

return Nest
