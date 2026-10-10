--!strict
-- The limited egg and the hatch skip, through the real server scripts.
local Eggs = require("../../src/shared/Game/Eggs")
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

	-- buying with coins
	local price = (Eggs.tier(current.tier) :: Eggs.Tier).price
	local ok1, why1 = limited.buyWithCoins(ana)
	t.check("a poor player cannot buy it", not ok1 and why1 == "not enough coins")
	session.add(ana, price + 500)
	local before = ana:GetAttribute("Coins") :: number
	local ok2 = limited.buyWithCoins(ana)
	t.check("a rich player can", ok2)
	t.check("it costs the price", math.abs((before - price) - (ana:GetAttribute("Coins") :: number)) < 5000)
	local item = session.get(ana).base.slots[1]
	t.check("and the egg is in their base", item ~= nil and item.kind == "egg" and item.tier == current.tier)
	world.advance(6)
	t.equal("the shared stock went down by one", storage:GetAttribute("LimitedLeft"), Limited.STOCK - 1)

	-- sold out
	for _ = 1, Limited.STOCK - 1 do
		limited.claimStock(current.key)
	end
	session.add(ben, price + 500)
	local coins = ben:GetAttribute("Coins") :: number
	local ok3, why3 = limited.buyWithCoins(ben)
	t.check("when it is sold out nobody can buy", not ok3 and string.find(why3, "sold out") ~= nil, why3)
	t.equal("and nobody is charged", ben:GetAttribute("Coins"), coins)
	t.equal("a claim past zero gets nothing", limited.claimStock(current.key), nil)

	-- a full base cannot buy, and does not burn stock
	local next = Limited.current(current.endsAt + 1)
	world.advance(Limited.PERIOD)
	local state = session.get(ben)
	for n = 1, state.base.size do
		state.base.slots[n] = { kind = "char", id = "SoggyToast", mutation = "Normal" }
	end
	local coins2 = ben:GetAttribute("Coins") :: number
	local ok4, why4 = limited.buyWithCoins(ben)
	t.check("a full base cannot buy", not ok4 and string.find(why4, "full") ~= nil, why4)
	t.equal("and is not charged", ben:GetAttribute("Coins"), coins2)
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
	local skips = world.prompts(plot.model, "Skip hatch")
	t.equal("a hatching egg has a skip prompt", #skips, 1)
	session.add(ana, -(ana:GetAttribute("Coins") :: number)) -- broke
	skips[1].Triggered:Fire(ana)
	t.equal("a player without the coins cannot skip", anaState.base.slots[1].kind, "egg")
	session.add(ana, 100000)
	local richer = ana:GetAttribute("Coins") :: number
	skips[1].Triggered:Fire(ben)
	t.equal("nobody else can skip your egg", anaState.base.slots[1].kind, "egg")
	skips[1].Triggered:Fire(ana)
	t.equal("paying hatches it at once", anaState.base.slots[1].kind, "char")
	local paid = richer - (ana:GetAttribute("Coins") :: number)
	t.check("for the skip price (60% of a 1,000-coin egg)", math.abs(paid - 600) < 50, tostring(paid))
end
