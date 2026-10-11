--!strict
-- The two buttons the HUD adds: Drop (let go of the egg you are carrying) and Slow Mode (walk at the normal speed while
-- building). The client only asks; the server checks.
local Fake = require("../fake/Roblox")
local Economy = require("../../src/shared/Game/Economy")
local Progression = require("../../src/shared/Game/Progression")

return function(t)
	-- the rules on their own
	t.equal("the speed shows every digit", Economy.full(1634), "1,634")
	t.equal("a small number has no comma", Economy.full(999), "999")
	t.equal("a big one has several", Economy.full(1234567), "1,234,567")
	t.equal("an exact thousand", Economy.full(1000), "1,000")
	t.equal("the speed number starts at 1600 (16 studs a second)", Progression.speedStat(0), 1600)
	t.check(
		"every level multiplies it by 1.22",
		math.abs(Progression.speedStat(7) / Progression.speedStat(6) - 1.22) < 0.01
	)
	t.check("it has no ceiling: billions, trillions and quadrillions are reachable", Progression.speedStat(170) > 1e15)
	t.equal("a number of billions reads as B", Economy.speed(8.89e9), "8.89B")
	t.equal("and trillions as T", Economy.speed(4.2e12), "4.2T")
	t.equal("a negative level is the start", Progression.speedStat(-4), 1600)
	t.equal("slow mode caps a fast walker", Progression.slowed(30, true), Progression.SLOW_SPEED)
	t.equal("and does not speed up a slow one", Progression.slowed(10, true), 10)
	t.equal("off changes nothing", Progression.slowed(30, false), 30)

	-- on the real server
	local world = Fake.world()
	local V3 = world.Vector3
	local ok, err = pcall(world.load, "src/server/main.server")
	t.check("the server starts", ok, tostring(err))
	if not ok then
		return
	end
	local session = world.load("src/server/Session")
	local wilds = world.load("src/server/Wilds")
	local remotes = world.service("ReplicatedStorage"):FindFirstChild("Remotes") :: Instance
	local ana = world.addPlayer("Ana", 71)
	local ben = world.addPlayer("Ben", 72)
	world.spawnCharacter(ana)
	world.spawnCharacter(ben)
	world.advance(0.6)
	world.setLocal(ana)
	local root = world.root(ana)
	local drop, slow = remotes:FindFirstChild("Drop") :: RemoteEvent, remotes:FindFirstChild("SlowMode") :: RemoteEvent
	t.check("the server offers Drop and SlowMode", drop ~= nil and slow ~= nil)

	-- Drop
	drop:FireServer()
	t.equal("dropping with nothing in hand does nothing", ana:GetAttribute("Carrying"), "")
	local entry = wilds.entries()[1]
	root.Position = V3.new(entry.egg.Position.X - 5, 3, entry.egg.Position.Z)
	entry.prompt.Triggered:Fire(ana)
	t.check("Ana carries the egg", ana:GetAttribute("Carrying") ~= "")
	t.check("and the nest looks empty", not entry.prompt.Enabled)
	local here = root.Position
	drop:FireServer()
	t.equal("Drop empties her hands", ana:GetAttribute("Carrying"), "")
	-- a drop on purpose leaves the egg exactly where she let go; only being caught sends it back to its nest
	local lying = entry.dropped
	t.check("the egg lies on the ground", lying ~= nil and not entry.prompt.Enabled)
	t.check(
		"exactly where she dropped it",
		lying ~= nil
			and math.abs(lying.part.Position.X - here.X) < 0.01
			and math.abs(lying.part.Position.Z - here.Z) < 0.01
	)
	t.check("she stays where she was", (root.Position - here).Magnitude < 0.01)
	t.equal("nobody is chasing her any more", entry.thief, nil)
	t.check(
		"the nest does not grow a new egg while one lies on the ground",
		(function()
			world.advance(40)
			return entry.dropped ~= nil and entry.nest.tier == nil
		end)()
	)
	-- anyone can pick it up again, and the boss chases whoever does
	lying = entry.dropped :: any
	local prompt = lying.part:FindFirstChildOfClass("ProximityPrompt") :: ProximityPrompt
	prompt.Triggered:Fire(ana)
	t.check("she picks it up again", ana:GetAttribute("Carrying") ~= "" and entry.dropped == nil and entry.thief == ana)
	drop:FireServer()
	t.check("and drops it again", entry.dropped ~= nil)
	world.advance(95)
	t.check("a dropped egg nobody picks up goes back to its nest", entry.dropped == nil and entry.nest.tier ~= nil)
	t.check("and the nest shows it", entry.prompt.Enabled)
	drop:FireServer()
	t.equal("a second Drop is harmless", ana:GetAttribute("Carrying"), "")

	-- Drop only touches the sender's own egg
	world.setLocal(ben)
	root.Position = V3.new(entry.egg.Position.X - 5, 3, entry.egg.Position.Z)
	entry.prompt.Triggered:Fire(ana)
	drop:FireServer()
	t.check("Ben cannot make Ana drop her egg", ana:GetAttribute("Carrying") ~= "")
	world.setLocal(ana)
	drop:FireServer()

	-- Slow Mode
	session.addSpeedXp(ana, 5000)
	world.advance(0.6)
	t.check("a trained player walks faster than normal", world.humanoid(ana).WalkSpeed > Progression.SLOW_SPEED)
	slow:FireServer(true)
	t.equal("Slow Mode brings her to the normal speed", world.humanoid(ana).WalkSpeed, Progression.SLOW_SPEED)
	t.equal("and the HUD can see it", ana:GetAttribute("SlowMode"), true)
	slow:FireServer(false)
	t.check("turning it off gives the speed back", world.humanoid(ana).WalkSpeed > Progression.SLOW_SPEED)
	slow:FireServer(true)
	for _, junk in { "yes", 1, 0, {}, "nan", 0 / 0 } do
		slow:FireServer(junk)
	end
	t.equal("junk from the client changes nothing", ana:GetAttribute("SlowMode"), true)
	-- the Eggs panel's buttons, the base view and the Index
	local action = remotes:FindFirstChild("BaseAction") :: RemoteEvent
	t.check("the server offers BaseAction", action ~= nil)
	t.equal("the base view starts empty", ana:GetAttribute("BaseItems"), "")
	t.equal("and so does the Index", ana:GetAttribute("Index"), "")
	session.get(ana).coins = 1e9
	session.grantEgg(ana, "Soggy")
	t.check(
		"an egg shows in the base view",
		string.find(tostring(ana:GetAttribute("BaseItems")), "1,e,Soggy", 1, true) ~= nil
	)
	local coins = ana:GetAttribute("Coins") :: number
	for _, junk in
		{
			{ "skip", 0 },
			{ "skip", 1.5 },
			{ "skip", math.huge },
			{ "skip", "1" },
			{ "skip", 99 },
			{ "explode", 1 },
			{ 5, 1 },
			{ "skip", 0 / 0 },
		}
	do
		action:FireServer(junk[1], junk[2])
	end
	action:FireServer()
	t.equal("junk requests change nothing", ana:GetAttribute("Characters"), 0)
	t.equal("and cost nothing", ana:GetAttribute("Coins"), coins)
	action:FireServer("skip", 1)
	t.equal("there is no coin skip: the egg is still hatching", ana:GetAttribute("Characters"), 0)
	t.equal("and it cost nothing", ana:GetAttribute("Coins"), coins)
	world.advance(10)
	t.equal("it hatches on its own with time", ana:GetAttribute("Characters"), 1)
	t.check("and in the Index", #tostring(ana:GetAttribute("Index")) > 0)
	t.equal(
		"the speed stat is published",
		ana:GetAttribute("SpeedStat"),
		Progression.speedStat(Progression.levelFloat(session.get(ana).speedXp))
	)
end
