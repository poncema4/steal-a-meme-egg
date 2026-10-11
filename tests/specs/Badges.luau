--!strict
-- Badges: handed out the first time a player does the thing, never twice, and never for a badge with no Roblox id yet.
local Config = require("../../src/shared/Config")
local Fake = require("../fake/Roblox")
local Zones = require("../../src/shared/Game/Zones")

return function(t)
	-- the catalogue itself
	local names, ok = {}, true
	for key, badge in Config.Badges :: any do
		if badge.name == "" or #badge.name > 50 or #badge.description > 1000 or names[badge.name] then
			ok = false
			print("  bad badge", key)
		end
		names[badge.name] = true
	end
	t.check("every badge has its own name and a description", ok)

	local world = Fake.world()
	local V3 = world.Vector3
	local ok2, err = pcall(world.load, "src/server/main.server")
	t.check("the server starts", ok2, tostring(err))
	if not ok2 then
		return
	end
	local badges = world.load("src/server/Badges")
	local session = world.load("src/server/Session")
	local wilds = world.load("src/server/Wilds")
	local given: { string } = {}
	local ids: { [number]: string } = {}
	local catalog: any = {}
	local n = 100
	for key, badge in Config.Badges :: any do
		n += 1
		catalog[key] = { id = n, name = badge.name, description = badge.description }
		ids[n] = key
	end
	badges.setCatalog(catalog)
	badges.setAwarder(function(_, id)
		table.insert(given, ids[id])
		return true
	end)

	local ana = world.addPlayer("Ana", 901)
	world.spawnCharacter(ana)
	world.advance(0.6)
	t.check("joining gives Welcome", table.find(given, "welcome") ~= nil)

	-- a badge Roblox refused is tried again the next time it is earned (it is not marked as given)
	local tries = 0
	badges.setAwarder(function()
		tries += 1
		return tries > 1
	end)
	local probe = world.addPlayer("Probe", 902)
	world.advance(0.3)
	t.equal("a refused Welcome was attempted", tries, 1)
	t.check("and can be earned again", badges.give(probe, "welcome"))
	world.advance(0.3)
	t.equal("the second try goes through", tries, 2)
	t.check("after that it counts as given", not badges.give(probe, "welcome"))
	badges.setAwarder(function(_, id)
		table.insert(given, ids[id])
		return true
	end)

	-- stealing, delivering, hatching
	local entry = wilds.entries()[1]
	entry.nest.tier = "Soggy"
	world.root(ana).Position = V3.new(entry.egg.Position.X - 5, 3, entry.egg.Position.Z)
	entry.prompt.Triggered:Fire(ana)
	t.check("the first steal gives Egg Thief", table.find(given, "firstSteal") ~= nil)
	local plot = world.load("src/server/Plots").of(ana)
	world.root(ana).Position = V3.new(plot.center.X, 3, plot.center.Z)
	world.advance(0.6)
	world.load("src/server/Home").placeEgg(ana)
	world.advance(0.2)
	t.check("bringing it home gives Home Safe", table.find(given, "homeSafe") ~= nil)
	t.check("a Meadow egg is not a Boss Escape", table.find(given, "bossEscape") == nil)
	world.advance(10)
	for slot = 1, 12 do -- the owner presses Hatch on every finished egg
		world.load("src/server/Session").hatchSlot(ana, slot)
	end
	world.advance(0.2)
	t.check("the first hatch gives Crack!", table.find(given, "firstHatch") ~= nil)

	-- a boss escape needs an egg from the third terrain or deeper
	local volcano
	for _, e in wilds.entries() do
		if e.zone.id == "Volcano" then
			volcano = e
			break
		end
	end
	session.setCarry(ana, "Spicy", volcano.id, "Normal")
	session.deliver(ana)
	t.check("an egg from Lava Lands gives Boss Escape", table.find(given, "bossEscape") ~= nil)
	t.check("but not Sky High", table.find(given, "deepDiver") == nil)
	session.setCarry(ana, "Cloud", "Nest_Sky_1", "Normal")
	session.deliver(ana)
	t.check("an egg from the Sky Kingdom gives Sky High", table.find(given, "deepDiver") ~= nil)

	-- progress badges
	session.addSpeedXp(ana, 1e9)
	world.advance(4)
	t.check("a speed of 100,000 gives Speed Demon", table.find(given, "speedDemon") ~= nil)
	session.get(ana).rebirths = 1
	session.changed(ana)
	t.check("a rebirth gives Reborn", table.find(given, "reborn") ~= nil)
	local base = session.get(ana).base
	base.size = 12
	local k = 0
	for id in (require("../../src/shared/Game/Eggs") :: any).Characters do
		k += 1
		if k > base.size then
			break
		end
		base.slots[k] = { kind = "char", id = id, mutation = "Normal" }
	end
	session.changed(ana)
	world.advance(4)
	t.check("ten characters in the Index gives Meme Collector", table.find(given, "collector") ~= nil)

	-- never twice, and an unknown or id-less badge does nothing
	local before = #given
	session.changed(ana)
	session.setCarry(ana, "Soggy", entry.id, "Normal")
	session.deliver(ana)
	t.equal("nothing is handed out twice in one visit", #given, before)
	t.check("a badge with no id is skipped", not badges.give(ana, "nonsense"))
	badges.setCatalog({ welcome = { id = 0, name = "x", description = "y" } })
	local other = world.addPlayer("Ben", 902)
	t.check("a badge whose id is 0 is skipped", not badges.give(other, "welcome"))
	t.check("the catalogue tells the zones apart", Zones.forTier("Cloud") ~= nil)
end
