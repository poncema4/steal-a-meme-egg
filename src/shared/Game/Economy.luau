--!strict
-- Money rules: slot prices, offline earnings, and the short number format shown on the HUD.
local Economy = {}

-- Price of the next slot when the base has `size` slots (the first `startSlots` are free).
function Economy.slotCost(size: number, startSlots: number, base: number): number
	return base * 4 ^ (size - startSlots)
end

-- Coins earned while away: income for the time away, capped so a week offline is not a week of income.
function Economy.offline(incomePerSecond: number, secondsAway: number, capSeconds: number): number
	return math.floor(incomePerSecond * math.clamp(secondsAway, 0, capSeconds))
end

local SUFFIXES = { "", "K", "M", "B", "T", "Qa", "Qi" }

-- 1234 -> "1.23K", 25000000 -> "25M", 999 -> "999"
function Economy.format(n: number): string
	if n < 1000 then
		return tostring(math.floor(n))
	end
	local i = 1
	while n >= 1000 and i < #SUFFIXES do
		n /= 1000
		i += 1
	end
	local text = string.format("%.2f", n)
	text = string.gsub(text, "%.?0+$", "")
	return text .. SUFFIXES[i]
end

return Economy
