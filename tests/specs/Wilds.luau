--!strict
-- Runs the real server scripts: stealing an egg from a guardian, being chased, caught or escaping, delivering it home, the
-- gates that keep you out of terrains you have not unlocked, the treadmill and the buy pads.
local Fake = require("../fake/Roblox")
local Layout = require("../../src/shared/Game/Layout")
local Progression = require("../../src/shared/Game/Progression")
local Zones = require("../../src/shared/Game/Zones")

return function(t)
	local world = Fake.world()
	local V3 = world.Vector3
	local ok, err = pcall(world.load, "src/server/main.server")
	t.check("the server starts with the Wilds", ok, tostring(err))
	if not ok then
		return
	end
	local wilds = world.load("src/server/Wilds")
	local session = world.load("src/server/Session")
	local plotsMod = world.load("src/server/Plots")
	local entries = wilds.entries()
	local expected = 0
	for _, zone in Zones.List do
		expected += zone.nests
	end
	t.equal("every terrain has its nests and guardians", #entries, expected)
	t.equal("each terrain has 5 nests", Zones.List[1].nests, 5)
	local folder = world.workspace:FindFirstChild("Wilds") :: Instance
	t.check("the Wilds folder is built", folder ~= nil)
	local signs, gates = 0, 0
	for _, child in folder:GetChildren() do
		if string.match(child.Name, "^Sign_") then
			signs += 1
			local text = ""
			for _, d in child:GetDescendants() do
				if d:IsA("TextLabel") then
					text ..= (d :: TextLabel).Text .. "|"
				end
			end
			if string.find(text, "Recommended|Speed ", 1, true) == nil then
				signs -= 1000
			end
		elseif string.match(child.Name, "^Gate_") then
			gates += 1
		end
	end
	t.equal("every terrain has one small sign saying its recommended speed", signs, #Zones.List)
	for _, zone in Zones.List do
		local sign = folder:FindFirstChild(`Sign_{zone.id}`) :: Part
		local boss = Layout.bossSpot(zone)
		local away = math.sqrt((sign.Position.X - boss.x) ^ 2 + (sign.Position.Z - boss.z) ^ 2)
		t.check(`{zone.id}'s sign stands by its boss`, away < Layout.BOSS_CLEAR)
		t.check(`{zone.id}'s sign is small`, sign.Size.Y <= 3 and sign.Size.Z <= 7)
		t.check(`{zone.id}'s sign is not in anyone's way`, not sign.CanCollide)
	end
	t.equal("and there are no gates or red walls", gates, 0)
	local bosses = wilds.bosses()
	t.equal("there is exactly one boss per terrain", #bosses, #Zones.List)
	local shared = true
	for _, e in entries do
		if e.guardian ~= e.boss.guardian then
			shared = false
		end
	end
	t.check("every nest of a terrain shares its boss", shared)
	t.check("the boss is a meme, never a goose", string.find(string.lower(bosses[1].name), "goose", 1, true) == nil)

	local function feetY(entry: any): number
		local body = entry.boss.model:FindFirstChild("Body")
		return body.Position.Y - body.Size.Y / 2
	end
	local grounded = true
	for _, e in entries do
		if math.abs(feetY(e)) > 0.01 then
			grounded = false
		end
	end
	t.check("every guardian stands on the ground", grounded)

	-- the sound effects the server asks the client to play (by name, never by asset id)
	local function heardNames(player: any): { string }
		local names = {}
		for _, entry in world.log do
			if entry.remote == "Sfx" and entry.to == "client" and entry.args[1] == player then
				table.insert(names, entry.args[2])
			end
		end
		return names
	end
	local ana = world.addPlayer("Ana", 21)
	world.spawnCharacter(ana)
	world.advance(0.6)
	local plot = plotsMod.of(ana)
	t.check("Ana has a plot", plot ~= nil)
	local root = world.root(ana)
	local entry = entries[1]
	t.equal("the first nest is in the Meadow", entry.zone.id, "Meadow")
	t.check("its egg can be stolen", entry.prompt.Enabled)

	-- 1) stealing, and the chase that follows
	root.Position = V3.new(entry.egg.Position.X - 5, 3, entry.egg.Position.Z)
	entry.prompt.Triggered:Fire(ana)
	local carried = ana:GetAttribute("Carrying") :: string
	t.check("stealing makes you carry the egg", carried ~= "" and carried ~= nil)
	t.check("the nest looks empty", not entry.prompt.Enabled)
	t.equal("the guardian wakes up", entry.guardian.state, "Chase")
	t.check("a carrier is slower than normal", world.humanoid(ana).WalkSpeed < Progression.BASE_SPEED)
	local tierAtSteal = carried
	t.check(
		"stealing plays the steal blip and the guardian roar",
		table.find(heardNames(ana), "steal") ~= nil and table.find(heardNames(ana), "roar") ~= nil
	)

	-- stealing twice is not allowed
	local second = entries[2]
	second.prompt.Triggered:Fire(ana)
	t.check("a second egg cannot be taken while carrying", second.prompt.Enabled)

	-- 2) standing still gets you caught: the egg goes back and you go home
	world.advance(10) -- the boss runs over from the middle of the terrain
	t.equal("the guardian caught the thief", ana:GetAttribute("Carrying"), "")
	t.check("being caught plays the sad sound", table.find(heardNames(ana), "caught") ~= nil)
	t.check("the egg is back in the nest", entry.prompt.Enabled and entry.nest.tier == tierAtSteal)
	t.check("a guardian is still on the ground after chasing", math.abs(feetY(entry)) < 0.01, tostring(feetY(entry)))
	-- after the guardian is back at its nest its model must still be a real position (no NaN from looking at itself)
	world.advance(8)
	local look = entry.boss.model:GetPivot().LookVector
	t.check(
		"and still faces somewhere real",
		look.X == look.X and look.Y == look.Y and look.Z == look.Z,
		tostring(look)
	)
	local bodyAfter = entry.boss.model:FindFirstChild("Body") :: Part
	local pos = bodyAfter.Position
	t.check(
		"a guardian back at its nest still has a valid position",
		pos.X == pos.X and pos.Y == pos.Y and pos.Z == pos.Z,
		tostring(pos)
	)
	t.check(
		"and is standing at its nest",
		math.abs(pos.X - entry.guardian.homeX) < 0.1 and math.abs(pos.Z - entry.guardian.homeZ) < 0.1,
		tostring(pos)
	)
	t.check("the thief was flung back toward the Safe Zone", root.AssemblyLinearVelocity.X < 0)
	t.equal("speed is normal again", world.humanoid(ana).WalkSpeed, Progression.BASE_SPEED)
	t.equal("the guardian walks home", entry.guardian.state == "Return" or entry.guardian.state == "Idle", true)

	-- 3) escaping: run away faster than the guardian, then get home
	world.advance(10)
	root.Position = V3.new(entry.egg.Position.X - 5, 3, entry.egg.Position.Z)
	entry.prompt.Triggered:Fire(ana)
	t.check("the nest egg can be stolen again after a catch", ana:GetAttribute("Carrying") ~= "")
	local speed = world.humanoid(ana).WalkSpeed
	for _ = 1, 70 do
		root.Position = root.Position - V3.new(speed * 0.1, 0, 0)
		world.advance(0.1)
	end
	t.equal("a runner faster than the guardian keeps the egg", ana:GetAttribute("Carrying") ~= "", true)
	root.Position = V3.new(entry.egg.Position.X, 3, 150) -- out by the wall, far from the boss
	world.advance(8)
	t.check("and the guardian gave up", entry.guardian.state ~= "Chase")
	root.Position = V3.new(plot.center.X, 3, plot.center.Z)
	world.advance(0.6)
	world.load("src/server/Home").placeEgg(ana) -- Place egg: you choose the spot
	world.advance(0.2)
	t.equal("running home and placing it delivers the egg", ana:GetAttribute("Carrying"), "")
	t.check("delivering plays the fanfare", table.find(heardNames(ana), "deliver") ~= nil)
	t.check("it is hatching in the base", (session.get(ana).base.slots[1] or {}).kind == "egg")
	local at = session.get(ana).base.slots[1].at
	t.check(
		"and it was put down where she stood: the middle of the pen",
		at ~= nil and math.abs(at.x) < 1 and math.abs(at.z) < 1
	)
	t.check("delivering pays Meme Points", (ana:GetAttribute("MemePoints") :: number) >= 1)
	local mp = ana:GetAttribute("MemePoints") :: number
	t.equal("the delivered egg's tier is kept", session.get(ana).base.slots[1].tier, tierAtSteal)
	t.check(
		"the nest regrows an egg",
		(function()
			world.advance(30)
			return entry.prompt.Enabled
		end)()
	)

	-- 3b) a nest does not grow a new egg while the thief is still out with the old one (or a second thief would overwrite the
	-- first one's record and the first guardian could never catch them or recover the egg)
	root.Position = V3.new(entry.egg.Position.X - 7, 3, entry.egg.Position.Z)
	entry.prompt.Triggered:Fire(ana)
	t.check("a thief is out with the egg", ana:GetAttribute("Carrying") ~= "")
	root.Position = V3.new(Zones.List[1].startX - 5, 3, 150) -- in the Safe Zone out by the wall: out of the boss's reach, not home yet
	world.advance(40)
	t.check("the thief still has the egg after 40 seconds", ana:GetAttribute("Carrying") ~= "")
	t.check("so the nest has not grown a new one", not entry.prompt.Enabled)
	t.equal("and still names them as the thief", entry.thief, ana)
	root.Position = V3.new(plot.center.X, 3, plot.center.Z)
	world.advance(0.6)
	world.load("src/server/Home").placeEgg(ana)
	world.advance(0.2)
	t.equal("once they deliver it", ana:GetAttribute("Carrying"), "")
	world.advance(30)
	t.check("the nest grows a new egg a little later", entry.prompt.Enabled)

	-- 4) dying while carrying puts the egg back
	local third = entries[3]
	root.Position = V3.new(third.egg.Position.X - 5, 3, third.egg.Position.Z)
	third.prompt.Triggered:Fire(ana)
	t.check("a third egg is carried", ana:GetAttribute("Carrying") ~= "")
	world.humanoid(ana).Health = 0
	world.advance(0.5)
	t.equal("dying drops the egg", ana:GetAttribute("Carrying"), "")
	t.check("and it returns to its nest", third.prompt.Enabled)
	world.spawnCharacter(ana)
	root = world.root(ana)

	-- 5) a full base cannot take another egg
	local full = session.get(ana)
	for n = 1, full.base.size do
		if not full.base.slots[n] then
			full.base.slots[n] = { kind = "char", id = "SoggyToast", mutation = "Normal" }
		end
	end
	local firstBefore = full.base.slots[1]
	mp = ana:GetAttribute("MemePoints") :: number
	local coinsBeforeFull = ana:GetAttribute("Coins") :: number
	local fourth = entries[4]
	root.Position = V3.new(fourth.egg.Position.X - 5, 3, fourth.egg.Position.Z)
	fourth.prompt.Triggered:Fire(ana)
	root.Position = V3.new(plot.center.X, 3, plot.center.Z)
	world.advance(0.6)
	world.load("src/server/Home").placeEgg(ana)
	world.advance(0.2)
	t.equal("a full base never traps you carrying an egg", ana:GetAttribute("Carrying"), "")
	t.check("the points still count", (ana:GetAttribute("MemePoints") :: number) > mp)
	t.check("and the egg is sold for coins instead", (ana:GetAttribute("Coins") :: number) > coinsBeforeFull)
	local firstNow = full.base.slots[1]
	t.check("nothing was added to the full base", firstNow == firstBefore)

	-- 6) no gates: anyone may walk anywhere, the signs only recommend a speed
	local duneX = Zones.List[2].startX
	root.Position = V3.new(duneX + 60, 3, 0)
	world.advance(0.7)
	t.check("a brand new player is NOT pushed out of the Dune", root.Position.X >= duneX + 60)
	t.equal("and the HUD zone shows where they are", ana:GetAttribute("Zone"), "Dune Desert")
	local dune = entries[7]
	t.equal("the seventh nest is the Dune's first", dune.zone.id, "Dune")
	local lowbie = world.addPlayer("Ben", 22)
	world.spawnCharacter(lowbie)
	world.advance(0.6)
	world.root(lowbie).Position = V3.new(dune.egg.Position.X - 5, 3, dune.egg.Position.Z)
	dune.prompt.Triggered:Fire(lowbie)
	t.check("a slow player can steal there too (the boss will just catch them)", lowbie:GetAttribute("Carrying") ~= "")

	-- 7) the treadmill: you have to RUN on it, and upgrading it trains you faster
	local anaRoot = world.root(ana)
	anaRoot.Position = V3.new(plot.treadmill.Position.X, 3, plot.treadmill.Position.Z)
	world.advance(30)
	t.equal("stepping on the belt locks you on it", ana:GetAttribute("TreadmillLocked"), true)
	t.check("and trains speed with no keys held", (ana:GetAttribute("SpeedLevel") :: number) >= 1)
	t.check("which makes you walk faster", world.humanoid(ana).WalkSpeed > Progression.BASE_SPEED)
	local belt = plot.treadmill.AssemblyLinearVelocity
	t.check("the belt carries you backward, away from the plaza", belt.X * plot.front.X + belt.Z * plot.front.Z < -1)
	anaRoot.Position = V3.new(plot.center.X, 3, plot.center.Z)
	world.advance(0.6)
	local still = plot.treadmill.AssemblyLinearVelocity
	t.equal("and stops when you step off", still.Magnitude, 0)
	t.equal("a new player starts on treadmill level 0", ana:GetAttribute("TreadmillLevel"), 0)
	t.equal("and there is no Buy speed prompt any more", #world.prompts(plot.model, "Buy speed"), 0)
	local upgrade = world.prompts(plot.model, "Upgrade treadmill")[1]
	t.check(
		"the treadmill shows its next price",
		string.find(upgrade.ObjectText, "100", 1, true) ~= nil,
		upgrade.ObjectText
	)
	session.get(ana).coins = 50
	upgrade.Triggered:Fire(ana)
	t.equal("too poor to upgrade", ana:GetAttribute("TreadmillLevel"), 0)
	session.add(ana, 100000)
	local before = ana:GetAttribute("Coins") :: number
	upgrade.Triggered:Fire(ana)
	t.equal("upgrading raises the treadmill level", ana:GetAttribute("TreadmillLevel"), 1)
	t.equal(
		"and takes the price",
		math.floor(before - (ana:GetAttribute("Coins") :: number)),
		Progression.treadmillCost(0)
	)
	local other = world.addPlayer("Dee", 24)
	world.advance(0.6)
	upgrade.Triggered:Fire(other)
	t.equal("nobody else can upgrade your treadmill", ana:GetAttribute("TreadmillLevel"), 1)
	-- the same minute of running gives more speed XP on the upgraded treadmill
	session.get(ana).speedXp = 0
	anaRoot.Position = V3.new(plot.treadmill.Position.X, 3, plot.treadmill.Position.Z)
	world.advance(10)
	local xpAfter = session.get(ana).speedXp
	t.check("level 1 trains faster than level 0", xpAfter > 10 * Progression.trainRate(0, 1) * 1.3, tostring(xpAfter))
	world.humanoid(ana).MoveDirection = V3.new(0, 0, 0)

	-- 8) slots
	anaRoot.Position = V3.new(plot.center.X, 3, plot.center.Z)
	local slots = ana:GetAttribute("Slots") :: number
	world.prompts(plot.model, "Buy slot")[1].Triggered:Fire(ana)
	t.equal("buying a slot adds one", ana:GetAttribute("Slots"), slots + 1)
	local broke = world.addPlayer("Cy", 23)
	world.advance(0.6)
	local brokePlot = plotsMod.of(broke)
	world.prompts(brokePlot.model, "Buy slot")[1].Triggered:Fire(broke)
	t.equal("not enough coins means no slot", broke:GetAttribute("Slots"), 6)
	world.prompts(plot.model, "Buy slot")[1].Triggered:Fire(broke)
	t.equal("and you cannot buy on someone else's pad", broke:GetAttribute("Slots"), 6)
end
