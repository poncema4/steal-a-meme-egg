--!strict
-- How big the UI is on each screen. Everything is drawn for a "design screen" and scaled to fit, so the same layout works
-- on a monitor, a phone held sideways and a TV. Touch screens get a slightly smaller design screen than a monitor (a touch
-- bigger, for fingers, but the same share of the screen as on a PC: Marco found 820x460 made everything far too big on a
-- phone), and no button may end up smaller than a fingertip. Pure maths, so it is tested exactly.
local UiScale = {}

UiScale.DESKTOP = { x = 1440, y = 810 } -- Marco: the UI was too big; a bigger design screen draws everything ~11% smaller
UiScale.TOUCH = { x = 1200, y = 640 }
UiScale.MIN = 0.55
UiScale.MAX = 1.6
UiScale.MIN_TAP = 40 -- pixels: the smallest a touch target may render (still a comfortable thumb)

local function finite(n: number): boolean
	return n == n and n > -math.huge and n < math.huge
end

-- The scale that fits the design screen inside the real one. Strange sizes (zero, NaN) fall back to 1.
function UiScale.factor(viewportX: number, viewportY: number, touch: boolean): number
	if not finite(viewportX) or not finite(viewportY) or viewportX <= 0 or viewportY <= 0 then
		return 1
	end
	local design = if touch then UiScale.TOUCH else UiScale.DESKTOP
	return math.clamp(math.min(viewportX / design.x, viewportY / design.y), UiScale.MIN, UiScale.MAX)
end

-- How much a panel (Shop, Index, Eggs...) is scaled down on top of the screen scale: a bit smaller than drawn on a monitor, and on
-- a phone small enough to cover at most PHONE_SHARE of the screen's height, so players still see the world and their thumbs
-- reach the joystick and jump button. `panelHeight` is the panel's design height, `designHeight` the design screen's.
UiScale.PANEL = 0.85
UiScale.PHONE_SHARE = 0.72
function UiScale.panelScale(panelHeight: number, designHeight: number, touch: boolean): number
	if not finite(panelHeight) or not finite(designHeight) or panelHeight <= 0 or designHeight <= 0 then
		return UiScale.PANEL
	end
	local shown = math.min(panelHeight, designHeight * 0.88) -- a panel is never taller than 88% of the screen
	if touch then
		return math.min(UiScale.PANEL, UiScale.PHONE_SHARE * designHeight / shown)
	end
	return UiScale.PANEL
end

-- The design size a button needs so that it renders at least MIN_TAP pixels at this scale.
function UiScale.tap(designSize: number, factor: number): number
	if not finite(factor) or factor <= 0 then
		return designSize
	end
	return math.max(designSize, math.ceil(UiScale.MIN_TAP / factor))
end

-- The bottom bar: the trap hotbar sits in the middle and the event clock in the right corner. Given the design screen's width, how many
-- trap slots there can be and how wide a slot is (never below a fingertip), this gives the slot size and gap and the widest the clock
-- may be so the two never touch. Pure, so the "never overlap" rule is tested for every width.
export type BottomBar = { slot: number, gap: number, hotbarWidth: number, clockWidth: number }

function UiScale.bottomBar(designWidth: number, slots: number, tap: number): BottomBar
	local n = math.max(slots, 1)
	local slot = math.max(tap, 44)
	local gap = 4
	local hotbarWidth = n * slot + (n - 1) * gap
	local margin = 16 -- the clock's distance from the right edge
	local room = designWidth - margin - (designWidth / 2 + hotbarWidth / 2 + 12) -- from the hotbar's right edge (plus a gap) to the clock's right edge
	return { slot = slot, gap = gap, hotbarWidth = hotbarWidth, clockWidth = math.clamp(room, 100, 360) }
end

-- How many leaderboard rows fit: fewer on a short (phone) screen.
function UiScale.leaderboardRows(viewportY: number, touch: boolean): number
	if not finite(viewportY) or viewportY < 300 then
		return 3
	end
	return if touch or viewportY < 500 then 4 else 8
end

return UiScale
