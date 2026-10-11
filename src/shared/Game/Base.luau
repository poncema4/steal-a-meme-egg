--!strict
-- One player's base: a row of slots holding eggs (hatching) or characters (earning). A pure state machine: time is
-- passed in, never read, so every rule is testable. The server mirrors this into parts; nothing here knows Roblox.
local Eggs = require("./Eggs")

local Base = {}

export type Spot = { x: number, z: number }

export type Item = {
	kind: "egg" | "char",
	tier: string?, -- egg: which tier
	hatchLeft: number?, -- egg: seconds until it hatches
	eggMutation: string?, -- egg: a Gold or Rainbow egg hatches into a pet with that mutation
	id: string?, -- char: which character
	mutation: string?, -- char: Normal / Gold / Rainbow
	at: Spot?, -- egg: where in the pen it was put (pen-local: x to the right, z toward the front); nil = the slot's default spot
}
export type Base = {
	size: number,
	slots: { [number]: Item },
}

-- Where an egg without a chosen spot sits: slot n in a grid of 4 columns by 3 rows (the same spots the pedestals used to mark).
function Base.defaultSpot(slot: number): Spot
	local column = (slot - 1) % 4
	local row = (slot - 1) // 4
	return { x = (column - 1.5) * 8.5, z = (row - 1) * 10 - 2 }
end

-- The part of the pen eggs may be put in: inside the fence, and clear of the pads and the spawn along the front edge.
Base.MIN_X, Base.MAX_X, Base.MIN_Z, Base.MAX_Z = -16, 16, -16, 10
Base.EGG_GAP = 5 -- eggs are put at least this far apart

function Base.clampSpot(x: number, z: number): Spot
	local cx = if x == x then x else 0
	local cz = if z == z then z else 0
	return { x = math.clamp(cx, Base.MIN_X, Base.MAX_X), z = math.clamp(cz, Base.MIN_Z, Base.MAX_Z) }
end

local function spotOf(base: Base, slot: number): Spot
	local item = base.slots[slot]
	return if item and item.at then item.at else Base.defaultSpot(slot)
end

-- The spot nearest (x, z) that is inside the pen and not on top of another egg: the egg goes where the player stands, nudged
-- sideways if somebody's egg is already there.
function Base.freeSpot(base: Base, x: number, z: number): Spot
	local start = Base.clampSpot(x, z)
	local function clear(spot: Spot): boolean
		for slot = 1, base.size do
			local item = base.slots[slot]
			if item and item.kind == "egg" then
				local other = spotOf(base, slot)
				if (other.x - spot.x) ^ 2 + (other.z - spot.z) ^ 2 < Base.EGG_GAP ^ 2 then
					return false
				end
			end
		end
		return true
	end
	if clear(start) then
		return start
	end
	for ring = 1, 6 do
		for step = 0, 11 do
			local a = step * math.pi / 6
			local spot = Base.clampSpot(start.x + math.cos(a) * ring * 3, start.z + math.sin(a) * ring * 3)
			if clear(spot) then
				return spot
			end
		end
	end
	return start
end

function Base.new(size: number): Base
	return { size = size, slots = {} }
end

function Base.firstFree(base: Base): number?
	for i = 1, base.size do
		if base.slots[i] == nil then
			return i
		end
	end
	return nil
end

function Base.count(base: Base): number
	local n = 0
	for i = 1, base.size do
		if base.slots[i] ~= nil then
			n += 1
		end
	end
	return n
end

-- Puts an egg in the first free slot, at `at` in the pen if the player chose a spot (a bought egg has none). Returns the slot, or nil if the base is full.
function Base.placeEgg(base: Base, tierId: string, mutation: string?, at: Spot?): number?
	local tier = Eggs.tier(tierId)
	local slot = Base.firstFree(base)
	if not tier or not slot then
		return nil
	end
	local eggMutation = if mutation and mutation ~= "Normal" and Eggs.Mutations[mutation] then mutation else nil
	base.slots[slot] = {
		kind = "egg",
		tier = tierId,
		hatchLeft = tier.hatchSeconds,
		eggMutation = eggMutation,
		at = if at then Base.freeSpot(base, at.x, at.z) else nil,
	}
	return slot
end

-- Puts a finished character (a steal, a reward, a saved game) in the first free slot.
function Base.placeCharacter(base: Base, id: string, mutation: string?): number?
	local slot = Base.firstFree(base)
	if not slot or not Eggs.character(id) then
		return nil
	end
	base.slots[slot] = { kind = "char", id = id, mutation = mutation or "Normal" }
	return slot
end

-- Counts hatch timers down. With `auto` (a paid instant hatch) each egg that reaches zero becomes a character at once, chosen
-- by `roll(tierId)` and `mutate()`; otherwise a finished egg waits, READY, until its owner presses Hatch (Base.hatchReady).
-- Returns the slots that hatched, so the server can play the pop.
function Base.tick(base: Base, dt: number, roll: (string) -> string, mutate: () -> string, auto: boolean?): { number }
	local hatched = {}
	for i = 1, base.size do
		local item = base.slots[i]
		if item and item.kind == "egg" and item.tier then
			local left = math.max((item.hatchLeft or 0) - dt, 0)
			item.hatchLeft = left
			if left <= 0 and auto ~= false then
				-- a mutated egg hatches into a pet with that mutation; otherwise the usual roll decides
				base.slots[i] = { kind = "char", id = roll(item.tier), mutation = item.eggMutation or mutate() }
				table.insert(hatched, i)
			end
		end
	end
	return hatched
end

-- Is the egg in this slot done and waiting for its owner to hatch it?
function Base.isReady(base: Base, slot: number): boolean
	local item = base.slots[slot]
	return item ~= nil and item.kind == "egg" and item.tier ~= nil and (item.hatchLeft or 0) <= 0
end

-- The owner pressed Hatch on a finished egg: it becomes a character. Returns true if it hatched.
function Base.hatchReady(base: Base, slot: number, roll: (string) -> string, mutate: () -> string): boolean
	if not Base.isReady(base, slot) then
		return false
	end
	local item = base.slots[slot] :: Item
	base.slots[slot] = { kind = "char", id = roll(item.tier :: string), mutation = item.eggMutation or mutate() }
	return true
end

-- Coins per second from every character, times the global multiplier (events, passes).
function Base.income(base: Base, multiplier: number): number
	local total = 0
	for i = 1, base.size do
		local item = base.slots[i]
		if item and item.kind == "char" and item.id then
			local c = Eggs.character(item.id)
			if c then
				total += c.income * (Eggs.Mutations[item.mutation or "Normal"] or 1)
			end
		end
	end
	return total * multiplier
end

-- Adds a slot (up to max). Returns the new size.
function Base.grow(base: Base, max: number): number
	base.size = math.min(max, base.size + 1)
	return base.size
end

return Base
