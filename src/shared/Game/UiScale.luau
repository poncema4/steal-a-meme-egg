--!strict
-- How big the UI is on each screen. Everything is drawn for a "design screen" and scaled to fit, so the same layout works
-- on a monitor, a phone held sideways and a TV. Touch screens get a smaller design screen (so everything is bigger), and
-- no button may end up smaller than a fingertip. Pure maths, so it is tested exactly.
local UiScale = {}

UiScale.DESKTOP = { x = 1280, y = 720 }
UiScale.TOUCH = { x = 820, y = 460 }
UiScale.MIN = 0.55
UiScale.MAX = 1.6
UiScale.MIN_TAP = 44 -- pixels: the smallest a touch target may render

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

-- The design size a button needs so that it renders at least MIN_TAP pixels at this scale.
function UiScale.tap(designSize: number, factor: number): number
	if not finite(factor) or factor <= 0 then
		return designSize
	end
	return math.max(designSize, math.ceil(UiScale.MIN_TAP / factor))
end

-- How many leaderboard rows fit: fewer on a short (phone) screen.
function UiScale.leaderboardRows(viewportY: number, touch: boolean): number
	if not finite(viewportY) or viewportY < 300 then
		return 3
	end
	return if touch or viewportY < 500 then 4 else 8
end

return UiScale
