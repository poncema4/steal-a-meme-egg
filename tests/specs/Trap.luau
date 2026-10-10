--!strict
local Guardian = require("../../src/shared/Game/Guardian")
local Trap = require("../../src/shared/Game/Trap")

return function(t)
	local s = Trap.new()
	t.check("a new player may place a trap", Trap.place(s, 10, 10, 0))
	t.equal("and it is counted", Trap.count(s), 1)
	local ok, why = Trap.place(s, 20, 20, 0.5)
	t.check("the next one needs a moment", not ok and why == "Your next trap is not ready yet")
	t.check("after the cooldown it works", Trap.place(s, 20, 20, 3))
	t.check("a third works", Trap.place(s, 30, 30, 6))
	local ok4, why4 = Trap.place(s, 40, 40, 9)
	t.check("a fourth is refused: at most 3 at once", not ok4 and why4 == "You can only have 3 traps out at once")
	t.equal("still three", Trap.count(s), 3)

	-- springing one frees a place
	t.equal("a guardian on a trap springs it", Trap.hit(s, 11, 10), 1)
	t.equal("one far away does not", Trap.hit(s, 100, 100), nil)
	table.remove(s.spots, 1)
	t.check("after one is used a new one can go down", Trap.place(s, 40, 40, 12))

	-- the nearest trap is the one that springs
	local n = Trap.new()
	Trap.place(n, 0, 0, 0)
	Trap.place(n, 4, 0, 5)
	t.equal("two in range: the closer springs", Trap.hit(n, 3.5, 0), 2)
	t.equal("the edge of the radius counts", Trap.hit(n, -Trap.RADIUS, 0), 1)

	-- they rot away
	local r = Trap.new()
	Trap.place(r, 0, 0, 0)
	t.equal("a trap lasts a while", Trap.prune(r, Trap.LIFETIME - 1), 0)
	t.equal("then it is gone", Trap.prune(r, Trap.LIFETIME), 1)
	t.equal("and the place is free", Trap.count(r), 0)
	local full = Trap.new()
	for i = 1, 3 do
		Trap.place(full, i, i, i * 3)
	end
	t.check("when old traps rot, placing works again", Trap.place(full, 9, 9, Trap.LIFETIME + 10))

	-- hostile input
	local bad = Trap.new()
	t.check("NaN is refused", not Trap.place(bad, 0 / 0, 0, 0))
	t.check("infinity is refused", not Trap.place(bad, 0, math.huge, 0))
	t.equal("nothing was placed", Trap.count(bad), 0)

	-- 20,000 random actions never break the limit
	local p = Trap.new()
	local broken = false
	local now = 0
	for _ = 1, 20000 do
		now += math.random() * 3
		local roll = math.random()
		if roll < 0.6 then
			Trap.place(p, math.random() * 100, math.random() * 100, now)
		elseif roll < 0.8 and #p.spots > 0 then
			table.remove(p.spots, math.random(1, #p.spots))
		else
			Trap.prune(p, now)
		end
		if Trap.count(p) > Trap.MAX then
			broken = true
		end
	end
	t.check("20,000 random actions never put more than 3 traps down", not broken)

	-- a stunned guardian holds still, but the chase clock runs
	local g = Guardian.new(0, 0, 10)
	Guardian.alert(g, 10)
	Guardian.stunned(g, 3)
	local caught = Guardian.step(g, 1, { x = 20, z = 0 }, 4.5, 150)
	t.equal("a stunned guardian does not move", g.x, 0)
	t.check("and cannot catch anyone", not caught)
	t.check("the stun counts down", g.stun == 2)
	t.equal("the chase clock still runs", g.chaseLeft, 9)
	Guardian.stunned(g, 1)
	t.equal("a shorter stun does not shorten a longer one", g.stun, 2)
	Guardian.step(g, 3, { x = 20, z = 0 }, 4.5, 150)
	Guardian.step(g, 1, { x = 20, z = 0 }, 4.5, 150)
	t.check("when it wears off the guardian runs again", g.x > 0)
	local gone = Guardian.new(0, 0, 10)
	Guardian.alert(gone, 2)
	Guardian.stunned(gone, 5)
	Guardian.step(gone, 3, { x = 20, z = 0 }, 4.5, 150)
	Guardian.step(gone, 3, { x = 20, z = 0 }, 4.5, 150)
	t.check("a long stun lets the thief escape: the guardian gives up", gone.state ~= "Chase")
end
