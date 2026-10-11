--!strict
-- One boss guards a whole terrain: when it catches one thief it keeps chasing another who is still running, and it ignores
-- thieves of other terrains.
local Fake = require("../fake/Roblox")
local Zones = require("../../src/shared/Game/Zones")

return function(t)
	local world = Fake.world()
	local V3 = world.Vector3
	local ok, err = pcall(world.load, "src/server/main.server")
	t.check("the server starts", ok, tostring(err))
	if not ok then
		return
	end
	local wilds = world.load("src/server/Wilds")
	local ana = world.addPlayer("Ana", 81)
	local ben = world.addPlayer("Ben", 82)
	world.spawnCharacter(ana)
	world.spawnCharacter(ben)
	world.advance(0.6)
	local first, second = wilds.entries()[1], wilds.entries()[2]
	t.check("two nests of one terrain share one boss", first.boss == second.boss)
	for _, pair in { { ana, first }, { ben, second } } do
		local who, entry = pair[1], pair[2]
		entry.nest.tier = "Soggy"
		world.root(who).Position = V3.new(entry.egg.Position.X - 5, 3, entry.egg.Position.Z)
		entry.prompt.Triggered:Fire(who)
	end
	t.check("both are carrying", ana:GetAttribute("Carrying") ~= "" and ben:GetAttribute("Carrying") ~= "")
	-- the boss catches Ana (it stands on her); Ben keeps running
	local g = first.guardian
	world.root(ana).Position = V3.new(g.x, 3, g.z)
	world.root(ben).Position = V3.new(g.x - 60, 3, g.z)
	world.advance(0.3)
	t.equal("Ana is caught and drops the egg", ana:GetAttribute("Carrying"), "")
	t.check("Ben still carries his", ben:GetAttribute("Carrying") ~= "")
	t.equal("and the boss turns on Ben", g.state, "Chase")

	-- 2) the boss follows a thief through the terrains in between, and stops at the Safe Zone
	local zone = first.boss.zone
	local safeEdge = Zones.List[1].startX
	t.check("the first terrain is the Meadow, next to the Safe Zone", zone.id == "Meadow")
	world.root(ben).Position = V3.new(safeEdge - 20, 3, 0)
	for _ = 1, 80 do
		world.advance(0.25)
		t.check("the boss never enters the Safe Zone", g.x >= safeEdge)
	end
	t.check("the chase ends when the thief is in the Safe Zone", g.state ~= "Chase")

	-- 3) a boss from the deepest terrain follows a thief out through the other terrains
	local deep
	for _, entry in wilds.entries() do
		if entry.zone.id == "Cosmic" then
			deep = entry
			break
		end
	end
	local session = world.load("src/server/Session")
	session.addSpeedXp(ana, 1e7) -- fast enough for the deepest terrain
	deep.nest.tier = "Soggy"
	world.root(ana).Position = V3.new(deep.egg.Position.X - 5, 3, deep.egg.Position.Z)
	deep.prompt.Triggered:Fire(ana)
	t.check("Ana stole from the deepest terrain", ana:GetAttribute("Carrying") ~= "")
	local boss = deep.guardian
	local start = boss.x
	world.root(ana).Position = V3.new(Zones.List[3].startX + 50, 3, 0)
	for _ = 1, 160 do
		world.advance(0.25)
	end
	t.check("the Cosmic boss left its own terrain to chase her", boss.x < deep.zone.startX or boss.state ~= "Chase")
	t.check("and it started from its own terrain", start >= deep.zone.startX)
end
