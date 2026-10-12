--!strict
local Eggs = require("../../src/shared/Game/Eggs")

return function(t)
	-- every pool entry is a real character, and every character belongs to exactly one egg
	local seen: { [string]: number } = {}
	local allTiers: { Eggs.Tier } = {}
	for _, tier in Eggs.Tiers do
		table.insert(allTiers, tier)
	end
	for _, tier in Eggs.LimitedTiers do
		table.insert(allTiers, tier)
	end
	for _, tier in allTiers do
		for _, entry in tier.pool do
			t.check(`{entry.id} exists`, Eggs.character(entry.id) ~= nil)
			seen[entry.id] = (seen[entry.id] or 0) + 1
		end
	end
	local once = true
	for id in Eggs.Characters do
		if seen[id] ~= 1 then
			once = false
		end
	end
	t.check("every character is in exactly one egg", once)

	-- prices and income only go up from egg to egg (a pricier egg is always better)
	local ok = true
	for i = 2, #Eggs.Tiers do
		if Eggs.Tiers[i].price <= Eggs.Tiers[i - 1].price then
			ok = false
		end
		local worst = Eggs.Characters[Eggs.Tiers[i].pool[1].id].income
		local bestBefore = Eggs.Characters[Eggs.Tiers[i - 1].pool[#Eggs.Tiers[i - 1].pool].id].income
		if worst <= bestBefore then
			ok = false
		end
	end
	t.check("a pricier egg always beats the one before it", ok)

	-- a character pays its egg back in a sane time (not instantly, not never)
	local payback = true
	for _, tier in Eggs.Tiers do
		local avg, total = 0, 0
		for _, entry in tier.pool do
			avg += Eggs.Characters[entry.id].income * entry.weight
			total += entry.weight
		end
		avg /= total
		local seconds = tier.price / avg
		if seconds < 20 or seconds > 400 then
			payback = false
		end
	end
	t.check("every egg pays itself back in 20 to 400 seconds on average", payback)

	-- the chances the shop shows are exactly the roll's odds, luck included
	local baseOdds = Eggs.chances("GooseGold", 1)
	t.check(
		"base chances are the weights (60/30/10)",
		math.abs(baseOdds[1].percent - 60) < 1e-9 and math.abs(baseOdds[3].percent - 10) < 1e-9
	)
	local luckyOdds = Eggs.chances("GooseGold", 2)
	t.check(
		"2x luck moves odds toward the rare pets",
		luckyOdds[3].percent > baseOdds[3].percent and luckyOdds[1].percent < baseOdds[1].percent
	)
	local sum = 0
	for _, c in luckyOdds do
		sum += c.percent
	end
	t.check("they add up to 100%", math.abs(sum - 100) < 1e-9)
	local mythicHits, rolls = 0, 20000
	local seed = 12345
	local function rng()
		seed = (seed * 1103515245 + 12345) % 2147483648
		return seed / 2147483648
	end
	for _ = 1, rolls do
		if Eggs.roll("GooseGold", 2, rng) == "MythicGoose" then
			mythicHits += 1
		end
	end
	t.check(
		"and real rolls land on them (Mythic within 1.5% of the shown chance)",
		math.abs(mythicHits / rolls * 100 - luckyOdds[3].percent) < 1.5,
		tostring(mythicHits / rolls * 100)
	)

	-- the roll follows the weights
	t.equal(
		"rng at 0 gives the commonest",
		Eggs.roll("Soggy", 1, function()
			return 0
		end),
		"SoggyToast"
	)
	t.equal(
		"rng just under 1 gives the rarest",
		Eggs.roll("Soggy", 1, function()
			return 0.9999
		end),
		"SleepySock"
	)
	t.equal(
		"rng 0.7 lands in the middle entry",
		Eggs.roll("Soggy", 1, function()
			return 0.7
		end),
		"BonkBean"
	)

	-- luck shifts odds toward the rare end: count the rarest over many fixed samples
	local function rareShare(luck: number): number
		local n, hits = 4000, 0
		for i = 1, n do
			local r = (i - 0.5) / n
			if Eggs.roll("Soggy", luck, function()
				return r
			end) == "SleepySock" then
				hits += 1
			end
		end
		return hits / n
	end
	local base, lucky = rareShare(1), rareShare(2)
	t.check("normal luck: the rarest is about 10%", math.abs(base - 0.10) < 0.01, tostring(base))
	t.check("2x luck makes the rarest clearly likelier", lucky > base * 1.8, `{lucky} vs {base}`)
	t.check("luck below 1 is treated as 1", rareShare(0.2) == base)

	-- mutations
	t.equal(
		"a low roll is Normal",
		Eggs.mutation(1, function()
			return 0.5
		end),
		"Normal"
	)
	t.equal(
		"a roll over 0.95 is Gold",
		Eggs.mutation(1, function()
			return 0.97
		end),
		"Gold"
	)
	t.equal(
		"a roll over 0.99 is Rainbow",
		Eggs.mutation(1, function()
			return 0.995
		end),
		"Rainbow"
	)
	local function mut(luck: number, r: number): string
		return Eggs.mutation(luck, function()
			return r
		end)
	end
	t.equal("2x luck lifts 0.48 (0.96 after luck) into Gold", mut(2, 0.48), "Gold")
	t.equal("2x luck lifts 0.499 into Rainbow", mut(2, 0.499), "Rainbow")
	t.equal("2x luck leaves 0.4 as Normal", mut(2, 0.4), "Normal")

	-- aura grows with income and mutation
	t.check("rarer means more aura", Eggs.aura("OmegaMeme") > Eggs.aura("SoggyToast"))
	t.check(
		"a Gold one has more aura than a Normal one",
		Eggs.aura("BonkBean", "Gold") > Eggs.aura("BonkBean", "Normal")
	)
	t.equal("an unknown character has no aura", Eggs.aura("Nope"), 0)
end
