--!strict
-- Runs the real server scripts: stealing an egg from a guardian, being chased, caught or escaping, delivering it home, the
-- gates that keep you out of terrains you have not unlocked, the treadmill and the buy pads.
local Fake = require("../fake/Roblox")
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
	t.equal("every terrain has its nests and guardians", #entries, #Zones.List * 6)
	local folder = world.workspace:FindFirstChild("Wilds") :: Instance
	t.check("the Wilds folder is built", folder ~= nil)
	local gates = 0
	for _, child in folder:GetChildren() do
		if string.match(child.Name, "^Gate_") then
			gates += 1
		end
	end
	t.equal("every terrain has a gate", gates, #Zones.List)

	local function feetY(entry: any): number
		local body = entry.model:FindFirstChild("Body")
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
	root.Position = V3.new(entry.guardian.homeX - 14, 3, entry.guardian.homeZ)
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
	world.advance(4)
	t.equal("the guardian caught the thief", ana:GetAttribute("Carrying"), "")
	t.check("being caught plays the sad sound", table.find(heardNames(ana), "caught") ~= nil)
	t.check("the egg is back in the nest", entry.prompt.Enabled and entry.nest.tier == tierAtSteal)
	t.check("a guardian is still on the ground after chasing", math.abs(feetY(entry)) < 0.01, tostring(feetY(entry)))
	-- after the guardian is back at its nest its model must still be a real position (no NaN from looking at itself)
	world.advance(8)
	local look = entry.model:GetPivot().LookVector
	t.check(
		"and still faces somewhere real",
		look.X == look.X and look.Y == look.Y and look.Z == look.Z,
		tostring(look)
	)
	local bodyAfter = entry.model:FindFirstChild("Body") :: Part
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
	t.check("the thief was sent home", math.abs(root.Position.X - plot.spawn.Position.X) < 30)
	t.equal("speed is normal again", world.humanoid(ana).WalkSpeed, Progression.BASE_SPEED)
	t.equal("the guardian walks home", entry.guardian.state == "Return" or entry.guardian.state == "Idle", true)

	-- 3) escaping: run away faster than the guardian, then get home
	world.advance(10)
	root.Position = V3.new(entry.guardian.homeX - 14, 3, entry.guardian.homeZ)
	entry.prompt.Triggered:Fire(ana)
	t.check("the nest egg can be stolen again after a catch", ana:GetAttribute("Carrying") ~= "")
	local speed = world.humanoid(ana).WalkSpeed
	for _ = 1, 130 do
		root.Position = root.Position - V3.new(speed * 0.1, 0, 0)
		world.advance(0.1)
	end
	t.equal("a runner faster than the guardian keeps the egg", ana:GetAttribute("Carrying") ~= "", true)
	t.check("and the guardian gave up", entry.guardian.state ~= "Chase")
	root.Position = V3.new(plot.center.X, 3, plot.center.Z)
	world.advance(0.6)
	t.equal("running home delivers the egg", ana:GetAttribute("Carrying"), "")
	t.check("delivering plays the fanfare", table.find(heardNames(ana), "deliver") ~= nil)
	t.check("it is hatching in the base", (session.get(ana).base.slots[1] or {}).kind == "egg")
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
	root.Position = V3.new(entry.guardian.homeX - 16, 3, entry.guardian.homeZ)
	entry.prompt.Triggered:Fire(ana)
	t.check("a thief is out with the egg", ana:GetAttribute("Carrying") ~= "")
	root.Position = V3.new(entry.guardian.homeX - 200, 3, entry.guardian.homeZ) -- far from the guardian, not home yet
	world.advance(40)
	t.check("the thief still has the egg after 40 seconds", ana:GetAttribute("Carrying") ~= "")
	t.check("so the nest has not grown a new one", not entry.prompt.Enabled)
	t.equal("and still names them as the thief", entry.thief, ana)
	root.Position = V3.new(plot.center.X, 3, plot.center.Z)
	world.advance(0.6)
	t.equal("once they deliver it", ana:GetAttribute("Carrying"), "")
	world.advance(30)
	t.check("the nest grows a new egg a little later", entry.prompt.Enabled)

	-- 4) dying while carrying puts the egg back
	local third = entries[3]
	root.Position = V3.new(third.guardian.homeX - 14, 3, third.guardian.homeZ)
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
	mp = ana:GetAttribute("MemePoints") :: number
	local coinsBeforeFull = ana:GetAttribute("Coins") :: number
	local fourth = entries[4]
	root.Position = V3.new(fourth.guardian.homeX - 14, 3, fourth.guardian.homeZ)
	fourth.prompt.Triggered:Fire(ana)
	root.Position = V3.new(plot.center.X, 3, plot.center.Z)
	world.advance(0.6)
	t.equal("a full base never traps you carrying an egg", ana:GetAttribute("Carrying"), "")
	t.check("the points still count", (ana:GetAttribute("MemePoints") :: number) > mp)
	t.check("and the egg is sold for coins instead", (ana:GetAttribute("Coins") :: number) > coinsBeforeFull)
	t.equal("nothing was added to the full base", full.base.slots[1].kind, "char")

	-- 6) the gates
	root.Position = V3.new(500, 3, 0)
	world.advance(0.7)
	t.check("a player without enough points is pushed out of the Dune", root.Position.X < 440)
	t.equal("the HUD zone is the Meadow-side or home", ana:GetAttribute("Zone") ~= "Dune Desert", true)
	session.addPoints(ana, 25)
	root.Position = V3.new(500, 3, 0)
	world.advance(0.7)
	t.check("with the points they can stay", root.Position.X >= 500)
	t.equal("and the zone shows", ana:GetAttribute("Zone"), "Dune Desert")
	local dune = entries[7]
	t.equal("the seventh nest is the Dune's first", dune.zone.id, "Dune")
	-- a locked-terrain steal is refused even if you are standing there
	local lowbie = world.addPlayer("Ben", 22)
	world.spawnCharacter(lowbie)
	world.advance(0.6)
	world.root(lowbie).Position = V3.new(dune.guardian.homeX - 14, 3, dune.guardian.homeZ)
	dune.prompt.Triggered:Fire(lowbie)
	t.equal("a player who has not unlocked the terrain cannot steal there", lowbie:GetAttribute("Carrying"), "")
	t.check("and the egg is still there", dune.prompt.Enabled)

	-- 7) the treadmill trains speed
	local anaRoot = world.root(ana)
	anaRoot.Position = V3.new(plot.treadmill.Position.X, 3, plot.treadmill.Position.Z)
	world.advance(30)
	t.check("standing on the treadmill trains speed", (ana:GetAttribute("SpeedLevel") :: number) >= 1)
	t.check("which makes you walk faster", world.humanoid(ana).WalkSpeed > Progression.BASE_SPEED)

	-- 8) buying speed and slots
	anaRoot.Position = V3.new(plot.center.X, 3, plot.center.Z)
	local level = ana:GetAttribute("SpeedLevel") :: number
	session.add(ana, 100000)
	world.prompts(plot.model, "Buy speed")[1].Triggered:Fire(ana)
	t.equal("buying speed raises the level", ana:GetAttribute("SpeedLevel"), level + 1)
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
