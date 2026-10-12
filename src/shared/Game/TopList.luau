--!strict
-- The global leaderboards (top 10 of everyone who has played, across all servers): Speed, Money and Rebirths. Roblox's ordered
-- data stores only sort whole numbers below 2^63, but speed and coins reach 1e30+, so a value is stored as its log10 scaled by a
-- billion (exact enough to rank, decoded back for display). The board travels to clients as "name=value;name=value".
local TopList = {}

TopList.BOARDS = { "Speed", "Money", "Rebirths" }
TopList.SIZE = 10
local SCALE = 1e9

function TopList.encode(value: number): number
	if value ~= value or value <= 0 then
		return 0
	end
	return math.floor(math.log10(value + 1) * SCALE)
end

function TopList.decode(stored: number): number
	return math.max(0, 10 ^ (stored / SCALE) - 1)
end

export type Entry = { name: string, value: number }

function TopList.pack(entries: { Entry }): string
	local parts = {}
	for _, e in entries do
		table.insert(parts, `{(string.gsub(e.name, "[=;]", ""))}={e.value}`)
	end
	return table.concat(parts, ";")
end

function TopList.unpack(text: string): { Entry }
	local out = {}
	for name, value in string.gmatch(text, "([^=;]+)=([^;]+)") do
		table.insert(out, { name = name, value = tonumber(value) or 0 })
	end
	return out
end

return TopList
