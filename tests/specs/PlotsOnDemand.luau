--!strict
-- A base exists only while someone lives there (like the real game): three players, three bases; a base returns underground when
-- its owner leaves, and comes back to the same place when the next player takes it.
local Fake = require("../fake/Roblox")

return function(t)
	local world = Fake.world()
	local ok, err = pcall(world.load, "src/server/main.server")
	t.check("the server starts", ok, tostring(err))
	if not ok then
		return
	end
	local plots = world.load("src/server/Plots")
	local map = world.workspace:FindFirstChild("Map") :: Instance

	local function above(): { string }
		local out = {}
		for _, plot in map:GetChildren() do
			local floor = plot:FindFirstChild("Floor") :: BasePart?
			if string.match(plot.Name, "^Plot_") and floor and floor.Position.Y > -100 then
				table.insert(out, plot.Name)
			end
		end
		table.sort(out)
		return out
	end

	t.equal("an empty server shows no bases", #above(), 0)
	local lobby = map:FindFirstChild("LobbySpawn", true) :: SpawnLocation?
	t.check(
		"but there is a lobby spawn in the plaza for the moment before a base is assigned",
		lobby ~= nil and lobby.Enabled ~= false
	)
	local ana = world.addPlayer("Ana", 301)
	world.advance(0.6)
	t.equal("one player: one base, the middle of the arc", table.concat(above(), ","), "Plot_4")
	local ben = world.addPlayer("Ben", 302)
	local cy = world.addPlayer("Cy", 303)
	world.advance(0.6)
	t.equal("three players: three bases, centred on the arc", table.concat(above(), ","), "Plot_3,Plot_4,Plot_5")

	local plot4 = plots.of(ana)
	local home = plot4.center
	local floor = plot4.model:FindFirstChild("Floor") :: BasePart
	t.check(
		"a base stands exactly on its place on the arc",
		math.abs(floor.Position.X - home.X) < 0.01 and math.abs(floor.Position.Z - home.Z) < 0.01
	)
	local spawn = plot4.spawn :: SpawnLocation
	t.check("an occupied base has its spawn on", spawn.Enabled)
	local parked = map:FindFirstChild("Plot_1") :: Instance
	t.check(
		"a free base's spawn is off (nobody spawns underground)",
		not (parked:FindFirstChild("Spawn") :: SpawnLocation).Enabled
	)
	t.check("a free base is far below the map", (parked:FindFirstChild("Floor") :: BasePart).Position.Y < -500)

	world.removePlayer(ben)
	world.advance(0.6)
	t.equal("when a player leaves their base goes away", table.concat(above(), ","), "Plot_3,Plot_4")
	local dan = world.addPlayer("Dan", 304)
	world.advance(0.6)
	t.equal("the next player takes the freed base", table.concat(above(), ","), "Plot_3,Plot_4,Plot_5")
	local back = plots.of(dan).model:FindFirstChild("Floor") :: BasePart
	t.check(
		"and it comes back to the same place",
		math.abs(back.Position.X - plots.of(dan).center.X) < 0.01 and math.abs(back.Position.Y - -0.3) < 0.01
	)

	for i = 1, 5 do
		world.addPlayer("P" .. i, 400 + i)
	end
	world.advance(0.6)
	t.equal("eight players: all eight bases", #above(), 8)
	t.check("nobody shares a base", plots.of(ana) ~= plots.of(cy) and plots.of(ana) ~= plots.of(dan))
end
