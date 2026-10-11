--!strict
-- The Speed number on the HUD and how fast you really run are the same thing: whatever level you have trained to, you run at that
-- level's speed, and the HUD number is that level's own big number (it has no ceiling: it keeps growing into B, T and Qa). Respawning, carrying an egg and Slow Mode change how fast you move, never the number.
local Fake = require("../fake/Roblox")
local Progression = require("../../src/shared/Game/Progression")

local function xpFor(level: number): number
	local total = 0
	for l = 0, level - 1 do
		total += Progression.xpForNext(l)
	end
	return total
end

return function(t)
	local world = Fake.world()
	local ok, err = pcall(world.load, "src/server/main.server")
	t.check("the server starts", ok, tostring(err))
	if not ok then
		return
	end
	local session = world.load("src/server/Session")
	local ana = world.addPlayer("Ana", 501)
	world.spawnCharacter(ana)
	world.advance(0.6)

	local trained = 0
	for _, level in { 0, 5, 12, 24, 30 } do
		session.addSpeedXp(ana, xpFor(level) - trained)
		trained = xpFor(level)
		local walk = Progression.walkSpeed(level)
		t.check(
			`level {level}: you run at {walk} studs a second`,
			math.abs(world.humanoid(ana).WalkSpeed - walk) < 1e-6,
			tostring(world.humanoid(ana).WalkSpeed)
		)
		t.equal(
			`level {level}: the number is that level's speed number`,
			ana:GetAttribute("SpeedStat"),
			Progression.speedStat(level)
		)
	end
	local top = world.humanoid(ana).WalkSpeed
	t.check("the best runner is much faster than a new one", top >= Progression.BASE_SPEED * 3)

	-- dying and coming back keeps your speed
	world.spawnCharacter(ana)
	world.advance(0.3)
	t.check(
		"a respawn keeps your speed",
		math.abs(world.humanoid(ana).WalkSpeed - top) < 1e-6,
		tostring(world.humanoid(ana).WalkSpeed)
	)

	-- carrying an egg slows the legs, not the number
	session.setCarry(ana, "Soggy", "Nest_Meadow_1")
	t.check(
		"carrying an egg slows you a little",
		math.abs(world.humanoid(ana).WalkSpeed - top * Progression.CARRY_FACTOR) < 1e-6
	)
	t.equal("but the number stays", ana:GetAttribute("SpeedStat"), Progression.speedStat(30))
	session.setCarry(ana, nil)
	t.check("putting it down gives the speed back", math.abs(world.humanoid(ana).WalkSpeed - top) < 1e-6)

	-- Slow Mode is for building: it holds you at a walk, and turning it off brings the speed back
	session.setSlow(ana, true)
	t.equal("Slow Mode walks at the normal pace", world.humanoid(ana).WalkSpeed, Progression.SLOW_SPEED)
	t.equal(
		"and the number still shows what you have trained",
		ana:GetAttribute("SpeedStat"),
		Progression.speedStat(30)
	)
	session.setSlow(ana, false)
	t.check("Slow Mode off: full speed again", math.abs(world.humanoid(ana).WalkSpeed - top) < 1e-6)
end
