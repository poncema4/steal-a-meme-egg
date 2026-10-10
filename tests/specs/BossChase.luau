--!strict
-- One boss guards a whole terrain: when it catches one thief it keeps chasing another who is still running, and it ignores
-- thieves of other terrains.
local Fake = require("../fake/Roblox")

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
end
