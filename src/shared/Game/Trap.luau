--!strict
-- Traps: a player may have at most 3 on the ground at once. A trap stuns a chasing guardian that runs over it, then is used up;
-- an untouched trap rots away after a while. Pure rules (time is passed in), the server builds the parts.
local Trap = {}

Trap.MAX = 3 -- placed at once, per player
Trap.RADIUS = 5 -- studs: how close a guardian must come to spring it
Trap.LIFETIME = 90 -- seconds before an unused trap disappears
Trap.COOLDOWN = 2 -- seconds between placing two traps
Trap.STUN = 3.5 -- seconds a sprung trap holds a guardian

export type Spot = { x: number, z: number, expires: number }
export type State = { spots: { Spot }, lastPlaced: number }

function Trap.new(): State
	return { spots = {}, lastPlaced = -math.huge }
end

-- Why a trap cannot be placed right now, or nil if it can.
function Trap.why(s: State, now: number): string?
	Trap.prune(s, now)
	if #s.spots >= Trap.MAX then
		return "You can only have 3 traps out at once"
	end
	if now - s.lastPlaced < Trap.COOLDOWN then
		return "Your next trap is not ready yet"
	end
	return nil
end

-- Places a trap. Returns (true, nil) or (false, the reason).
function Trap.place(s: State, x: number, z: number, now: number): (boolean, string?)
	if x ~= x or z ~= z or math.abs(x) == math.huge or math.abs(z) == math.huge then
		return false, "bad position"
	end
	local reason = Trap.why(s, now)
	if reason then
		return false, reason
	end
	table.insert(s.spots, { x = x, z = z, expires = now + Trap.LIFETIME })
	s.lastPlaced = now
	return true, nil
end

-- Removes traps that ran out; returns how many were removed.
function Trap.prune(s: State, now: number): number
	local removed = 0
	for i = #s.spots, 1, -1 do
		if s.spots[i].expires <= now then
			table.remove(s.spots, i)
			removed += 1
		end
	end
	return removed
end

-- A guardian at (x, z): the index of the nearest trap it has run onto, or nil.
function Trap.hit(s: State, x: number, z: number): number?
	local best, bestD = nil, Trap.RADIUS
	for i, spot in s.spots do
		local d = math.sqrt((spot.x - x) ^ 2 + (spot.z - z) ^ 2)
		if d <= bestD then
			best, bestD = i, d
		end
	end
	return best
end

-- How many traps are down.
function Trap.count(s: State): number
	return #s.spots
end

return Trap
