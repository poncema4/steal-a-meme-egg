--!nocheck
-- Egg timers read like a clock and tick one second per second, also with the Hatch Speed pass; in the Eggs panel a finished egg
-- shows a Hatch button and an unfinished one the Robux instant hatch, never both.
local BaseView = require("../../src/shared/Game/BaseView")
local Base = require("../../src/shared/Game/Base")
local Economy = require("../../src/shared/Game/Economy")
local Fake = require("../fake/Roblox")

return function(t)
	t.equal("under a minute shows seconds", Economy.duration(45), "45s")
	t.equal("over a minute shows minutes and seconds", Economy.duration(185), "3m 05s")
	t.equal("over an hour shows hours too", Economy.duration(3725), "1h 02m 05s")
	t.equal("a part second rounds up", Economy.duration(0.2), "1s")

	local base = Base.new(6)
	base.slots[1] = { kind = "egg", tier = "Soggy", hatchLeft = 20, eggMutation = "Normal" }
	t.equal("without the pass 20 work-seconds is 20 seconds", BaseView.decode(BaseView.encode(base))[1].secondsLeft, 20)
	t.equal(
		"with the 2x pass the same egg is 10 REAL seconds away (so the timer ticks 1 a second, not 2)",
		BaseView.decode(BaseView.encode(base, 2))[1].secondsLeft,
		10
	)

	-- the Eggs panel
	local world = Fake.world()
	assert(pcall(world.load, "src/server/main.server"))
	local session = world.load("src/server/Session")
	local ana = world.addPlayer("Ana", 71)
	world.advance(0.6)
	world.setLocal(ana)
	local panels = world.load("src/client/Panels")
	local api = panels.start(ana)
	local state = session.get(ana)
	state.base.slots[1] = { kind = "egg", tier = "Soggy", hatchLeft = 500, eggMutation = "Normal" }
	state.base.slots[2] = { kind = "egg", tier = "Soggy", hatchLeft = 0, eggMutation = "Normal" }
	session.changed(ana)
	world.advance(0.6)
	api.eggs()
	world.advance(1.2)
	local gui = ana.PlayerGui:FindFirstChild("Panels")
	local waiting = gui:FindFirstChild("EggRow_1", true)
	local ready = gui:FindFirstChild("EggRow_2", true)
	t.check(
		"a hatching egg says how long, in minutes",
		string.find(waiting.Timer.Text, "m ", 1, true) ~= nil,
		waiting.Timer.Text
	)
	t.check("it offers no Hatch button yet", not waiting.Hatch.Visible)
	t.check("a finished egg says it is ready", string.find(ready.Timer.Text, "Ready", 1, true) ~= nil, ready.Timer.Text)
	t.check("and shows Hatch, not the Robux instant hatch", ready.Hatch.Visible and not ready.Instant.Visible)
	ready.Hatch.Activated:Fire()
	world.advance(0.6)
	t.equal("pressing Hatch hatches it", state.base.slots[2].kind, "char")
	t.equal("and leaves the unfinished one alone", state.base.slots[1].kind, "egg")
end
