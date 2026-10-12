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

	-- day and night is the only event (Marco): nothing else is scheduled, and an empty schedule never breaks anything
	t.equal("no other event is on a schedule", (Events.scheduledAt(1000 * PERIOD + 10, PERIOD, CLAIM)), nil)
	local nextId = Events.nextAfter(1000 * PERIOD + 400, PERIOD)
	t.equal("and none is coming up", nextId, "")
end
