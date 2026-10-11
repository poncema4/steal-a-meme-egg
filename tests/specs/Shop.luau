--!strict
-- The limited egg and the hatch skip, through the real server scripts.
local Fake = require("../fake/Roblox")
local Limited = require("../../src/shared/Game/Limited")

return function(t)
	local world = Fake.world()
	local storage = world.service("ReplicatedStorage")
	local ok, err = pcall(world.load, "src/server/main.server")
	t.check("the server starts", ok, tostring(err))
	if not ok then
		return
	end
	local session = world.load("src/server/Session")
	local limited = world.load("src/server/LimitedService")
	local plots = world.load("src/server/Plots")

	local ana = world.addPlayer("Ana", 31)
	local ben = world.addPlayer("Ben", 32)
	world.advance(6)
	local current = Limited.current(world.workspace:GetServerTimeNow())
	t.equal("the HUD is told which limited egg is on sale", storage:GetAttribute("LimitedTier"), current.tier)
	t.equal("and how many are left", storage:GetAttribute("LimitedLeft"), Limited.STOCK)
	t.equal("and when it ends", storage:GetAttribute("LimitedEnds"), current.endsAt)

	-- limited eggs are Robux only (Marco): no coin purchase exists, a paid one takes one from the shared stock
	t.check("there is no coin purchase", limited.buyWithCoins == nil)
	t.check(
		"nor a remote to buy with coins",
		world.service("ReplicatedStorage"):FindFirstChild("Remotes"):FindFirstChild("BuyLimited") == nil
	)
	t.check("a paid limited egg lands in the base", limited.grantPaid(ana, current.tier))
	local item = session.get(ana).base.slots[1]
	t.check("as that egg", item ~= nil and item.kind == "egg" and item.tier == current.tier)
	world.advance(6)
	t.equal("the shared stock went down by one", storage:GetAttribute("LimitedLeft"), Limited.STOCK - 1)
	-- sold out: the stock never goes below zero, and a purchase already paid for is still honoured
	for _ = 1, Limited.STOCK - 1 do
		limited.claimStock(current.key)
	end
	t.equal("a claim past zero gets nothing", limited.claimStock(current.key), nil)
	t.check("a paid one is still honoured", limited.grantPaid(ben, current.tier))
	local next = Limited.current(current.endsAt + 1)
	world.advance(Limited.PERIOD)
	t.check(
		"the next rotation has fresh stock",
		next.key ~= current.key and limited.claimStock(next.key) == Limited.STOCK - 1
	)

	-- skipping a hatch
	local plot = plots.of(ana)
	local anaState = session.get(ana)
	for n = 1, anaState.base.size do
		anaState.base.slots[n] = nil
	end
	anaState.base.slots[1] = { kind = "egg", tier = "Disco", hatchLeft = 15 }
	session.changed(ana)
	t.equal(
		"a hatching egg has no coin-skip prompt: only Robux speeds it up",
		#world.prompts(plot.model, "Skip hatch"),
		0
	)
	local coinsBefore = ana:GetAttribute("Coins") :: number
	session.add(ana, 100000)
	t.equal("coins cannot hatch an egg", anaState.base.slots[1].kind, "egg")
	t.check("and nothing was charged", (ana:GetAttribute("Coins") :: number) >= coinsBefore)
end
