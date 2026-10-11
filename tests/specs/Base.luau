--!strict
local Base = require("../../src/shared/Game/Base")

local function const(v: string): () -> string
	return function()
		return v
	end
end

return function(t)
	local base = Base.new(3)
	t.equal("a new base is empty", Base.count(base), 0)
	t.equal("the first egg goes in slot 1", Base.placeEgg(base, "Soggy"), 1)
	t.equal("the next in slot 2", Base.placeEgg(base, "Disco"), 2)
	t.equal("an unknown egg is refused", Base.placeEgg(base, "Nope"), nil)
	t.equal("the third fits", Base.placeEgg(base, "Soggy"), 3)
	t.equal("a full base refuses another", Base.placeEgg(base, "Soggy"), nil)
	t.equal("a full base refuses a character too", Base.placeCharacter(base, "BonkBean"), nil)

	-- hatching: not before the timer, exactly at it
	local roll = function(tier: string): string
		return if tier == "Soggy" then "BonkBean" else "GigachadGoose"
	end
	t.equal("nothing hatches early", #Base.tick(base, 7, roll, const("Normal")), 0)
	t.equal("income is 0 while only eggs", Base.income(base, 1), 0)
	local hatched = Base.tick(base, 1, roll, const("Normal"))
	t.equal("both Soggy eggs hatch at 8 s", #hatched, 2)
	t.equal("slot 1 is now the rolled character", base.slots[1].id, "BonkBean")
	t.equal("the Disco egg is still an egg", base.slots[2].kind, "egg")
	t.equal("income now counts the two characters", Base.income(base, 1), 4)
	t.equal("a multiplier scales income", Base.income(base, 2.5), 10)

	-- a Gold character earns double
	local gold = Base.new(2)
	Base.placeCharacter(gold, "BonkBean", "Gold")
	t.equal("a Gold character pays double", Base.income(gold, 1), 4)

	t.equal("growing adds a slot", Base.grow(Base.new(6), 12), 7)
	t.equal("but not past the max", Base.grow(Base.new(12), 12), 12)

	-- eggs can be put anywhere in the pen: where the player stands, inside the fence, never on top of another egg
	local pen = Base.new(6)
	local first = Base.placeEgg(pen, "Soggy", nil, { x = 3, z = -4 }) :: number
	t.check(
		"an egg goes where it was put",
		pen.slots[first].at ~= nil and pen.slots[first].at.x == 3 and pen.slots[first].at.z == -4
	)
	local second = Base.placeEgg(pen, "Soggy", nil, { x = 3.5, z = -4.5 }) :: number
	local a, b = pen.slots[first].at :: Base.Spot, pen.slots[second].at :: Base.Spot
	t.check("a second egg is nudged off the first", (a.x - b.x) ^ 2 + (a.z - b.z) ^ 2 >= Base.EGG_GAP ^ 2 - 1e-6)
	local outside = Base.placeEgg(pen, "Soggy", nil, { x = 500, z = -900 }) :: number
	local o = pen.slots[outside].at :: Base.Spot
	t.check(
		"an egg is never put outside the fence",
		o.x <= Base.MAX_X and o.x >= Base.MIN_X and o.z >= Base.MIN_Z and o.z <= Base.MAX_Z
	)
	local junk = Base.clampSpot(0 / 0, math.huge)
	t.check("junk coordinates become a real spot", junk.x == 0 and junk.z == Base.MAX_Z)
	local bought = Base.placeEgg(pen, "Soggy") :: number
	t.check("a bought egg has no chosen spot (it uses its slot's default)", pen.slots[bought].at == nil)
	local dflt = Base.defaultSpot(1)
	t.check(
		"default spots are inside the pen",
		dflt.x >= Base.MIN_X and dflt.x <= Base.MAX_X and dflt.z >= Base.MIN_Z and dflt.z <= Base.MAX_Z
	)
end
