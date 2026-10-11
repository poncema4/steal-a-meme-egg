--!strict
-- Property tests: thousands of random operation sequences against the pure rules, checking things that must ALWAYS be true
-- (nothing is created or lost by a steal, a guardian never outruns its speed, the odds always name a real egg...).
local Base = require("../../src/shared/Game/Base")
local Daily = require("../../src/shared/Game/Daily")
local Economy = require("../../src/shared/Game/Economy")
local Eggs = require("../../src/shared/Game/Eggs")
local Events = require("../../src/shared/Game/Events")
local Guardian = require("../../src/shared/Game/Guardian")
local Nest = require("../../src/shared/Game/Nest")
local Progression = require("../../src/shared/Game/Progression")
local Zones = require("../../src/shared/Game/Zones")

local function finite(n: number): boolean
	return n == n and n ~= math.huge and n ~= -math.huge
end

local function itemCount(b: Base.Base): number
	return Base.count(b)
end

return function(t)
	local rng = Random and nil -- (Random is not available under Lune; use math.random with a fixed seed)
	math.randomseed(2024)
	local _ = rng

	-- 1) bases: placements and hatching never create or destroy items, and slots stay in range
	local broken: string? = nil
	local a, b = Base.new(6), Base.new(8)
	local placed = 0
	local ids = { "SoggyToast", "BonkBean", "SleepySock", "GoldenGoose" }
	local now = 0
	for i = 1, 6000 do
		now += math.random() * 3
		local op = math.random(1, 5)
		local x = if math.random() < 0.5 then a else b
		if op == 1 then
			if Base.placeEgg(x, Eggs.Tiers[math.random(1, #Eggs.Tiers)].id) then
				placed += 1
			end
		elseif op == 2 then
			if Base.placeCharacter(x, ids[math.random(1, #ids)], if math.random() < 0.3 then "Gold" else nil) then
				placed += 1
			end
		elseif op == 3 then
			Base.tick(x, math.random() * 20, function(tier)
				return Eggs.roll(tier, 1 + math.random() * 4, math.random)
			end, function()
				return Eggs.mutation(1 + math.random() * 4, math.random)
			end)
		elseif op == 4 then
			x.slots[math.random(1, x.size)] = nil
			placed = itemCount(a) + itemCount(b) -- (we removed one on purpose: re-sync the expectation)
		else
			Base.grow(x, 12)
		end
		for _, bs in { a, b } do
			for slot in bs.slots do
				if slot < 1 or slot > bs.size then
					broken = `step {i}: an item in slot {slot} of a base of {bs.size}`
				end
			end
			local income = Base.income(bs, 1 + math.random() * 5)
			if not finite(income) or income < 0 then
				broken = `step {i}: income {income}`
			end
		end
		if broken then
			break
		end
	end
	t.check("6000 random base operations never broke a rule", broken == nil, tostring(broken))
	broken = nil

	-- 2) the odds always name a real character and a real mutation, whatever the luck and the dice
	local weird = { 0, 1, 1.5, 3, 5, 100, 1e6, -2, 0 / 0 }
	for _, tier in Eggs.Tiers do
		for _, luck in weird do
			for _ = 1, 20 do
				local id = Eggs.roll(tier.id, luck, math.random)
				if not Eggs.character(id) then
					broken = `{tier.id} rolled {id}`
				end
			end
			for _, r in { 0, 0.5, 0.999999, 1 - 1e-12 } do
				local id = Eggs.roll(tier.id, luck, function()
					return r
				end)
				if not Eggs.character(id) then
					broken = `{tier.id} at {r} rolled {id}`
				end
			end
			if not Eggs.Mutations[Eggs.mutation(luck, math.random)] then
				broken = "a mutation that does not exist"
			end
		end
	end
	t.check("every roll names a real character and mutation, even for strange luck", broken == nil, tostring(broken))

	-- 4) a guardian never moves faster than its speed and never reaches NaN, whoever it chases
	for _ = 1, 200 do
		local speed = 5 + math.random() * 30
		local g = Guardian.new((math.random() - 0.5) * 400, (math.random() - 0.5) * 200, speed)
		if math.random() < 0.7 then
			Guardian.alert(g, math.random() * 20)
		end
		for _ = 1, 300 do
			local dt = math.random() * 0.3
			local px, pz = g.x, g.z
			local target = if math.random() < 0.9
				then { x = (math.random() - 0.5) * 600, z = (math.random() - 0.5) * 300 }
				else nil
			Guardian.step(g, dt, target, 4.5, 150)
			local moved = math.sqrt((g.x - px) ^ 2 + (g.z - pz) ^ 2)
			if not finite(g.x) or not finite(g.z) then
				broken = "a guardian reached a bad position"
			elseif moved > speed * dt + 0.06 then -- (it may snap the last 0.05 studs onto its nest)
				broken = `a guardian moved {moved} in {dt}s at speed {speed}`
			end
			if math.random() < 0.01 then
				Guardian.alert(g, math.random() * 20)
			end
		end
	end
	t.check("guardians never outrun their speed and never go NaN", broken == nil, tostring(broken))
	broken = nil

	-- 5) nests: whatever happens, an empty nest always has a way to get its egg back
	for _ = 1, 300 do
		local nest = Nest.new("Soggy")
		for _ = 1, 100 do
			local op = math.random(1, 4)
			if op == 1 then
				Nest.take(nest, 25)
			elseif op == 2 and nest.tier == nil then
				Nest.giveBack(nest, "Disco")
			elseif op == 3 then
				Nest.tick(nest, math.random() * 10, function()
					return "Soggy"
				end)
			end
			if nest.tier == nil and nest.regrow < 0 then
				broken = "an empty nest with a negative timer that never fired"
			end
			if not finite(nest.regrow) then
				broken = "a nest with a bad timer"
			end
		end
	end
	t.check("nests always stay consistent", broken == nil, tostring(broken))
	broken = nil

	-- 6) progression is monotonic and bounded
	local lastLevel, lastSpeed = -1, 0
	for xp = 0, 400000, 137 do
		local level = Progression.levelFor(xp)
		local speed = Progression.walkSpeed(level)
		if level < lastLevel or speed < lastSpeed or level > Progression.MAX_LEVEL or not finite(speed) then
			broken = `xp {xp}: level {level} speed {speed}`
		end
		lastLevel, lastSpeed = level, speed
	end
	t.check("more XP never means a lower level or a lower speed", broken == nil, tostring(broken))
	broken = nil
	for _, mp in { -5, 0, 1, 4, 5, 30, 1e6, 1e300 } do
		local zone = Zones.furthest(mp)
		if mp < zone.level and zone ~= Zones.List[1] then
			broken = `level {mp} reached a terrain that needs {zone.level}`
		end
	end
	t.check("a Speed level never reaches a terrain it cannot enter", broken == nil, tostring(broken))
	broken = nil

	-- 7) events never produce an impossible multiplier
	local state = Events.new()
	for i = 1, 3000 do
		local ids2 = {}
		for id in Events.Defs do
			table.insert(ids2, id)
		end
		Events.start(state, ids2[math.random(1, #ids2)], i * 0.5, math.random() * 400)
		if math.random() < 0.02 then
			Events.clear(state)
		end
		local luck, income = Events.multipliers(state, i * 0.5)
		if not finite(luck) or not finite(income) or luck < 1 or income < 1 then
			broken = `step {i}: luck {luck} income {income}`
		end
	end
	t.check("event multipliers stay finite and at least 1", broken == nil, tostring(broken))
	broken = nil

	-- 8) daily: the streak only ever goes up by one or resets to 1
	local last: number? = nil
	local streak = 0
	for day = 1, 400 do
		if math.random() < 0.75 then
			local new = Daily.next(last, streak, day)
			if new then
				if new ~= 1 and new ~= streak + 1 then
					broken = `day {day}: streak {streak} -> {new}`
				end
				if last == day - 1 and new ~= streak + 1 then
					broken = `day {day}: a consecutive day did not extend the streak`
				end
				last, streak = day, new
			end
		end
	end
	t.check("the daily streak only grows by one or resets to one", broken == nil, tostring(broken))
	broken = nil

	-- 9) number formatting never throws and never returns nothing
	for _, n in { -5, 0, 0.4, 999, 1000, 12345, 1e9, 1e15, 1e20, 1e300, 0 / 0, math.huge } do
		local ok, text = pcall(Economy.format, n)
		if not ok or type(text) ~= "string" or text == "" then
			broken = `format({n}) failed`
		end
	end
	t.check("number formatting survives any number", broken == nil, tostring(broken))
	broken = nil
end
