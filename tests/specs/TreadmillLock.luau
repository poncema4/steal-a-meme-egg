--!strict
-- The treadmill like the real game: step on and you are locked to it (the game runs for you, no keys to hold) until you jump off,
-- and your speed climbs continuously while you are on it.
local Fake = require("../fake/Roblox")
local Belt = require("../../src/shared/Game/Belt")
local Progression = require("../../src/shared/Game/Progression")

return function(t)
	-- speed is smooth, not stepped
	t.equal("a fresh player is at level 0.0", Progression.levelFloat(0), 0)
	t.check(
		"halfway through level 0 is 0.5",
		math.abs(Progression.levelFloat(Progression.xpForNext(0) / 2) - 0.5) < 1e-9
	)
	t.equal("level 1.0 starts exactly at the XP for level 0", Progression.levelFloat(Progression.xpForNext(0)), 1)
	t.equal(
		"only the safety stop caps it, far beyond any real play",
		Progression.levelFloat(1e300),
		Progression.MAX_LEVEL
	)
	t.equal("negative XP is level 0", Progression.levelFloat(-9), 0)
	local rising = true
	local last = -1
	for xp = 0, 4000, 7 do
		local v = Progression.levelFloat(xp)
		if v < last then
			rising = false
		end
		last = v
	end
	t.check("the smooth level never goes backward as XP grows", rising)
	t.check("the speed number rises between whole levels", Progression.speedStat(0.5) > Progression.speedStat(0))
	t.check("and so does walking speed", Progression.walkSpeed(0.5) > Progression.walkSpeed(0))

	-- the belt keeps a runner in the middle: exactly their speed at the middle, faster if they creep forward, slower if they slip back
	t.equal("at the middle the belt runs exactly as fast as you", Belt.pace(40, 0), 40)
	t.check("creeping forward speeds it up", Belt.pace(40, 2) > 40)
	t.check("slipping back slows it down", Belt.pace(40, -2) < 40)
	t.check("it never runs backward or away", Belt.pace(40, -50) >= 0 and Belt.pace(40, 50) <= 40 * Belt.MAX)
	t.equal("a standing player gets a still belt", Belt.pace(0, 3), 0)

	local world = Fake.world()
	local V3 = world.Vector3
	local ok, err = pcall(world.load, "src/server/main.server")
	t.check("the server starts", ok, tostring(err))
	if not ok then
		return
	end
	local plots = world.load("src/server/Plots")
	local session = world.load("src/server/Session")
	local remotes = world.service("ReplicatedStorage"):FindFirstChild("Remotes") :: Instance
	local leave = remotes:FindFirstChild("LeaveTreadmill") :: RemoteEvent
	t.check("the server offers LeaveTreadmill", leave ~= nil)
	local ana = world.addPlayer("Ana", 71)
	local ben = world.addPlayer("Ben", 72)
	world.spawnCharacter(ana)
	world.spawnCharacter(ben)
	world.advance(0.6)
	world.setLocal(ana)
	local plot = plots.of(ana)
	local belt = plot.treadmill
	local root = world.root(ana)
	local function onBelt(offsetAcross: number)
		root.AssemblyLinearVelocity = V3.new(0, 0, 0)
		root.Position = belt.Position + plot.right * offsetAcross + V3.new(0, 3, 0)
	end

	t.equal("not locked at first", ana:GetAttribute("TreadmillLocked"), nil)
	onBelt(1.5) -- a bit off the middle
	world.advance(0.3)
	t.equal("stepping on locks you", ana:GetAttribute("TreadmillLocked"), true)
	local front = ana:GetAttribute("TreadmillFront") :: Vector3
	t.check("the client is told which way to run", front ~= nil and (front - plot.front).Magnitude < 1e-6)
	local across = (root.Position - belt.Position):Dot(plot.right)
	t.check("you are put on the middle of the belt", math.abs(across) < 0.01, tostring(across))
	t.check("facing the front", root.CFrame.LookVector:Dot(plot.front) > 0.99)

	-- speed climbs continuously with nothing held
	local readings, walks = {}, {}
	for _ = 1, 6 do
		world.advance(0.5)
		table.insert(readings, ana:GetAttribute("SpeedStat") :: number)
		table.insert(walks, world.humanoid(ana).WalkSpeed)
	end
	local smooth, walkSmooth = true, true
	for i = 2, #readings do
		if readings[i] <= readings[i - 1] then
			smooth = false
		end
		if walks[i] <= walks[i - 1] then
			walkSmooth = false
		end
	end
	t.check("the speed number rises every half second", smooth, table.concat(readings, ", "))
	t.check("and so does your real walking speed", walkSmooth)
	t.check("the belt is running at your pace", (belt:GetAttribute("BeltSpeed") :: number) > 10)

	-- jumping off
	leave:FireServer()
	t.equal("jumping off unlocks you", ana:GetAttribute("TreadmillLocked"), false)
	t.check(
		"and throws you up and forward",
		root.AssemblyLinearVelocity.Y > 40 and root.AssemblyLinearVelocity:Dot(plot.front) > 5
	)
	world.advance(0.3)
	t.equal("the belt stops", belt:GetAttribute("BeltSpeed"), 0)
	onBelt(0)
	world.advance(0.5)
	t.equal("you are not caught again straight away", ana:GetAttribute("TreadmillLocked"), false)
	world.advance(1.5)
	t.equal("but you are once the moment has passed", ana:GetAttribute("TreadmillLocked"), true)

	-- a jump you make yourself counts too
	root.AssemblyLinearVelocity = V3.new(0, 25, 0)
	world.advance(0.3)
	t.equal("an upward jump unlocks you", ana:GetAttribute("TreadmillLocked"), false)

	-- stepping off the side, dying, carrying
	world.advance(2)
	onBelt(0)
	world.advance(0.3)
	t.equal("locked again", ana:GetAttribute("TreadmillLocked"), true)
	root.Position = plot.center + V3.new(0, 3, 0)
	world.advance(0.3)
	t.equal("pushed off the belt: unlocked", ana:GetAttribute("TreadmillLocked"), false)
	world.advance(2)
	session.setCarry(ana, "Soggy", "Nest_Meadow_1")
	onBelt(0)
	world.advance(0.3)
	t.equal("carrying an egg: no lock", ana:GetAttribute("TreadmillLocked"), false)
	session.setCarry(ana, nil)
	world.advance(0.3)
	t.equal("with empty hands it locks", ana:GetAttribute("TreadmillLocked"), true)

	-- on the belt: the pace follows where you stand
	local walk = world.humanoid(ana).WalkSpeed
	local centre = belt.Position
	root.AssemblyLinearVelocity = V3.new(0, 0, 0)
	root.Position = centre + plot.front * 3 + V3.new(0, 3, 0)
	world.advance(0.3)
	t.check("ahead of the middle the belt runs faster than you", (belt:GetAttribute("BeltSpeed") :: number) > walk)
	root.AssemblyLinearVelocity = V3.new(0, 0, 0)
	root.Position = centre - plot.front * 3 + V3.new(0, 3, 0)
	world.advance(0.3)
	t.check("behind the middle it runs slower", (belt:GetAttribute("BeltSpeed") :: number) < walk)
	root.AssemblyLinearVelocity = V3.new(0, 0, 0)
	root.Position = centre + V3.new(0, 3, 0)
	world.advance(0.3)
	t.check("in the middle it matches your speed", math.abs((belt:GetAttribute("BeltSpeed") :: number) - walk) < 0.2)
	world.humanoid(ana).Health = 0
	world.advance(0.3)
	t.equal("dying unlocks", ana:GetAttribute("TreadmillLocked"), false)

	-- other people and junk
	world.spawnCharacter(ana)
	root = world.root(ana)
	world.root(ben).Position = belt.Position + V3.new(0, 3, 0)
	world.advance(0.5)
	t.check("nobody else is locked onto your belt", ben:GetAttribute("TreadmillLocked") ~= true)
	world.setLocal(ben)
	leave:FireServer()
	leave:FireServer("x", 1, {})
	t.check("leave from someone who is not on a belt does nothing", ben:GetAttribute("TreadmillLocked") ~= true)
	local before = session.get(ana).speedXp
	world.advance(0.5)
	t.check(
		"a player who is not on a belt trains nothing",
		session.get(ben).speedXp == 0 and session.get(ana).speedXp >= before
	)

	-- the client half: it runs for you, takes the keys away, and lets you off
	world.spawnCharacter(ana)
	root = world.root(ana)
	world.setLocal(ana)
	world.advance(2)
	local run = world.load("src/client/TreadmillRun")
	run.start(ana)
	local hud = world.load("src/client/Hud")
	hud.start(ana, {})
	world.render(1 / 60)
	t.check(
		"nothing is taken over while you are free",
		world.actions["TreadmillSink"] == nil and world.humanoid(ana).LastMove == nil
	)
	root.AssemblyLinearVelocity = V3.new(0, 0, 0)
	root.Position = belt.Position + V3.new(0, 3, 0)
	world.advance(0.4)
	t.equal("locked again", ana:GetAttribute("TreadmillLocked"), true)
	world.render(1 / 60)
	local walking = world.humanoid(ana).LastMove
	t.check("the client runs for you, toward the front", walking ~= nil and (walking - plot.front).Magnitude < 1e-6)
	t.check("without relying on the camera", world.humanoid(ana).LastMoveRelative == false)
	t.check("movement keys are taken away", world.actions["TreadmillSink"] ~= nil)
	t.check("but jump leaves", world.actions["TreadmillLeave"] ~= nil)
	local hudGui = ana.PlayerGui:FindFirstChild("Hud") :: Instance
	world.advance(0.6)
	t.check(
		"there is no Jump off button: jumping is the way off (Marco)",
		hudGui:FindFirstChild("LeaveButton", true) == nil
	)
	world.actions["TreadmillLeave"]("TreadmillLeave", world.enum.UserInputState.Begin)
	t.equal("pressing jump takes you off", ana:GetAttribute("TreadmillLocked"), false)
	world.render(1 / 60)
	t.check("the keys come back", world.actions["TreadmillSink"] == nil and world.actions["TreadmillLeave"] == nil)
end
