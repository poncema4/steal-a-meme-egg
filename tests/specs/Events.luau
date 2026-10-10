--!strict
local Events = require("../../src/shared/Game/Events")

local PERIOD, CLAIM = 1800, 300

return function(t)
	local state = Events.new()
	local luck, income = Events.multipliers(state, 0)
	t.check("no event means no bonus", luck == 1 and income == 1)
	t.check("an unknown event is refused", not Events.start(state, "Nope", 0))
	t.check("a known event starts", Events.start(state, "LuckyHour", 100))
	luck, income = Events.multipliers(state, 150)
	t.check("Lucky Hour doubles luck only", luck == 2 and income == 1)
	luck = Events.multipliers(state, 100 + 300)
	t.equal("it ends on time", luck, 1)

	Events.start(state, "LuckyHour", 0)
	Events.start(state, "CoinRain", 0)
	luck, income = Events.multipliers(state, 10)
	t.check("two events stack", luck == 2 and income == 2)
	t.equal("both are listed", #Events.active(state, 10), 2)
	Events.clear(state)
	t.equal("clear stops everything", #Events.active(state, 10), 0)

	Events.start(state, "MegaLuck", 0, 30)
	t.equal("a custom length is used", #Events.active(state, 29), 1)
	t.equal("and ends", #Events.active(state, 31), 0)
	Events.start(state, "MegaLuck", 0, 30)
	Events.start(state, "MegaLuck", 0, 10)
	t.equal("a shorter restart never shortens a running event", #Events.active(state, 20), 1)

	-- the schedule: Lucky Hour at :00, Egg Rain at :10, Coin Rain at :20 of each half hour
	local id, ends = Events.scheduledAt(1000 * PERIOD + 10, PERIOD, CLAIM)
	t.check("0:10 into the period is Lucky Hour", id == "LuckyHour" and ends == 1000 * PERIOD + CLAIM)
	t.equal("a quiet moment has no event", (Events.scheduledAt(1000 * PERIOD + 400, PERIOD, CLAIM)), nil)
	t.equal("Egg Rain at 10 minutes", (Events.scheduledAt(1000 * PERIOD + 610, PERIOD, CLAIM)), "EggRain")
	t.equal("Coin Rain at 20 minutes", (Events.scheduledAt(1000 * PERIOD + 1201, PERIOD, CLAIM)), "CoinRain")
	t.equal("nothing at 25 minutes", (Events.scheduledAt(1000 * PERIOD + 1500, PERIOD, CLAIM)), nil)
	local nextId, wait = Events.nextAfter(1000 * PERIOD + 400, PERIOD)
	t.check("the next event after a quiet moment", nextId == "EggRain" and wait == 200)
	nextId, wait = Events.nextAfter(1000 * PERIOD + 1500, PERIOD)
	t.check("after the last it wraps to the next period", nextId == "LuckyHour" and wait == 300)
end
