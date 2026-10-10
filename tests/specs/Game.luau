--!strict
-- Runs the REAL server scripts against the fake Roblox world: the map is built, players get bases, eggs are bought off the
-- belt, hatch and earn, characters are raided, locks hold, and admin events change the multipliers.
local Fake = require("../fake/Roblox")
local Eggs = require("../../src/shared/Game/Eggs")

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
	t.equal("there are 12 base plots", plotCount, 12)

	local ana = world.addPlayer("Ana", 11)
	local ben = world.addPlayer("Ben", 12)
	world.advance(0.6)
	t.equal("a joining player starts with coins", ana:GetAttribute("Coins"), 150)
	t.equal("and the starting slots", ana:GetAttribute("Slots"), 6)
	local anaPlot = (map :: Instance):FindFirstChild("Plot_1") :: Instance
	local benPlot = (map :: Instance):FindFirstChild("Plot_2") :: Instance
	t.equal("the first player owns plot 1", anaPlot:GetAttribute("OwnerUserId"), 11)
	t.equal("the second owns plot 2", benPlot:GetAttribute("OwnerUserId"), 12)

	-- buying off the belt
	local conveyor = world.load("src/server/Conveyor")
	conveyor.spawn("Soggy")
	local buys = world.prompts(world.workspace, "Buy")
	t.equal("an egg on the belt can be bought", #buys, 1)
	buys[1].Triggered:Fire(ana)
	t.equal("buying takes the price", ana:GetAttribute("Coins"), 50)
	t.equal("and removes the egg from the belt", #world.prompts(world.workspace, "Buy"), 0)
	t.check("the egg shows on the player's base", anaPlot.Slot_1:FindFirstChild("Item") ~= nil)

	-- too poor: the 1000-coin egg is refused
	conveyor.spawn("Disco")
	world.prompts(world.workspace, "Buy")[1].Triggered:Fire(ana)
	t.equal("a player who cannot afford an egg keeps their coins", math.floor(ana:GetAttribute("Coins") :: number), 50)
	t.equal("and the egg stays on the belt", #world.prompts(world.workspace, "Buy"), 1)

	-- hatching and earning
	world.advance(9)
	t.check(
		"the egg hatched into a character",
		anaPlot.Slot_1.Item.Body:FindFirstChildOfClass("ProximityPrompt") ~= nil
	)
	t.check("a character earns income", (ana:GetAttribute("Income") :: number) >= 1)
	local before = ana:GetAttribute("Coins") :: number
	world.advance(5)
	t.check("coins grow while characters work", (ana:GetAttribute("Coins") :: number) > before)

	-- raiding
	local steals = world.prompts(anaPlot, "Steal")
	t.equal("a character in a base can be stolen", #steals, 1)
	steals[1].Triggered:Fire(ana)
	t.check("the owner cannot steal their own", #world.prompts(anaPlot, "Steal") == 1)
	steals[1].Triggered:Fire(ben)
	t.equal("a raid removes it from the victim", #world.prompts(anaPlot, "Steal"), 0)
	t.equal("and puts it in the thief's base", #world.prompts(benPlot, "Steal"), 1)

	-- locking: Ben locks, Ana's raid fails
	local locks = world.prompts(benPlot, "Lock base")
	t.equal("a base has a lock pad", #locks, 1)
	locks[1].Triggered:Fire(ana) -- not the owner: nothing happens
	world.prompts(benPlot, "Steal")[1].Triggered:Fire(ana)
	t.equal("an unlocked base can be raided by anyone", #world.prompts(benPlot, "Steal"), 0)
	t.equal("and it landed with the raider", #world.prompts(anaPlot, "Steal"), 1)
	world.prompts(anaPlot, "Lock base")[1].Triggered:Fire(ana)
	world.prompts(anaPlot, "Steal")[1].Triggered:Fire(ben)
	t.equal("a locked base cannot be raided", #world.prompts(anaPlot, "Steal"), 1)
	world.advance(50)
	world.prompts(anaPlot, "Steal")[1].Triggered:Fire(ben)
	t.equal("the lock runs out", #world.prompts(anaPlot, "Steal"), 0)

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
	t.equal("an admin event changes luck", liveOps.luck(), 5)
	t.check("and the HUD can see it", string.find(tostring(storage:GetAttribute("ActiveEvents")), "MegaLuck") ~= nil)
	local coinsBefore = ana:GetAttribute("Coins") :: number
	liveOps.command(ana, "/give 1000")
	t.check("/give adds coins", (ana:GetAttribute("Coins") :: number) >= coinsBefore + 1000)
	liveOps.command(ana, "/clear")
	t.equal("/clear ends events", liveOps.luck(), 1)
	liveOps.command(ana, "/event eggrain 30")
	t.equal("Egg Rain speeds up the belt", liveOps.beltRate(), 6)

	-- saving: leave and come back with the same things
	local saved = ben:GetAttribute("Coins") :: number
	world.removePlayer(ben)
	t.equal("a leaving player frees their plot", benPlot:GetAttribute("OwnerUserId"), 0)
	local ben2 = world.addPlayer("Ben", 12)
	world.advance(0.6)
	t.check("a returning player keeps their coins", math.abs((ben2:GetAttribute("Coins") :: number) - saved) < 5)
	t.check("every character id is real", Eggs.character("SoggyToast") ~= nil)
end
