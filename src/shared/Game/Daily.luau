--!strict
-- The daily reward: come back each day to extend a streak. Days are whole UTC days, so every server agrees. A missed day
-- resets the streak to 1; the seventh day also gives an egg and the cycle starts again. Pure.
local Daily = {}

Daily.DAY = 86400
Daily.CYCLE = 7

export type Claim = { streak: number, day: number }

-- The UTC day number for a unix time.
function Daily.dayOf(unix: number): number
	return math.floor(unix / Daily.DAY)
end

-- What happens if a player who last claimed on `lastDay` (nil if never) with `streak` logs in on `today`:
-- nil if they already claimed today, otherwise their new streak.
function Daily.next(lastDay: number?, streak: number, today: number): number?
	if lastDay == today then
		return nil
	end
	if lastDay ~= nil and lastDay == today - 1 then
		return streak + 1
	end
	return 1
end

-- The reward for day `streak` of the run: coins (at least a minute of your income, otherwise a base amount that grows with
-- the streak) and, on the last day of the 7-day cycle, an egg.
function Daily.reward(streak: number, incomePerSecond: number): (number, string?)
	local dayInCycle = (streak - 1) % Daily.CYCLE + 1
	local coins = math.max(500 * dayInCycle, math.floor(incomePerSecond * 60 * dayInCycle))
	return coins, if dayInCycle == Daily.CYCLE then "Disco" else nil
end

return Daily
