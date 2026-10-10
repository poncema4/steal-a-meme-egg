--!strict
-- What is in a base, flattened to a short string the server publishes as one attribute and the Eggs and Pets panels read.
-- Format: rows joined by ";", each row "slot,kind,id,extra": kind is "e" (egg: id = tier, extra = whole seconds left) or "c"
-- (character: id = character, extra = mutation). Decoding is defensive: anything malformed is skipped.
local Base = require("./Base")
local Eggs = require("./Eggs")

local BaseView = {}

export type Row = { slot: number, kind: string, id: string, mutation: string?, secondsLeft: number? }

function BaseView.encode(base: Base.Base): string
	local rows = {}
	for slot = 1, base.size do
		local item = base.slots[slot]
		if item and item.kind == "egg" and item.tier then
			table.insert(rows, `{slot},e,{item.tier},{math.max(0, math.ceil(item.hatchLeft or 0))}`)
		elseif item and item.kind == "char" and item.id then
			table.insert(rows, `{slot},c,{item.id},{item.mutation or "Normal"}`)
		end
	end
	return table.concat(rows, ";")
end

function BaseView.decode(text: string): { Row }
	local rows: { Row } = {}
	for chunk in string.gmatch(text, "[^;]+") do
		local slot, kind, id, extra = string.match(chunk, "^(%d+),([ec]),(%w+),(%w+)$")
		local n = tonumber(slot)
		if n and kind and id and extra and n >= 1 and n <= 12 and #rows < 12 then
			if kind == "e" and Eggs.tier(id) then
				table.insert(rows, { slot = n, kind = "egg", id = id, secondsLeft = tonumber(extra) or 0 })
			elseif kind == "c" and Eggs.character(id) and Eggs.Mutations[extra] then
				table.insert(rows, { slot = n, kind = "char", id = id, mutation = extra })
			end
		end
	end
	return rows
end

return BaseView
