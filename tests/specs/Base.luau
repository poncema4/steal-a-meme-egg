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
end
