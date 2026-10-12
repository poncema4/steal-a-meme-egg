--!strict
-- Mutated eggs: a nest can grow a Gold or Rainbow egg, the egg keeps its mutation all the way home, pays more Meme Points, and
-- hatches into a pet with that mutation. Deeper terrains grow them more often.
local Base = require("../../src/shared/Game/Base")
local BaseView = require("../../src/shared/Game/BaseView")
local Eggs = require("../../src/shared/Game/Eggs")
local Fake = require("../fake/Roblox")
local Nest = require("../../src/shared/Game/Nest")
local Progression = require("../../src/shared/Game/Progression")
local Zones = require("../../src/shared/Game/Zones")

return function(t)
	-- how often nests mutate
	local function share(depth: number): (number, number)
		local gold, rainbow, n = 0, 0, 40000
		for i = 1, n do
			local m = Eggs.nestMutation(depth, function()
				return (i - 0.5) / n
			end)
			if m == "Gold" then
				gold += 1
			elseif m == "Rainbow" then
				rainbow += 1
			end
		end
		return gold / n, rainbow / n
	end
	local g1, r1 = share(1)
	-- Marco: Normal most, Gold less, Rainbow least; a little more each world deeper, never easy
	t.check("almost every Meadow egg is Normal", g1 + r1 < 0.05, tostring(g1 + r1))
	t.check("a few Meadow eggs are Gold", g1 > 0.02 and g1 < 0.04, tostring(g1))
	t.check("Rainbow is much rarer than Gold", r1 < g1 / 3, tostring(r1))
	local g5, r5 = share(5)
	t.check("deeper terrains grow a little more Gold", g5 > g1)
	t.check("and a little more Rainbow", r5 > r1)
	local gDeep, rDeep = share(30)
	t.check(
		"even the deepest world stays rare: Gold at most 10%, Rainbow at most 3%",
		gDeep <= 0.1001 and rDeep <= 0.0301
	)
	-- no lucky streaks: right after a Gold or Rainbow egg the nest's chance drops, then recovers with normal eggs
	local afterRainbow = Eggs.dampAfter(1, "Rainbow")
	local afterGold = Eggs.dampAfter(1, "Gold")
	t.check("a Rainbow egg makes the nest's next lucky egg much less likely", afterRainbow <= 0.25)
	t.check("a Gold one halves it", afterGold <= 0.5)
	local g, rb = Eggs.nestChances(1, afterRainbow)
	local gFull, rbFull = Eggs.nestChances(1, 1)
	t.check("so the chances right after a Rainbow are lower", g < gFull and rb < rbFull)
	local damp = afterRainbow
	for _ = 1, 6 do
		damp = Eggs.dampAfter(damp, "Normal")
	end
	t.equal("and recover after a few normal eggs", damp, 1)
	for _, odd in { 0, -3, 99, 0 / 0 } do
		local m = Eggs.nestMutation(odd, math.random)
		t.check(`a strange depth ({odd}) still names a real mutation`, Eggs.Mutations[m] ~= nil)
	end
	t.equal(
		"a roll of 0 is Rainbow",
		Eggs.nestMutation(1, function()
			return 0
		end),
		"Rainbow"
	)
	t.equal(
		"a roll of 0.999 is Normal",
		Eggs.nestMutation(1, function()
			return 0.999
		end),
		"Normal"
	)

	-- a nest keeps the mutation of its egg
	local nest = Nest.new("Spicy", "Gold")
	local tier, mutation = Nest.take(nest, 5)
	t.check("taking gives the tier and mutation", tier == "Spicy" and mutation == "Gold")
	t.equal("an empty nest has no mutation", nest.mutation, "Normal")
	Nest.giveBack(nest, "Spicy", "Rainbow")
	t.equal("a recovered egg keeps its mutation", nest.mutation, "Rainbow")
	Nest.take(nest, 1)
	Nest.tick(nest, 2, function()
		return "Disco", "Gold"
	end)
	t.check("a regrown egg can come back mutated", nest.tier == "Disco" and nest.mutation == "Gold")
	t.equal("Nest.new defaults to Normal", Nest.new("Soggy").mutation, "Normal")

	-- a mutated egg hatches into a mutated pet
	local base = Base.new(4)
	Base.placeEgg(base, "Soggy", "Gold")
	Base.placeEgg(base, "Soggy")
	Base.placeEgg(base, "Soggy", "Evil")
	base.slots[1].hatchLeft = 0
	base.slots[2].hatchLeft = 0
	base.slots[3].hatchLeft = 0
	t.equal("an invalid mutation is ignored", base.slots[3].eggMutation, nil)
	Base.tick(base, 0, function()
		return "SoggyToast"
	end, function()
		return "Rainbow"
	end)
	t.equal("a Gold egg hatches a Gold pet even if the roll says Rainbow", base.slots[1].mutation, "Gold")
	t.equal("a Normal egg lets the usual roll decide", base.slots[2].mutation, "Rainbow")

	-- the base view carries it
	local view = Base.new(3)
	Base.placeEgg(view, "Golden", "Rainbow")
	local rows = BaseView.decode(BaseView.encode(view))
	t.equal("the base view keeps an egg's mutation", rows[1].mutation, "Rainbow")
	t.equal("a plain egg decodes as Normal", BaseView.decode("1,e,Soggy,9")[1].mutation, "Normal")
	t.equal("a made-up egg mutation decodes as Normal", BaseView.decode("1,e,Soggy,9,Evil")[1].mutation, "Normal")

	-- on the real server: steal, carry, deliver, hatch
	local world = Fake.world()
	local V3 = world.Vector3
	local ok, err = pcall(world.load, "src/server/main.server")
	t.check("the server starts", ok, tostring(err))
	if not ok then
		return
	end
	local wilds = world.load("src/server/Wilds")
	local session = world.load("src/server/Session")
	local plots = world.load("src/server/Plots")
	local ana = world.addPlayer("Ana", 31)
	world.spawnCharacter(ana)
	world.advance(0.6)
	local entry = wilds.entries()[1]
	local function steal(kind: string)
		entry.nest.mutation = kind
		entry.nest.tier = "Soggy"
		world.root(ana).Position = V3.new(entry.egg.Position.X - 5, 3, entry.egg.Position.Z)
		entry.prompt.Triggered:Fire(ana)
		world.root(ana).Position = V3.new(entry.egg.Position.X - 141, 3, entry.egg.Position.Z)
	end
	steal("Gold")
	t.equal("stealing a Gold egg: the HUD knows", ana:GetAttribute("CarryingMutation"), "Gold")
	t.equal("the nest forgets the mutation", entry.nest.mutation, "Normal")
	local carriedTier, _, carriedMutation = session.carrying(ana)
	t.check("the server tracks tier and mutation", carriedTier == "Soggy" and carriedMutation == "Gold")
	-- caught: the egg goes back with its mutation
	world.root(ana).Position = V3.new(entry.guardian.x, 3, entry.guardian.z)
	world.advance(0.5)
	t.equal("a caught thief drops nothing", ana:GetAttribute("Carrying"), "")
	t.equal("the egg is back in its nest, still Gold", entry.nest.mutation, "Gold")
	t.equal("and the nest looks Gold", entry.egg:GetAttribute("Mutation"), "Gold")
	t.check("with a Gold prompt", string.find(entry.prompt.ObjectText, "Gold", 1, true) ~= nil)
	-- carry it home properly
	world.advance(1)
	steal("Gold")
	local before = session.get(ana).mp
	local plot = plots.of(ana)
	world.root(ana).Position = V3.new(plot.center.X, 3, plot.center.Z)
	world.advance(1)
	-- in the pen the egg is not put down by itself (Marco): you pick the spot and press Place egg
	t.equal("walking into the pen does not place the egg", ana:GetAttribute("Carrying"), "Soggy")
	t.equal("the HUD knows you are in your pen", ana:GetAttribute("InPen"), true)
	local remotes = world.service("ReplicatedStorage"):FindFirstChild("Remotes") :: Instance
	local placeRemote = remotes:FindFirstChild("PlaceEgg") :: RemoteEvent
	world.setLocal(ana)
	placeRemote:FireServer(V3.new(plot.center.X + 4, 0.5, plot.center.Z + 4)) -- a click on the pen's ground
	world.advance(0.2)
	t.equal("a Gold egg pays double Meme Points", session.get(ana).mp - before, Progression.pointsForEgg("Soggy") * 2)
	local item = session.get(ana).base.slots[1]
	t.check("it is in the base as a Gold egg", item ~= nil and item.kind == "egg" and item.eggMutation == "Gold")
	t.check("the base view shows it", string.find(tostring(ana:GetAttribute("BaseItems")), "Gold", 1, true) ~= nil)
	item.hatchLeft = 0
	session.hatchNow(ana)
	local pet = session.get(ana).base.slots[1]
	t.check("it hatched a Gold pet", pet ~= nil and pet.kind == "char" and pet.mutation == "Gold")
	t.check("and the Index saw Gold", string.find(tostring(ana:GetAttribute("Index")), ":Gold", 1, true) ~= nil)

	-- a Rainbow egg pays five times as much, and is sold for five times when the base is full
	steal("Rainbow")
	local mpBefore = session.get(ana).mp
	local full = session.get(ana).base
	for i = 1, full.size do
		full.slots[i] = { kind = "char", id = "SoggyToast", mutation = "Normal" }
	end
	local coins = session.get(ana).coins
	world.root(ana).Position = V3.new(plot.center.X, 3, plot.center.Z)
	world.advance(1)
	world.load("src/server/Home").placeEgg(ana)
	world.advance(0.2)
	t.equal("Rainbow pays five times the points", session.get(ana).mp - mpBefore, Progression.pointsForEgg("Soggy") * 5)
	local def = Eggs.tier("Soggy") :: Eggs.Tier
	t.check(
		"a full base sells a Rainbow egg for five times the price",
		session.get(ana).coins - coins >= def.price * 0.5 * 5 - 1
	)

	-- saving keeps the mutation of an egg in the base
	local saved = Base.new(3)
	Base.placeEgg(saved, "Disco", "Gold")
	t.equal("a base remembers a Gold egg", saved.slots[1].eggMutation, "Gold")
	t.check("deeper zones exist to grow them", #Zones.List >= 5)
end
