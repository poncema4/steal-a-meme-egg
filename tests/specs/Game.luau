--!strict
-- Runs the REAL server scripts against the fake Roblox world: the map is built, players get bases, eggs are granted and
-- hatch and earn, and admin events change the multipliers.
local Fake = require("../fake/Roblox")
local Daily = require("../../src/shared/Game/Daily")
local Eggs = require("../../src/shared/Game/Eggs")
local Zones = require("../../src/shared/Game/Zones")

return function(t)
	local world = Fake.world()
	world.studio = false
	local storage = world.service("ReplicatedStorage")
	local ok, err = pcall(world.load, "src/server/main.server")
	t.check("the server script starts without error", ok, tostring(err))
	if not ok then
		return
	end
	local map = world.workspace:FindFirstChild("Map")
	t.check("the map is built", map ~= nil)
	local plotCount = 0
	for _, child in (map :: Instance):GetChildren() do
		if string.match(child.Name, "^Plot_") then
			plotCount += 1
		end
	end
	t.equal("there are 8 base plots", plotCount, 8)
	-- the corridor: walls on both sides, a red line ending the Safe Zone, and SAFE ZONE written on the ground
	local walls = { [-1] = 0, [1] = 0 }
	for _, child in (map :: Instance):GetChildren() do
		if child.Name == "Wall" then
			walls[if child.Position.Z < 0 then -1 else 1] += 1
		end
	end
	t.check("the corridor has walls along both sides", walls[-1] > 10 and walls[1] > 10)
	t.check("and a wall at each end", (map :: Instance):FindFirstChild("EndWall") ~= nil)
	local line = (map :: Instance):FindFirstChild("RedLine") :: Part
	t.check("a red line marks the edge of the Safe Zone", line ~= nil)
	-- the gateway over the red line: SAFE ZONE on the side that faces the pens, THE WILDS on the other
	local gate = (map :: Instance):FindFirstChild("GateSign") :: Part
	t.check("a gateway stands over the red line", gate ~= nil)
	local faces: { [string]: string } = {}
	for _, d in gate:GetChildren() do
		if d:IsA("SurfaceGui") then
			faces[tostring((d :: SurfaceGui).Face)] = ((d :: Instance):FindFirstChild("GateText") :: TextLabel).Text
		end
	end
	local front = faces[tostring(world.enum.NormalId.Front)]
	t.equal("its front face says SAFE ZONE", front, "SAFE ZONE")
	t.check(
		"and its back face points to the Wilds",
		string.find(faces[tostring(world.enum.NormalId.Back)] or "", "WILDS", 1, true) ~= nil
	)
	t.check("the front face looks toward the pens (west)", gate.CFrame.LookVector.X < -0.99)
	-- pens stand in a semicircle: all west of the red line, inside the walls, the same distance from the plaza, clear of each other
	local centers: { Vector3 } = {}
	for _, child in (map :: Instance):GetChildren() do
		if string.match(child.Name, "^Plot_") then
			table.insert(centers, (child :: Model).PrimaryPart.Position)
		end
	end
	local World = world.load("src/server/World")
	local penOk, apart, ring = true, true, true
	for i, c in centers do
		if c.X - 23 < World.SAFE_BACK or c.X + 23 > line.Position.X or math.abs(c.Z) + 23 > Zones.WIDTH / 2 then
			penOk = false
		end
		if math.abs((c - World.PLAZA).Magnitude - World.RADIUS) > 0.5 then
			ring = false
		end
		for j = i + 1, #centers do
			if (c - centers[j]).Magnitude < World.PEN + 1 then
				apart = false
			end
		end
	end
	t.check("every pen is inside the Safe Zone and the walls", penOk)
	t.check("the pens stand on a circle around the plaza", ring)
	t.check("and no two pens overlap", apart)

	local ana = world.addPlayer("Ana", 11)
	local ben = world.addPlayer("Ben", 12)
	world.advance(0.6)
	-- 150 starting coins plus the first daily reward
	local firstDay = (Daily.reward(1, 0))
	t.equal("a joining player starts with coins and the first daily reward", ana:GetAttribute("Coins"), 150 + firstDay)
	t.equal("and the starting slots", ana:GetAttribute("Slots"), 6)
	local anaPlot = (map :: Instance):FindFirstChild("Plot_1") :: Instance
	local benPlot = (map :: Instance):FindFirstChild("Plot_2") :: Instance
	t.equal("the first player owns plot 1", anaPlot:GetAttribute("OwnerUserId"), 11)
	t.equal("the second owns plot 2", benPlot:GetAttribute("OwnerUserId"), 12)

	-- an egg in the base hatches
	local session = world.load("src/server/Session")
	t.check("a free egg can be placed", session.grantEgg(ana, "Soggy"))
	t.equal("the new egg counts as hatching", ana:GetAttribute("EggsHatching"), 1)
	t.equal("and there are no characters yet", ana:GetAttribute("Characters"), 0)
	t.check("the egg shows on the player's base", anaPlot.Slot_1:FindFirstChild("Item") ~= nil)

	-- hatching and earning
	world.advance(9)
	local heard = false
	for _, entry in world.log do
		if entry.remote == "Sfx" and entry.to == "client" and entry.args[1] == ana and entry.args[2] == "hatch" then
			heard = true
		end
	end
	t.check("a hatch plays the pop", heard)
	t.equal("the hatched egg counts as a character", ana:GetAttribute("Characters"), 1)
	t.equal("and is no longer hatching", ana:GetAttribute("EggsHatching"), 0)
	t.check(
		"the egg hatched into a character shown as its portrait",
		anaPlot.Slot_1.Item:FindFirstChild("Portrait", true) ~= nil
	)
	t.check("a character earns income", (ana:GetAttribute("Income") :: number) >= 1)
	local before = ana:GetAttribute("Coins") :: number
	world.advance(5)
	t.check("coins grow while characters work", (ana:GetAttribute("Coins") :: number) > before)

	-- admin events
	local liveOps = world.load("src/server/LiveOps")
	t.equal("no event means normal luck", liveOps.luck(), 1)
	t.check(
		"a non-admin cannot start events",
		string.find(liveOps.command(ana, "/event luckyhour"), "not an admin") ~= nil
	)
	t.equal("and nothing changed", liveOps.luck(), 1)
	world.studio = true
	liveOps.command(ana, "/event megaluck 60")
	local horn = false
	for _, entry in world.log do
		if entry.remote == "Sfx" and entry.to == "all" and entry.args[1] == "horn" then
			horn = true
		end
	end
	t.check("starting an event sounds the horn for everyone", horn)
	t.equal("an admin event changes luck", liveOps.luck(), 5)
	t.check("and the HUD can see it", string.find(tostring(storage:GetAttribute("ActiveEvents")), "MegaLuck") ~= nil)
	local coinsBefore = ana:GetAttribute("Coins") :: number
	liveOps.command(ana, "/give 1000")
	t.check("/give adds coins", (ana:GetAttribute("Coins") :: number) >= coinsBefore + 1000)
	liveOps.command(ana, "/clear")
	t.equal("/clear ends events", liveOps.luck(), 1)
	liveOps.command(ana, "/event eggrain 30")
	t.equal("Egg Rain speeds up nest regrowth", liveOps.nestRate(), 6)

	-- saving: leave and come back with the same things
	local saved = ben:GetAttribute("Coins") :: number
	world.removePlayer(ben)
	t.equal("a leaving player frees their plot", benPlot:GetAttribute("OwnerUserId"), 0)
	local ben2 = world.addPlayer("Ben", 12)
	world.advance(0.6)
	t.check("a returning player keeps their coins", math.abs((ben2:GetAttribute("Coins") :: number) - saved) < 5)
	t.check("every character id is real", Eggs.character("SoggyToast") ~= nil)

	-- a full server: the 9th player gets no base and is sent away instead of standing around
	for i = 1, 7 do
		world.addPlayer(`Crowd{i}`, 200 + i)
	end
	world.advance(0.6)
	local ninth = world.addPlayer("Overflow", 299)
	world.advance(0.6)
	local planted = 0
	for _, child in (map :: Instance):GetChildren() do
		if string.match(child.Name, "^Plot_") and child:GetAttribute("OwnerUserId") ~= 0 then
			planted += 1
		end
	end
	t.equal("eight players fill the eight bases", planted, 8)
	local overflow = #world.players - 8
	t.check("there are players past eight", overflow >= 1)
	t.equal("nobody is sent away at once", #world.kicked, 0)
	world.advance(7)
	t.equal("every player past eight is sent away a few seconds later", #world.kicked, overflow)
	local kickedOverflow = false
	for _, k in world.kicked do
		if k.player == ninth then
			kickedOverflow = true
		end
		t.check("each is sent away with a message that says why", string.find(k.message, "full", 1, true) ~= nil)
	end
	t.check("including the last one to arrive", kickedOverflow)
end
