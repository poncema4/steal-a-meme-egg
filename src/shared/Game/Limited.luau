--!strict
-- Limited eggs: every PERIOD seconds a different limited egg goes on sale with a shared STOCK, so there is always something
-- to rush for. The rotation depends only on the clock, so every server agrees on which egg and when it ends.
local Eggs = require("./Eggs")

local Limited = {}

Limited.PERIOD = 1800
Limited.STOCK = 100

export type Rotation = { index: number, tier: string, startsAt: number, endsAt: number, key: string }

-- The limited egg on sale at this unix time.
function Limited.current(unix: number): Rotation
	local index = math.floor(unix / Limited.PERIOD)
	local tier = Eggs.LimitedTiers[index % #Eggs.LimitedTiers + 1]
	return {
		index = index,
		tier = tier.id,
		startsAt = index * Limited.PERIOD,
		endsAt = (index + 1) * Limited.PERIOD,
		key = `limited{index}`,
	}
end

-- What a store counter does for one purchase: nil means sold out, otherwise the stock left after this one. `old` is the
-- stored value (nil when nobody has bought yet this rotation). Used inside MemoryStore UpdateAsync and by the local fallback.
function Limited.claim(old: number?): number?
	local left = if old == nil then Limited.STOCK else old
	if left <= 0 then
		return nil
	end
	return left - 1
end

-- Giving one back (a purchase that failed after the stock was taken), capped at the full stock.
function Limited.release(old: number?): number
	return math.min((if old == nil then Limited.STOCK else old) + 1, Limited.STOCK)
end

return Limited
