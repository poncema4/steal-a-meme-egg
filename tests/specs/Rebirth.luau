--!strict
local Daily = require("../../src/shared/Game/Daily")
local Rebirth = require("../../src/shared/Game/Rebirth")

return function(t)
	-- rebirth
	t.equal("the first rebirth costs the base price", Rebirth.cost(0), Rebirth.BASE_COST)
	t.equal("each one costs 5x more", Rebirth.cost(2), Rebirth.BASE_COST * 25)
	t.equal("a negative count costs the base price", Rebirth.cost(-3), Rebirth.BASE_COST)
	t.equal("no rebirths means no bonus", Rebirth.multiplier(0), 1)
	t.equal("each rebirth adds 25%", Rebirth.multiplier(4), 2)
	t.check("all 20 rebirths are a fair 6x, not overpowered", Rebirth.multiplier(Rebirth.MAX) <= 6)
	t.equal("the bonus stops at the cap", Rebirth.multiplier(500), Rebirth.multiplier(Rebirth.MAX))
	t.check("you need the coins", not Rebirth.can(0, Rebirth.BASE_COST - 1) and Rebirth.can(0, Rebirth.BASE_COST))
	t.check("you cannot go past the cap", not Rebirth.can(Rebirth.MAX, 1e30))
	local rising = true
	for n = 1, Rebirth.MAX do
		if Rebirth.cost(n) <= Rebirth.cost(n - 1) or Rebirth.multiplier(n) <= Rebirth.multiplier(n - 1) then
			rising = false
		end
	end
	t.check("each rebirth costs more and pays more", rising)

	-- daily
	local day = 20000
	t.equal("a first-ever login starts the streak at 1", Daily.next(nil, 0, day), 1)
	t.equal("logging in again the same day gives nothing", Daily.next(day, 3, day), nil)
	t.equal("the next day extends the streak", Daily.next(day - 1, 3, day), 4)
	t.equal("a missed day resets it", Daily.next(day - 2, 6, day), 1)
	t.equal("a long absence resets it", Daily.next(day - 300, 6, day), 1)
	t.equal("a clock that went backwards still gives nothing today", Daily.next(day + 5, 2, day), 1)
	t.equal("a day is 86400 seconds", Daily.dayOf(86400 * 3 + 5), 3)
	t.equal("midnight UTC rolls the day", Daily.dayOf(86399), 0)

	local coins1, egg1 = Daily.reward(1, 0)
	local coins3 = Daily.reward(3, 0)
	t.check("day 1 pays a base amount and no egg", coins1 == 500 and egg1 == nil)
	t.check("later days pay more", coins3 > coins1)
	local coins7, egg7 = Daily.reward(7, 0)
	t.check("day 7 also gives an egg", egg7 == "Disco" and coins7 > coins3)
	local _, egg8 = Daily.reward(8, 0)
	t.equal("the cycle then starts again", egg8, nil)
	t.equal("day 14 gives an egg again", select(2, Daily.reward(14, 0)), "Disco")
	t.check("a rich player gets at least a minute of income", Daily.reward(1, 50000) >= 50000 * 60)
end
