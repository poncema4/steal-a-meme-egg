--!strict
-- Pets roam their patch of the pen: smoothly, within the patch, never fast, and the same for everyone.
local Wander = require("../../src/shared/Game/Wander")

return function(t)
	local radius = 3
	local inside, smooth, slow, moved, rested = true, true, true, false, false
	for seed = 1, 40 do
		local last = Wander.pose(seed, 0, radius)
		for step = 1, 4000 do
			local now = step * 0.05
			local p = Wander.pose(seed, now, radius)
			if math.sqrt(p.x * p.x + p.z * p.z) > radius + 1e-6 then
				inside = false
			end
			local jump = math.sqrt((p.x - last.x) ^ 2 + (p.z - last.z) ^ 2)
			if jump > 0.5 then
				smooth = false
			end
			if jump / 0.05 > Wander.topSpeed(radius) + 1e-6 then
				slow = false
			end
			if p.walking then
				moved = true
			else
				rested = true
			end
			last = p
		end
	end
	t.check("a pet never leaves its patch", inside)
	t.check("a pet never jumps: every frame is a small step from the last", smooth)
	t.check("a pet never zooms", slow)
	t.check("a pet walks", moved)
	t.check("and it also stops to rest", rested)

	local a, b = Wander.pose(7, 123.4, radius), Wander.pose(7, 123.4, radius)
	t.check("the same time gives the same spot for everyone", a.x == b.x and a.z == b.z)
	local other = Wander.pose(8, 123.4, radius)
	local differs = false
	for tt = 1, 60 do
		local p, q = Wander.pose(7, tt, radius), Wander.pose(8, tt, radius)
		if math.abs(p.x - q.x) > 0.1 then
			differs = true
		end
	end
	t.check("pets with different seeds do not walk in step", differs and other ~= nil)
	t.check("a topSpeed of a few studs a second is a calm walk", Wander.topSpeed(radius) < 3)
end
