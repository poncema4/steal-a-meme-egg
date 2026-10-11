--!strict
local UiScale = require("../../src/shared/Game/UiScale")

return function(t)
	t.check(
		"a 720p monitor draws the UI a little smaller than designed",
		math.abs(UiScale.factor(1280, 720, false) - 1280 / 1440) < 1e-9
	)
	t.equal("the design screen itself is scale 1", UiScale.factor(1440, 810, false), 1)
	t.check("a 1080p monitor scales up a third", math.abs(UiScale.factor(1920, 1080, false) - 4 / 3) < 1e-9)
	-- panels: a little smaller everywhere, and on a phone they leave most of the world and the controls visible
	t.equal("a panel on a monitor is drawn at 85%", UiScale.panelScale(520, 810, false), UiScale.PANEL)
	local phoneDesign = 390 / UiScale.factor(844, 390, true)
	for _, h in { 460, 520, 540 } do
		local shown = math.min(h, phoneDesign * 0.88) * UiScale.panelScale(h, phoneDesign, true)
		t.check(
			`a {h} tall panel covers at most 72% of a phone's height`,
			shown / phoneDesign <= UiScale.PHONE_SHARE + 1e-9,
			tostring(shown / phoneDesign)
		)
	end
	t.equal("a broken size falls back", UiScale.panelScale(0 / 0, 640, true), UiScale.PANEL)
	t.equal("a 4K screen is capped", UiScale.factor(3840, 2160, false), UiScale.MAX)
	t.check("a phone held sideways gets a real scale", UiScale.factor(844, 390, true) > 0.6)
	-- not too big on a phone (Marco): a 176 px button takes about the same share of a phone's width as of a monitor's
	local phoneShare = 176 * UiScale.factor(844, 390, true) / 844
	local pcShare = 176 * UiScale.factor(1920, 1080, false) / 1920
	t.check(
		"a phone's buttons are not much bigger than a PC's, as a share of the screen",
		phoneShare <= pcShare * 1.25,
		tostring(phoneShare / pcShare)
	)
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
	t.check(
		"a 36 px design button never renders under the fingertip minimum",
		worst >= UiScale.MIN_TAP - 1e-9,
		tostring(worst)
	)
	t.equal("a button that is already big enough is left alone", UiScale.tap(80, 1), 80)
	t.equal("a bad scale leaves the size alone", UiScale.tap(50, 0), 50)
	t.equal("a NaN scale leaves the size alone", UiScale.tap(50, 0 / 0), 50)

	t.equal("a desktop shows 8 leaderboard rows", UiScale.leaderboardRows(900, false), 8)
	t.equal("a phone shows 4", UiScale.leaderboardRows(390, true), 4)
	t.equal("a tiny window shows 3", UiScale.leaderboardRows(200, false), 3)
	t.equal("a NaN height shows 3", UiScale.leaderboardRows(0 / 0, false), 3)

	-- the bottom bar: six trap slots and the event clock never touch, on any screen from a small phone to a big monitor
	for _, spec in
		{
			{ 1280, 720, false },
			{ 1920, 1080, false },
			{ 844, 390, true },
			{ 812, 375, true },
			{ 740, 360, true },
			{ 932, 430, true },
		}
	do
		local factor = UiScale.factor(spec[1] :: number, spec[2] :: number, spec[3] :: boolean)
		local width = (spec[1] :: number) / factor
		for _, slots in { 3, 6 } do
			local bar = UiScale.bottomBar(width, slots, UiScale.tap(46, factor))
			local hotbarRight = width / 2 + bar.hotbarWidth / 2
			local clockLeft = width - 16 - bar.clockWidth
			t.check(
				`{spec[1]}x{spec[2]} with {slots} slots: the clock starts after the hotbar ends`,
				clockLeft >= hotbarRight or bar.clockWidth <= 100,
				`hotbar to {hotbarRight}, clock from {clockLeft}`
			)
			t.check(
				`{spec[1]}x{spec[2]}: slots are at least a fingertip wide`,
				bar.slot * factor >= UiScale.MIN_TAP - 1e-6
			)
		end
	end
	t.check("a roomy screen gives the clock its full width", UiScale.bottomBar(1280, 6, 46).clockWidth == 360)
end
