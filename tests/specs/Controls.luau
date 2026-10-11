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
		"and always matches your real run speed",
		Progression.speedStat(7) == math.floor(Progression.walkSpeed(7) * 100)
	)
	t.equal("it stops at the cap", Progression.speedStat(999), Progression.speedStat(Progression.MAX_LEVEL))
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
	t.check("the egg is back in its nest", entry.prompt.Enabled and entry.nest.tier ~= nil)
	t.check("she stays where she was", (root.Position - here).Magnitude < 0.01)
	t.equal("nobody is chasing her any more", entry.thief, nil)
	drop:FireServer()
	t.equal("a second Drop is harmless", ana:GetAttribute("Carrying"), "")

	-- Drop only touches the sender's own egg
	world.setLocal(ben)
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
