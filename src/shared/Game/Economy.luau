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

local SUFFIXES = { "", "K", "M", "B", "T", "Qa", "Qi", "Sx", "Sp", "Oc", "No", "Dc" }

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

-- The whole number with thousands separators (1,600), for stats that must visibly tick up one by one.
function Economy.full(n: number): string
	local text = tostring(math.floor(n))
	local out = string.gsub(string.reverse(text), "(%d%d%d)", "%1,")
	out = string.reverse(out)
	return (string.gsub(out, "^,", ""))
end

-- The Speed number: every digit with commas while it is small (so it visibly ticks up), then B, T, Qa... once it is huge.
function Economy.speed(n: number): string
	if n < 1e9 then
		return Economy.full(n)
	end
	return Economy.format(n)
end

-- A countdown the way a player reads it: 45 -> "45s", 185 -> "3m 05s", 3725 -> "1h 02m 05s".
function Economy.duration(seconds: number): string
	local s = math.max(0, math.ceil(seconds))
	if s < 60 then
		return `{s}s`
	elseif s < 3600 then
		return string.format("%dm %02ds", s // 60, s % 60)
	end
	return string.format("%dh %02dm %02ds", s // 3600, (s % 3600) // 60, s % 60)
end

return Economy
