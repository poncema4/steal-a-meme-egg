--!strict
local Guardian = require("../../src/shared/Game/Guardian")
local Nest = require("../../src/shared/Game/Nest")

local RADIUS, LEASH = 4.5, 150

return function(t)
	-- a calm guardian stays put
	local g = Guardian.new(100, 0, 20)
	Guardian.step(g, 1, nil, RADIUS, LEASH)
	t.check("an idle guardian does not move", g.x == 100 and g.z == 0 and g.state == "Idle")

	-- chasing: moves toward the thief at its speed
	Guardian.alert(g, 12)
	t.equal("alerting starts a chase", g.state, "Chase")
	local caught = Guardian.step(g, 1, { x = 160, z = 0 }, RADIUS, LEASH)
	t.check("it moves one second of speed toward the thief", g.x == 120 and not caught, tostring(g.x))
	local tz = Guardian.new(0, 0, 10)
	Guardian.alert(tz, 12)
	Guardian.step(tz, 1, { x = 0, z = 50 }, RADIUS, LEASH)
	t.check("it moves in z too", tz.z == 10 and tz.x == 0)

	-- catching
	local c = Guardian.new(0, 0, 20)
	Guardian.alert(c, 12)
	local got = Guardian.step(c, 1, { x = 22, z = 0 }, RADIUS, LEASH)
	t.check("it catches a thief within the radius", got)
	t.equal("and heads home afterwards", c.state, "Return")
	local missed = Guardian.new(0, 0, 20)
	Guardian.alert(missed, 12)
	t.check(
		"it does not catch a thief who stays out of reach",
		not Guardian.step(missed, 1, { x = 60, z = 0 }, RADIUS, LEASH)
	)

	-- a faster runner gets away and the guardian gives up
	local slow = Guardian.new(0, 0, 15)
	Guardian.alert(slow, 3)
	local x = 20
	local ever = false
	for _ = 1, 40 do
		x += 18 * 0.1
		if Guardian.step(slow, 0.1, { x = x, z = 0 }, RADIUS, LEASH) then
			ever = true
		end
	end
	t.check("a player faster than the guardian is never caught", not ever)
	t.check("and the guardian stopped chasing", slow.state ~= "Chase")

	-- the same chase with a slower player IS caught
	local fast = Guardian.new(0, 0, 18)
	Guardian.alert(fast, 12)
	x = 20
	ever = false
	for _ = 1, 100 do
		x += 14 * 0.1
		if Guardian.step(fast, 0.1, { x = x, z = 0 }, RADIUS, LEASH) then
			ever = true
			break
		end
	end
	t.check("a player slower than the guardian is caught", ever)

	-- the thief vanishing (died, left) sends it home
	local lost = Guardian.new(0, 0, 20)
	Guardian.alert(lost, 12)
	Guardian.step(lost, 0.5, { x = 100, z = 0 }, RADIUS, LEASH)
	Guardian.step(lost, 0.1, nil, RADIUS, LEASH)
	t.equal("with no target it returns", lost.state, "Return")
	for _ = 1, 20 do
		Guardian.step(lost, 0.5, nil, RADIUS, LEASH)
	end
	t.check("and ends up idle at home", lost.state == "Idle" and lost.x == 0 and lost.z == 0)

	-- the leash
	local far = Guardian.new(0, 0, 100)
	Guardian.alert(far, 60)
	for _ = 1, 5 do
		Guardian.step(far, 1, { x = 1000, z = 0 }, RADIUS, LEASH)
	end
	t.check("a guardian gives up when it is too far from its nest", far.state ~= "Chase")

	-- nests
	local n = Nest.new("Soggy")
	t.check("a new nest has its egg", Nest.hasEgg(n))
	t.equal("taking returns the tier", Nest.take(n, 25), "Soggy")
	t.check("and empties it", not Nest.hasEgg(n))
	t.equal("an empty nest gives nothing", Nest.take(n, 25), nil)
	t.check("it does not regrow early", not Nest.tick(n, 24, function()
		return "Disco"
	end) and not Nest.hasEgg(n))
	t.check("it regrows on time", Nest.tick(n, 1, function()
		return "Disco"
	end) and n.tier == "Disco")
	Nest.take(n, 25)
	Nest.giveBack(n, "Disco")
	t.check("a recovered egg goes back and stops the timer", n.tier == "Disco" and n.regrow == 0)

	-- a boss never leaves its own terrain
	local out = Guardian.new(5, 0, 20)
	out.x, out.z = -40, 500
	t.check("a boss outside its box is pulled back", Guardian.confine(out, 16, 240, -150, 150))
	t.check("to the nearest edge", out.x == 16 and out.z == 150)
	local inside = Guardian.new(100, 0, 20)
	t.check("a boss inside its box is left alone", not Guardian.confine(inside, 16, 240, -150, 150))
end
