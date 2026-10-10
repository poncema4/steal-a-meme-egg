--!strict
-- A guarded nest holding one egg. Stealing empties it; it grows a new egg after a delay. Pure: the caller passes the
-- random function, so a test can pick the egg.
local Nest = {}

export type Nest = { tier: string?, mutation: string, regrow: number }

function Nest.new(tier: string, mutation: string?): Nest
	return { tier = tier, mutation = mutation or "Normal", regrow = 0 }
end

function Nest.hasEgg(n: Nest): boolean
	return n.tier ~= nil
end

-- Takes the egg out. Returns its tier and mutation, or nil if the nest is empty.
function Nest.take(n: Nest, regrowSeconds: number): (string?, string)
	local tier, mutation = n.tier, n.mutation
	if tier then
		n.tier = nil
		n.mutation = "Normal"
		n.regrow = regrowSeconds
	end
	return tier, mutation
end

-- Puts a recovered egg back (the thief was caught).
function Nest.giveBack(n: Nest, tier: string, mutation: string?)
	n.tier = tier
	n.mutation = mutation or "Normal"
	n.regrow = 0
end

-- Counts down the regrow timer; when it ends the nest gets a new egg from `pick()`. Returns true on the tick it regrows.
function Nest.tick(n: Nest, dt: number, pick: () -> (string, string?)): boolean
	if n.tier == nil then
		n.regrow -= dt
		if n.regrow <= 0 then
			local tier, mutation = pick()
			n.tier = tier
			n.mutation = mutation or "Normal"
			n.regrow = 0
			return true
		end
	end
	return false
end

return Nest
