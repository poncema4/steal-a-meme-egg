--!strict
-- The passes that change how you play, not just a multiplier: faster hatching, six traps with a shorter wait, and slower bosses.
local Config = require("../../src/shared/Config")
local Fake = require("../fake/Roblox")
local Store = require("../../src/shared/Game/Store")
local Zones = require("../../src/shared/Game/Zones")

return function(t)
	local catalog = Config.Monetization :: any
	local none = Store.perks(catalog, Store.new())
	t.check(
		"with no passes you get the normal game",
		none.hatch == 1 and none.trapMax == 3 and none.trapCooldown == 1 and none.bossSlow == 1
	)
	local owned = Store.new()
	owned.passes.fastHatch = true
	owned.passes.trapMaster = true
	owned.passes.bossSlow = true
	local perks = Store.perks(catalog, owned)
	t.equal("Hatch Speed doubles hatching", perks.hatch, 2)
	t.equal("Trap Master allows six traps", perks.trapMax, 6)
	t.equal("and halves the wait between them", perks.trapCooldown, 0.5)
	t.equal("Slow Bosses slows them by a quarter", perks.bossSlow, 1.25)
	local vip = Store.new()
	vip.passes.vip = true
	local _, income = Store.multipliers(catalog, vip)
	t.equal("VIP pays 25% more coins", income, 1.25)
	t.equal(
		"and a pass the catalogue does not know does nothing",
		Store.perks(
			catalog,
			{ passes = { nope = true }, receipts = {}, receiptOrder = {}, hatchTokens = 0, pendingLimited = {} }
		).hatch,
		1
	)
	t.equal("the catalogue has no bad effect names", #Store.invalid(catalog), 0)

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
	local place = remotes:FindFirstChild("PlaceTrap") :: RemoteEvent
	local ana = world.addPlayer("Ana", 801)
	local ben = world.addPlayer("Ben", 802)
	world.spawnCharacter(ana)
	world.spawnCharacter(ben)
	world.advance(0.6)
	world.setLocal(ana)

	-- hatching: Ana's pass doubles it, Ben's eggs hatch at the normal pace
	session.grantEgg(ana, "Soggy")
	session.grantEgg(ben, "Soggy")
	session.get(ana).purchases.passes.fastHatch = true
	world.advance(5) -- the Soggy egg takes 8 seconds
	t.equal("with the pass an 8 second egg is done in 5", ana:GetAttribute("Characters"), 1)
	t.equal("without it, it is not", ben:GetAttribute("Characters"), 0)

	-- traps: the HUD is told how many Ana may have
	t.equal("a normal player may have 3", ben:GetAttribute("TrapsMax"), 3)
	session.get(ana).purchases.passes.trapMaster = true
	session.changed(ana)
	t.equal("Trap Master tells the HUD six", ana:GetAttribute("TrapsMax"), 6)
	local root = world.root(ana)
	for i = 1, 6 do
		root.Position = V3.new(Zones.List[1].startX + 30 + i * 8, 3, 0)
		place:FireServer()
		world.advance(1.1) -- half the normal wait
	end
	t.equal("Ana set six traps, one second apart", ana:GetAttribute("TrapsPlaced"), 6)
	root.Position = V3.new(Zones.List[1].startX + 100, 3, 0)
	place:FireServer()
	world.advance(1.1)
	t.equal("and not a seventh", ana:GetAttribute("TrapsPlaced"), 6)

	-- bosses: a thief with the pass is chased more slowly
	local entry = wilds.entries()[1]
	local boss = entry.boss
	session.get(ana).purchases.passes.bossSlow = true
	entry.nest.tier = "Soggy"
	root.Position = V3.new(entry.egg.Position.X - 5, 3, entry.egg.Position.Z)
	entry.prompt.Triggered:Fire(ana)
	t.check("Ana steals", ana:GetAttribute("Carrying") ~= "")
	world.advance(0.3)
	t.check(
		"the boss moves at a quarter less than its normal speed for her",
		math.abs(boss.guardian.speed - boss.zone.guardianSpeed / 1.25) < 1e-6,
		tostring(boss.guardian.speed)
	)
end
