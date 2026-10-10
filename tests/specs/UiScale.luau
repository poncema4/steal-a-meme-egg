--!strict
local UiScale = require("../../src/shared/Game/UiScale")

return function(t)
	t.equal("a 720p monitor is the design size", UiScale.factor(1280, 720, false), 1)
	t.equal("a 1080p monitor scales up 1.5x", UiScale.factor(1920, 1080, false), 1.5)
	t.equal("a 4K screen is capped", UiScale.factor(3840, 2160, false), UiScale.MAX)
	t.check("a phone held sideways gets a real scale", UiScale.factor(844, 390, true) > 0.8)
	t.check(
		"touch screens draw bigger than desktops at the same size",
		UiScale.factor(844, 390, true) > UiScale.factor(844, 390, false)
	)
	t.equal("a tiny window is floored", UiScale.factor(200, 100, false), UiScale.MIN)
	t.equal("zero size falls back to 1", UiScale.factor(0, 0, false), 1)
	t.equal("NaN falls back to 1", UiScale.factor(0 / 0, 720, true), 1)
	t.equal("infinity falls back to 1", UiScale.factor(math.huge, 720, false), 1)
	t.equal("a negative size falls back to 1", UiScale.factor(-5, 700, false), 1)
	local narrow = UiScale.factor(400, 1000, false)
	t.check("a tall narrow screen is limited by its width", narrow < 1 and narrow >= UiScale.MIN)

	-- no button is smaller than a fingertip, on any real screen size
	local worst = math.huge
	for _, size in { { 844, 390 }, { 932, 430 }, { 667, 375 }, { 1280, 720 }, { 1920, 1080 }, { 2560, 1440 } } do
		for _, touch in { true, false } do
			local f = UiScale.factor(size[1], size[2], touch)
			worst = math.min(worst, UiScale.tap(36, f) * f)
		end
	end
	t.check("a 36 px design button never renders under 44 px", worst >= UiScale.MIN_TAP - 1e-9, tostring(worst))
	t.equal("a button that is already big enough is left alone", UiScale.tap(80, 1), 80)
	t.equal("a bad scale leaves the size alone", UiScale.tap(50, 0), 50)
	t.equal("a NaN scale leaves the size alone", UiScale.tap(50, 0 / 0), 50)

	t.equal("a desktop shows 8 leaderboard rows", UiScale.leaderboardRows(900, false), 8)
	t.equal("a phone shows 4", UiScale.leaderboardRows(390, true), 4)
	t.equal("a tiny window shows 3", UiScale.leaderboardRows(200, false), 3)
	t.equal("a NaN height shows 3", UiScale.leaderboardRows(0 / 0, false), 3)
end
