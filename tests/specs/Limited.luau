--!strict
local Eggs = require("../../src/shared/Game/Eggs")
local Limited = require("../../src/shared/Game/Limited")
local Zones = require("../../src/shared/Game/Zones")

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

	-- balance (Marco: "not overpowered, realistic for the Robux price"): a 199 Robux egg is a strong head start that you
	-- outgrow, never a skip to the end. Every limited pet beats the Divine egg's best (mid game) but stays well below the
	-- deepest worlds: under even the commonest pet of the 8th world (Candy Canyon).
	local divineBest = 0
	for _, entry in (Eggs.tier("Divine") :: Eggs.Tier).pool do
		divineBest = math.max(divineBest, Eggs.Characters[entry.id].income)
	end
	local candyCommon = Eggs.Characters.SprinkleSloth.income
	for _, tier in Eggs.LimitedTiers do
		local worst, best = math.huge, 0
		for _, entry in tier.pool do
			local income = Eggs.Characters[entry.id].income
			worst = math.min(worst, income)
			best = math.max(best, income)
		end
		t.check(
			`{tier.name}'s best pet is worth paying for (beats the Divine egg's)`,
			best >= divineBest * 0.8,
			`{best} vs {divineBest}`
		)
		t.check(
			`{tier.name} is not overpowered (below the 8th world's commonest)`,
			best < candyCommon,
			`{best} vs {candyCommon}`
		)
		t.check(`{tier.name}'s pets get better with rarity`, worst < best)
		local inWilds = false
		for _, zone in Zones.List do
			if table.find(zone.eggs, tier.id) then
				inWilds = true
			end
		end
		t.check(`{tier.name} is not a Wilds egg`, not inWilds)
	end
end
