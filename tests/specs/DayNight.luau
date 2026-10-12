--!nocheck
-- Day and night (Marco): 5 minute days, then 15 s of night and 5 s of dawn behind a wall with a countdown; at nightfall everyone
-- in the Wilds goes home and loses the egg they carry; eggs in the pens hatch 2x while it is dark.
local DayNight = require("../../src/shared/Game/DayNight")
local Fake = require("../fake/Roblox")

return function(t)
	local C = DayNight.CYCLE
	t.equal("a cycle is 5 minutes of day + 15 s night + 5 s dawn", C, 320)
	t.equal("the start of a cycle is day", DayNight.at(1000 * C).phase, "Day")
	t.equal("with 5 minutes until night", DayNight.at(1000 * C).nightIn, 300)
	t.equal("then night falls", DayNight.at(1000 * C + 300).phase, "Night")
	t.equal("the wall countdown starts at 20", DayNight.at(1000 * C + 300).wallLeft, 20)
	t.equal("after 15 s of night comes dawn", DayNight.at(1000 * C + 315).phase, "Dawn")
	t.equal("with 5 s left on the wall", DayNight.at(1000 * C + 315).wallLeft, 5)
	t.equal("then the wall drops and it is day again", DayNight.at(1000 * C + 320).phase, "Day")
	t.check(
		"the Wilds are closed at night and dawn only",
		DayNight.closed(1000 * C + 305) and DayNight.closed(1000 * C + 317) and not DayNight.closed(1000 * C + 10)
	)
	t.equal("eggs hatch 2x at night", DayNight.hatchBoost(1000 * C + 305), 2)
	t.equal("and normally by day", DayNight.hatchBoost(1000 * C + 10), 1)

	-- on the server
	local world = Fake.world()
	assert(pcall(world.load, "src/server/main.server"))
	local wilds = world.load("src/server/Wilds")
	local night = world.load("src/server/NightCycle")
	local Zones = require("../../src/shared/Game/Zones")
	local ana = world.addPlayer("Ana", 71)
	local ben = world.addPlayer("Ben", 72)
	world.spawnCharacter(ana)
	world.spawnCharacter(ben)
	world.advance(0.6)
	local entry = wilds.entries()[1]
	local root = world.root(ana)
	root.Position = world.Vector3.new(entry.egg.Position.X - 5, 3, entry.egg.Position.Z)
	entry.prompt.Triggered:Fire(ana)
	t.check("Ana is out in the Wilds carrying an egg", ana:GetAttribute("Carrying") ~= "")
	local benRoot = world.root(ben)
	benRoot.Position = world.Vector3.new(Zones.List[1].startX - 30, 3, 0)
	local benAt = benRoot.Position
	night.nightfall()
	world.advance(0.2)
	t.equal("at nightfall she loses the egg", ana:GetAttribute("Carrying"), "")
	t.check("it is back in its nest", entry.nest.tier ~= nil)
	t.check("and she is sent home (out of the Wilds)", world.root(ana).Position.X < Zones.List[1].startX)
	t.check(
		"a player already in the Safe Zone stays where they are",
		(world.root(ben).Position - benAt).Magnitude < 0.01
	)
	local wall = world.workspace:FindFirstChild("NightWall")
	t.check("there is a night wall at the edge of the Wilds", wall ~= nil)
end
