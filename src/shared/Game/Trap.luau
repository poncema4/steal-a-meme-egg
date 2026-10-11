--!strict
-- Traps, like Steal an Egg: a player may have at most 3 on the ground at once, and they stay there until something steps on
-- them. Another player who steps on one is held still for 10 seconds; then the trap comes back to its owner (a slot frees up).
-- A chasing guardian that runs over one is stunned and the trap is used up. Pure rules (time is passed in), the server builds the
-- parts.
local Trap = {}

Trap.MAX = 3 -- placed at once, per player
Trap.RADIUS = 5 -- studs: how close a guardian must come to spring it
Trap.LIFETIME = math.huge -- an unused trap stays until something steps on it
Trap.HOLD = 10 -- seconds a sprung trap holds another player before it goes back to its owner
Trap.COOLDOWN = 2 -- seconds between placing two traps
Trap.STUN = 3.5 -- seconds a sprung trap holds a guardian

export type Spot = { x: number, z: number, expires: number, holdingUntil: number? }
export type State = { spots: { Spot }, lastPlaced: number }

function Trap.new(): State
	return { spots = {}, lastPlaced = -math.huge }
end

-- Why a trap cannot be placed right now, or nil if it can.
function Trap.why(s: State, now: number, max: number?, cooldown: number?): string?
	Trap.prune(s, now)
	local limit = max or Trap.MAX
	if #s.spots >= limit then
		return `You can only have {limit} traps out at once`
	end
	if now - s.lastPlaced < Trap.COOLDOWN * (cooldown or 1) then
		return "Your next trap is not ready yet"
	end
	return nil
end

-- Places a trap. Returns (true, nil) or (false, the reason).
function Trap.place(s: State, x: number, z: number, now: number, max: number?, cooldown: number?): (boolean, string?)
	if x ~= x or z ~= z or math.abs(x) == math.huge or math.abs(z) == math.huge then
		return false, "bad position"
	end
	local reason = Trap.why(s, now, max, cooldown)
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
		if spot.holdingUntil then
			continue -- already closed on someone
		end
		local d = math.sqrt((spot.x - x) ^ 2 + (spot.z - z) ^ 2)
		if d <= bestD then
			best, bestD = i, d
		end
	end
	return best
end

-- A player stepped on trap `index`: it closes on them until now + HOLD (it still counts as one of the owner's traps).
function Trap.spring(s: State, index: number, now: number): number
	local spot = s.spots[index]
	spot.holdingUntil = now + Trap.HOLD
	return spot.holdingUntil :: number
end

-- Traps whose hold is over open and go back to their owner: they are removed and returned.
function Trap.release(s: State, now: number): { Spot }
	local done = {}
	for i = #s.spots, 1, -1 do
		local spot = s.spots[i]
		if spot.holdingUntil and spot.holdingUntil <= now then
			table.insert(done, table.remove(s.spots, i) :: Spot)
		end
	end
	return done
end

-- How many traps are down.
function Trap.count(s: State): number
	return #s.spots
end

return Trap
