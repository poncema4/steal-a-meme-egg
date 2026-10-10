--!strict
local Economy = require("../../src/shared/Game/Economy")
local Eggs = require("../../src/shared/Game/Eggs")
local Limited = require("../../src/shared/Game/Limited")

return function(t)
	-- the rotation
	local start = 1000 * Limited.PERIOD
	local a = Limited.current(start + 5)
	local b = Limited.current(start + Limited.PERIOD - 1)
	t.equal("the same half hour is the same egg", a.tier, b.tier)
	t.equal("and the same stock counter", a.key, b.key)
	t.equal("the rotation ends at the next boundary", a.endsAt, start + Limited.PERIOD)
	t.equal("and starts at this one", a.startsAt, start)
	local c = Limited.current(start + Limited.PERIOD)
	t.check("the next half hour has a new counter", c.key ~= a.key)
	t.check("and a different egg", c.tier ~= a.tier)
	local seen: { [string]: boolean } = {}
	for k = 0, #Eggs.LimitedTiers - 1 do
		seen[Limited.current(start + k * Limited.PERIOD).tier] = true
	end
	local count = 0
	for _ in seen do
		count += 1
	end
	t.equal("the rotation shows every limited egg before repeating", count, #Eggs.LimitedTiers)
	t.equal("then it repeats", Limited.current(start + #Eggs.LimitedTiers * Limited.PERIOD).tier, a.tier)
	t.check("every rotation egg exists", Eggs.tier(a.tier) ~= nil and Eggs.tier(c.tier) ~= nil)

	-- the stock counter
	t.equal("the first claim of a rotation leaves STOCK - 1", Limited.claim(nil), Limited.STOCK - 1)
	t.equal("the last one leaves zero", Limited.claim(1), 0)
	t.equal("a sold-out egg cannot be claimed", Limited.claim(0), nil)
	local left: number? = nil
	local sold = 0
	for _ = 1, Limited.STOCK + 20 do
		left = Limited.claim(left)
		if left == nil then
			break
		end
		sold += 1
		left = left
	end
	t.equal("exactly STOCK can be sold", sold, Limited.STOCK)
	t.equal("giving one back adds one", Limited.release(5), 6)
	t.equal("and never goes past the full stock", Limited.release(Limited.STOCK), Limited.STOCK)

	-- balance: limited eggs beat everything standard, and still pay back in a sane time
	local best = 0
	for _, tier in Eggs.Tiers do
		for _, entry in tier.pool do
			best = math.max(best, Eggs.Characters[entry.id].income)
		end
	end
	for _, tier in Eggs.LimitedTiers do
		local worst, avg, total = math.huge, 0, 0
		for _, entry in tier.pool do
			local income = Eggs.Characters[entry.id].income
			worst = math.min(worst, income)
			avg += income * entry.weight
			total += entry.weight
		end
		avg /= total
		t.check(`{tier.name} always beats the best standard character`, worst > best, `{worst} vs {best}`)
		local payback = tier.price / avg
		t.check(
			`{tier.name} pays itself back in 20 to 120 seconds`,
			payback >= 20 and payback <= 120,
			tostring(payback)
		)
		t.check(`{tier.name} is not a belt or Wilds egg`, Eggs.ConveyorWeights[tier.id] == nil)
	end

	-- skipping a hatch
	t.equal("a finished hatch costs nothing", Economy.skipCost(1000, 0, 15), 0)
	t.equal("a full wait costs 60% of the price", Economy.skipCost(1000, 15, 15), 600)
	t.equal("half the wait costs half of that", Economy.skipCost(1000, 7.5, 15), 300)
	t.equal("the cost never goes below 1", Economy.skipCost(1, 0.001, 100), 1)
	t.equal("a corrupt total costs nothing", Economy.skipCost(1000, 5, 0), 0)
	t.check("skipping is always cheaper than the egg", Economy.skipCost(1000, 15, 15) < 1000)
end
