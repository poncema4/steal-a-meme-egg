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

	-- locking
	local victim, thief = Base.new(3), Base.new(3)
	Base.placeCharacter(victim, "SleepySock")
	t.equal("an unlocked base can be raided", Base.canSteal(victim, thief, 1, 100), nil)
	local locked, _ = Base.lock(victim, 100, 45, 90)
	t.check("locking works the first time", locked)
	t.equal("a locked base cannot be raided", Base.canSteal(victim, thief, 1, 120), "locked")
	t.equal("the lock ends on time", Base.canSteal(victim, thief, 1, 145), nil)
	local again, wait = Base.lock(victim, 150, 45, 90)
	t.check("the lock is on cooldown", not again and wait == 40, tostring(wait))
	local third = Base.lock(victim, 190, 45, 90)
	t.check("and works again after the cooldown", third)

	-- raiding
	local v2, th2 = Base.new(3), Base.new(1)
	Base.placeCharacter(v2, "SleepySock")
	Base.placeCharacter(v2, "BonkBean", "Gold")
	t.equal("an empty slot cannot be raided", Base.canSteal(v2, th2, 3, 0), "empty")
	local ok, slot = Base.steal(v2, th2, 2, 0)
	t.check("a raid moves the character", ok and slot == 1)
	t.equal("it left the victim", v2.slots[2], nil)
	t.equal("and kept its mutation", th2.slots[1].mutation, "Gold")
	t.equal("a thief with no room is refused", select(2, Base.steal(v2, th2, 1, 0)), "full")
	t.equal("the refused raid took nothing", v2.slots[1].id, "SleepySock")

	t.equal("growing adds a slot", Base.grow(Base.new(6), 12), 7)
	t.equal("but not past the max", Base.grow(Base.new(12), 12), 12)
end
