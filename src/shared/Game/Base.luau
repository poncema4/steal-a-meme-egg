--!strict
-- One player's base: a row of slots holding eggs (hatching) or characters (earning). A pure state machine: time is
-- passed in, never read, so every rule is testable. The server mirrors this into parts; nothing here knows Roblox.
local Eggs = require("./Eggs")

local Base = {}

export type Item = {
	kind: "egg" | "char",
	tier: string?, -- egg: which tier
	hatchLeft: number?, -- egg: seconds until it hatches
	id: string?, -- char: which character
	mutation: string?, -- char: Normal / Gold / Rainbow
}
export type Base = {
	size: number,
	slots: { [number]: Item },
}

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

-- Puts a bought egg in the first free slot. Returns the slot, or nil if the base is full.
function Base.placeEgg(base: Base, tierId: string): number?
	local tier = Eggs.tier(tierId)
	local slot = Base.firstFree(base)
	if not tier or not slot then
		return nil
	end
	base.slots[slot] = { kind = "egg", tier = tierId, hatchLeft = tier.hatchSeconds }
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

-- Counts hatch timers down. Each egg that reaches zero becomes a character, chosen by `roll(tierId)` and
-- `mutate()`. Returns the slots that hatched, so the server can play the pop.
function Base.tick(base: Base, dt: number, roll: (string) -> string, mutate: () -> string): { number }
	local hatched = {}
	for i = 1, base.size do
		local item = base.slots[i]
		if item and item.kind == "egg" and item.tier then
			local left = (item.hatchLeft or 0) - dt
			if left <= 0 then
				base.slots[i] = { kind = "char", id = roll(item.tier), mutation = mutate() }
				table.insert(hatched, i)
			else
				item.hatchLeft = left
			end
		end
	end
	return hatched
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
