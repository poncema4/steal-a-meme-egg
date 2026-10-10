--!strict
-- Live events: a fixed half-hourly schedule every server agrees on (it only needs the clock), plus events an admin
-- starts on demand. Active events change two multipliers, luck and income, and may add a one-off action (egg rain).
local Events = {}

export type Def = { id: string, name: string, luck: number, income: number, seconds: number, eggRain: boolean }
export type State = { ends: { [string]: number } }

local function def(id: string, name: string, luck: number, income: number, seconds: number, eggRain: boolean): Def
	return { id = id, name = name, luck = luck, income = income, seconds = seconds, eggRain = eggRain }
end

Events.Defs = {
	LuckyHour = def("LuckyHour", "Lucky Hour", 2, 1, 300, false),
	CoinRain = def("CoinRain", "Coin Rain", 1, 2, 300, false),
	EggRain = def("EggRain", "Egg Rain", 1, 1, 120, true),
	MegaLuck = def("MegaLuck", "Mega Luck", 5, 1, 180, false),
	Frenzy = def("Frenzy", "Meme Frenzy", 3, 3, 120, false),
} :: { [string]: Def }

-- the schedule inside one period: which event starts at which offset (seconds)
Events.Schedule = {
	{ offset = 0, id = "LuckyHour" },
	{ offset = 600, id = "EggRain" },
	{ offset = 1200, id = "CoinRain" },
} :: { { offset: number, id: string } }

function Events.new(): State
	return { ends = {} }
end

-- Starts (or extends to) an event. `seconds` defaults to the event's own length. Returns false for an unknown id.
function Events.start(state: State, id: string, now: number, seconds: number?): boolean
	local d = Events.Defs[id]
	if not d then
		return false
	end
	state.ends[id] = math.max(state.ends[id] or 0, now + (seconds or d.seconds))
	return true
end

function Events.stop(state: State, id: string)
	state.ends[id] = nil
end

function Events.clear(state: State)
	table.clear(state.ends)
end

-- Ids of events running at `now`, soonest-ending first.
function Events.active(state: State, now: number): { string }
	local list = {}
	for id, ends in state.ends do
		if ends > now then
			table.insert(list, id)
		end
	end
	table.sort(list, function(a, b)
		return state.ends[a] < state.ends[b]
	end)
	return list
end

-- Combined multipliers: luck and income multiply together across everything running.
function Events.multipliers(state: State, now: number): (number, number)
	local luck, income = 1, 1
	for _, id in Events.active(state, now) do
		local d = Events.Defs[id]
		luck *= d.luck
		income *= d.income
	end
	return luck, income
end

-- The scheduled event running at this unix time (and when it ends), or nil. `claim` is how long each one runs.
function Events.scheduledAt(unix: number, period: number, claim: number): (string?, number)
	local into = unix % period
	local start = unix - into
	for i = #Events.Schedule, 1, -1 do
		local entry = Events.Schedule[i]
		if into >= entry.offset then
			if into < entry.offset + claim then
				return entry.id, start + entry.offset + claim
			end
			break
		end
	end
	return nil, 0
end

-- The next scheduled event after this unix time: its id and how many seconds until it starts.
function Events.nextAfter(unix: number, period: number): (string, number)
	local into = unix % period
	for _, entry in Events.Schedule do
		if entry.offset > into then
			return entry.id, entry.offset - into
		end
	end
	local first = Events.Schedule[1]
	return first.id, period - into + first.offset
end

return Events
