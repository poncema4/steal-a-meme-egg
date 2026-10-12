--!strict
-- Day and night, the game's one event (Marco). A day lasts 5 minutes; then night falls for 15 seconds and a 5 second dawn
-- follows: for those 20 seconds a wall closes the Wilds (with a countdown), everyone out there is sent home without their egg,
-- and eggs in the pens hatch twice as fast. Then the wall drops and a new day starts; no day counter, it just repeats. It is
-- worked out from the clock alone, so every server agrees. Pure: the server and client both use it.
local DayNight = {}

DayNight.DAY = 300
DayNight.NIGHT = 15
DayNight.DAWN = 5
DayNight.CYCLE = DayNight.DAY + DayNight.NIGHT + DayNight.DAWN
DayNight.NIGHT_HATCH = 2 -- eggs in the pens hatch this much faster while it is night (and dawn)

export type Phase = "Day" | "Night" | "Dawn"
export type State = {
	phase: Phase,
	left: number, -- seconds until this phase ends
	wallLeft: number, -- seconds until the wall drops (0 in the day)
	nightIn: number, -- seconds until the next night falls (0 while it is night or dawn)
}

function DayNight.at(now: number): State
	local t = now % DayNight.CYCLE
	if t < DayNight.DAY then
		return { phase = "Day", left = DayNight.DAY - t, wallLeft = 0, nightIn = DayNight.DAY - t }
	end
	local into = t - DayNight.DAY
	local wallLeft = DayNight.NIGHT + DayNight.DAWN - into
	if into < DayNight.NIGHT then
		return { phase = "Night", left = DayNight.NIGHT - into, wallLeft = wallLeft, nightIn = 0 }
	end
	return { phase = "Dawn", left = wallLeft, wallLeft = wallLeft, nightIn = 0 }
end

-- Is the Wilds closed right now (night or dawn)?
function DayNight.closed(now: number): boolean
	return DayNight.at(now).phase ~= "Day"
end

-- How fast eggs in the pens hatch right now.
function DayNight.hatchBoost(now: number): number
	return if DayNight.closed(now) then DayNight.NIGHT_HATCH else 1
end

return DayNight
