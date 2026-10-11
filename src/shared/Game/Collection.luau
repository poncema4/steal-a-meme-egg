--!strict
-- The Index: every character you have ever had in a base, and which mutations of it you have seen. Saved with the player and
-- published as two short attributes. Keys are "<id>" for a character and "<id>:<mutation>" for a mutation of it.
local Base = require("./Base")
local Eggs = require("./Eggs")
local Zones = require("./Zones")

local Collection = {}

export type Collection = { [string]: boolean }

function Collection.new(): Collection
	return {}
end

-- Notes everything currently in the base. Returns true if something new was discovered.
function Collection.record(c: Collection, base: Base.Base): boolean
	local fresh = false
	for slot = 1, base.size do
		local item = base.slots[slot]
		if item and item.kind == "char" and item.id and Eggs.character(item.id) then
			if not c[item.id] then
				c[item.id] = true
				fresh = true
			end
			local mutation = item.mutation or "Normal"
			if Eggs.Mutations[mutation] then
				local key = `{item.id}:{mutation}`
				if not c[key] then
					c[key] = true
					fresh = true
				end
			end
		end
	end
	return fresh
end

function Collection.has(c: Collection, id: string): boolean
	return c[id] == true
end

function Collection.hasMutation(c: Collection, id: string, mutation: string): boolean
	return c[`{id}:{mutation}`] == true
end

-- How many characters are discovered, out of how many exist.
function Collection.progress(c: Collection): (number, number)
	local found, total = 0, 0
	for id in Eggs.Characters do
		total += 1
		if c[id] then
			found += 1
		end
	end
	return found, total
end

-- The characters that belong to a world: the ones its eggs hatch (each egg tier belongs to one world, see Zones.forTier).
function Collection.worldCharacters(zoneId: string): { string }
	local list = {}
	for _, tier in Eggs.Tiers do
		local home = Zones.forTier(tier.id)
		if home and home.id == zoneId then
			for _, entry in tier.pool do
				table.insert(list, entry.id)
			end
		end
	end
	return list
end

-- How many of a world's characters are discovered, out of how many it has.
function Collection.worldProgress(c: Collection, zoneId: string): (number, number)
	local ids = Collection.worldCharacters(zoneId)
	local found = 0
	for _, id in ids do
		if c[id] then
			found += 1
		end
	end
	return found, #ids
end

-- Has every character of the world been discovered?
function Collection.worldComplete(c: Collection, zoneId: string): boolean
	local found, total = Collection.worldProgress(c, zoneId)
	return total > 0 and found == total
end

-- A sorted, comma-separated list (stable, so an unchanged Index never re-replicates).
function Collection.encode(c: Collection): string
	local keys = {}
	for key, has in c do
		if has then
			table.insert(keys, key)
		end
	end
	table.sort(keys)
	return table.concat(keys, ",")
end

-- Reads a list back, keeping only real characters and real mutations (a corrupt save or a hostile string cannot add anything).
function Collection.decode(text: string): Collection
	local c = Collection.new()
	for key in string.gmatch(text, "[^,]+") do
		local id, mutation = string.match(key, "^(%w+):(%w+)$")
		if id and mutation then
			if Eggs.character(id) and Eggs.Mutations[mutation] then
				c[key] = true
			end
		elseif Eggs.character(key) then
			c[key] = true
		end
	end
	return c
end

return Collection
