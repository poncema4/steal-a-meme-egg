--!strict
local Config = require("../../src/shared/Config")
local Eggs = require("../../src/shared/Game/Eggs")
local Store = require("../../src/shared/Game/Store")

local catalog: Store.Catalog = {
	Passes = {
		coins = { id = 11, name = "C", blurb = "", robux = 1, effect = "income", factor = 2 },
		luck = { id = 12, name = "L", blurb = "", robux = 1, effect = "luck", factor = 2 },
		train = { id = 13, name = "T", blurb = "", robux = 1, effect = "train", factor = 3 },
	},
	Products = {
		one = { id = 21, name = "1", robux = 1, kind = "hatch", amount = 1 },
		five = { id = 22, name = "5", robux = 1, kind = "hatch", amount = 5 },
		goose = { id = 23, name = "G", robux = 1, kind = "limited", amount = 1, tier = "GooseGold" },
	},
}

return function(t)
	-- the shipped catalogue is valid, and every limited product names a real limited egg
	t.equal("the shipped catalogue has no mistakes", #Store.invalid(Config.Monetization :: any), 0)
	local real = true
	for _, product in (Config.Monetization :: any).Products do
		if product.kind == "limited" and not (product.tier and Eggs.tier(product.tier)) then
			real = false
		end
	end
	t.check("every limited product sells a real limited egg", real)
	local ids = true
	for _, group in { (Config.Monetization :: any).Passes, (Config.Monetization :: any).Products } do
		for _, item in group do
			if item.id ~= 0 then
				ids = false
			end
		end
	end
	t.check("nothing is for sale until its Creator Hub id is set", ids)
	t.equal("a typo in a pass effect is caught", #Store.invalid({
		Passes = { x = { id = 1, name = "", blurb = "", robux = 1, effect = "luk", factor = 2 } },
		Products = {},
	}), 1)
	t.equal("a limited product with no egg is caught", #Store.invalid({
		Passes = {},
		Products = { x = { id = 1, name = "", robux = 1, kind = "limited", amount = 1 } },
	}), 1)

	-- passes
	local p = Store.new()
	local luck, income, train = Store.multipliers(catalog, p)
	t.check("no passes means no bonus", luck == 1 and income == 1 and train == 1)
	t.check("a pass is granted once", Store.grantPass(p, "coins") and not Store.grantPass(p, "coins"))
	luck, income, train = Store.multipliers(catalog, p)
	t.check("2x coins doubles income only", luck == 1 and income == 2 and train == 1)
	Store.grantPass(p, "luck")
	Store.grantPass(p, "train")
	luck, income, train = Store.multipliers(catalog, p)
	t.check("passes stack across effects", luck == 2 and income == 2 and train == 3)
	p.passes.ghost = true
	t.check("a pass the catalogue does not know is ignored", select(2, Store.multipliers(catalog, p)) == 2)
	t.equal("a pass id is found", Store.passKey(catalog, 12), "luck")
	t.equal("an unknown id is not", Store.passKey(catalog, 999), nil)
	t.equal(
		"id 0 never matches",
		Store.passKey({
			Passes = { x = { id = 0, name = "", blurb = "", robux = 1, effect = "luck", factor = 2 } },
			Products = {},
		}, 0),
		nil
	)

	-- products
	local q = Store.new()
	local outcome, effect = Store.grantProduct(catalog, q, 22, "r1")
	t.check(
		"a hatch pack gives tokens",
		outcome == "granted" and effect ~= nil and effect.kind == "hatch" and q.hatchTokens == 5
	)
	t.equal("a replayed receipt is a duplicate", (Store.grantProduct(catalog, q, 22, "r1")), "duplicate")
	t.equal("and pays nothing", q.hatchTokens, 5)
	t.equal("an unknown product is unknown", (Store.grantProduct(catalog, q, 999, "r2")), "unknown")
	local _, limited = Store.grantProduct(catalog, q, 23, "r3")
	t.check(
		"a limited product names its egg",
		limited ~= nil and limited.kind == "limited" and limited.tier == "GooseGold"
	)
	t.equal("and adds no tokens", q.hatchTokens, 5)
	t.check("tokens are spent one at a time", Store.useToken(q) and q.hatchTokens == 4)
	q.hatchTokens = 0
	t.check("with none left nothing is spent", not Store.useToken(q) and q.hatchTokens == 0)

	-- the waiting list for paid limited eggs
	Store.queueLimited(q, "GooseGold")
	Store.queueLimited(q, "CatCosmic")
	t.equal("waiting eggs come out in order", Store.popLimited(q), "GooseGold")
	t.equal("then the next", Store.popLimited(q), "CatCosmic")
	t.equal("then nothing", Store.popLimited(q), nil)

	-- the receipt memory is capped so a save never grows forever
	local r = Store.new()
	for i = 1, Store.MAX_RECEIPTS + 50 do
		Store.grantProduct(catalog, r, 21, `rcpt{i}`)
	end
	t.equal("receipt memory is capped", #r.receiptOrder, Store.MAX_RECEIPTS)
	t.check(
		"old receipts are forgotten, recent ones kept",
		r.receipts.rcpt1 == nil and r.receipts[`rcpt{Store.MAX_RECEIPTS + 50}`] == true
	)
end
