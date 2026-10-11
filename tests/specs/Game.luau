--!strict
-- Runs the REAL server scripts against the fake Roblox world: the map is built, players get bases, eggs are granted and
-- hatch and earn, and admin events change the multipliers.
local Config = require("../../src/shared/Config")
local Fake = require("../fake/Roblox")
local Progression = require("../../src/shared/Game/Progression")
local Daily = require("../../src/shared/Game/Daily")
local Eggs = require("../../src/shared/Game/Eggs")
local Zones = require("../../src/shared/Game/Zones")

return function(t)
	local world = Fake.world()
	world.workspace:SetAttribute("ShowAllPlots", true) -- these checks look at every base, not just the occupied ones
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
	-- every terrain's walls wear its own theme (Marco: "the side of the walls should fit the theme of each world")
	local themed = 0
	for _, zone in Zones.List do
		local theme = Zones.WallTheme[zone.id]
		local mid = zone.startX + zone.length / 2
		for _, w in (map :: Instance):GetChildren() do
			if w.Name == "Wall" and math.abs((w :: Part).Position.X - mid) < 10 then
				local c = (w :: Part).Color
				local want = theme and theme.wall
				if
					want
					and (
						math.abs(c.R * 255 - want[1]) < 25
						and math.abs(c.G * 255 - want[2]) < 25
						and math.abs(c.B * 255 - want[3]) < 25
					)
				then
					themed += 1
					break
				end
			end
		end
	end
	t.equal("each of the 15 terrains has walls in its own theme", themed, #Zones.List)
	local line = (map :: Instance):FindFirstChild("RedLine") :: Part
	t.check("a red line marks the edge of the Safe Zone", line ~= nil)
	-- no big boards over the red line (Marco: only a small recommended-speed sign by each boss)
	t.check("no gateway board stands over the red line", (map :: Instance):FindFirstChild("GateSign") == nil)
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
	-- the first player gets the middle of the arc (base 4), the second the one beside it (base 5)
	local anaPlot = (map :: Instance):FindFirstChild("Plot_4") :: Instance
	local benPlot = (map :: Instance):FindFirstChild("Plot_5") :: Instance
	t.equal("the first player owns base 4, the middle of the arc", anaPlot:GetAttribute("OwnerUserId"), 11)
	t.equal("the second owns base 5, next to it", benPlot:GetAttribute("OwnerUserId"), 12)

	-- an egg in the base hatches
	local session = world.load("src/server/Session")
	t.check("a free egg can be placed", session.grantEgg(ana, "Soggy"))
	t.equal("the new egg counts as hatching", ana:GetAttribute("EggsHatching"), 1)
	t.equal("and there are no characters yet", ana:GetAttribute("Characters"), 0)
	t.check("the egg shows on the player's base", anaPlot.Slot_1:FindFirstChild("Item") ~= nil)

	-- hatching and earning: the egg finishes, then its owner presses Hatch
	world.advance(9)
	for slot = 1, 12 do -- the owner presses Hatch on every finished egg
		world.load("src/server/Session").hatchSlot(ana, slot)
	end
	world.advance(0.2)
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

	-- /resetme: the owner starts over; it touches only whoever typed it
	local sessionMod = world.load("src/server/Session")
	sessionMod.addSpeedXp(ana, 5000)
	sessionMod.addSpeedXp(ben, 5000)
	sessionMod.get(ana).treadmill = 4
	sessionMod.get(ana).rebirths = 2
	world.studio = false
	t.check("a non-admin cannot reset", string.find(liveOps.command(ana, "/resetme"), "not an admin") ~= nil)
	t.check(
		"and keeps their progress",
		(ana:GetAttribute("SpeedLevel") :: number) >= 1 and sessionMod.get(ana).rebirths == 2
	)
	world.studio = true
	liveOps.command(ana, "/resetme")
	t.equal("an admin's reset sends them back to speed level 0", ana:GetAttribute("SpeedLevel"), 0)
	t.equal("and treadmill 0, no rebirths", sessionMod.get(ana).treadmill + sessionMod.get(ana).rebirths, 0)
	t.equal("and the starting coins", ana:GetAttribute("Coins"), Config.Economy.StartCoins)
	t.check("nobody else is touched", (ben:GetAttribute("SpeedLevel") :: number) >= 1)
	-- /maxme: the owner jumps to the top to test the late game; again only themselves
	local benLevel = ben:GetAttribute("SpeedLevel") :: number
	liveOps.command(ana, "/maxme")
	t.equal("/maxme puts the treadmill at its top level", sessionMod.get(ana).treadmill, Progression.MAX_TREADMILL)
	t.check("and speed past the deepest world", (ana:GetAttribute("SpeedLevel") :: number) >= sessionMod.MAX_ME_LEVEL)
	t.check("and plenty of coins", (ana:GetAttribute("Coins") :: number) >= sessionMod.MAX_ME_COINS)
	t.equal("nobody else is maxed", ben:GetAttribute("SpeedLevel"), benLevel)
	world.studio = false
	t.check("a non-admin cannot max", string.find(liveOps.command(ben, "/maxme"), "not an admin") ~= nil)
	world.studio = true
	-- the commands are not registered on the server, so other players never see them in the chat suggestions
	local chat = world.service("TextChatService")
	local serverCommands = 0
	for _, c in chat:GetChildren() do
		if c:IsA("TextChatCommand") then
			serverCommands += 1
		end
	end
	t.equal("no admin command is visible to everyone", serverCommands, 0)
	t.check(
		"admins send them through their own remote",
		world.service("ReplicatedStorage"):FindFirstChild("Remotes"):FindFirstChild("AdminCommand") ~= nil
	)

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
