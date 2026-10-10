--!strict
-- Robux purchases through the real server: owned passes found on join and doubling income, receipts granted exactly once,
-- instant hatches (token or buy-now), paid limited eggs placed or queued, and the client can only ask by key.
local Eggs = require("../../src/shared/Game/Eggs")
local Fake = require("../fake/Roblox")
local Limited = require("../../src/shared/Game/Limited")
local Store = require("../../src/shared/Game/Store")

local catalog: Store.Catalog = {
	Passes = {
		coins2x = { id = 111, name = "C", blurb = "", robux = 399, effect = "income", factor = 2 },
		luck2x = { id = 112, name = "L", blurb = "", robux = 299, effect = "luck", factor = 2 },
		train2x = { id = 113, name = "T", blurb = "", robux = 199, effect = "train", factor = 2 },
	},
	Products = {
		hatch1 = { id = 221, name = "H", robux = 25, kind = "hatch", amount = 1 },
		hatch5 = { id = 222, name = "H5", robux = 99, kind = "hatch", amount = 5 },
		limitedGoose = { id = 231, name = "G", robux = 199, kind = "limited", amount = 1, tier = "GooseGold" },
		unsold = { id = 0, name = "U", robux = 1, kind = "hatch", amount = 1 },
	},
}

return function(t)
	local world = Fake.world()
	local market = world.service("MarketplaceService")
	local ok, err = pcall(world.load, "src/server/main.server")
	t.check("the server starts with purchases", ok, tostring(err))
	if not ok then
		return
	end
	local session = world.load("src/server/Session")
	local plots = world.load("src/server/Plots")
	session.setCatalog(catalog)
	local remotes = world.service("ReplicatedStorage"):FindFirstChild("Remotes")

	-- a pass bought earlier is found on join and doubles income
	market.owned["41:111"] = true
	local owner = world.addPlayer("Owner", 41)
	local buyer = world.addPlayer("Buyer", 42)
	world.advance(1)
	t.check("a pass owned before is found on join", session.purchases(owner).passes.coins2x == true)
	t.check("a player without it does not get it", session.purchases(buyer).passes.coins2x == nil)
	for _, p in { owner, buyer } do
		session.get(p).base.slots[1] = { kind = "char", id = "BonkBean", mutation = "Normal" }
		session.changed(p)
	end
	t.equal("a normal player earns the listed income", buyer:GetAttribute("Income"), 2)
	t.equal("2x Coins doubles it", owner:GetAttribute("Income"), 4)
	local _, _, train = session.passMultipliers(owner)
	t.equal("and does not touch training", train, 1)

	-- receipts
	local granted = world.enum.ProductPurchaseDecision.PurchaseGranted
	local retry = world.enum.ProductPurchaseDecision.NotProcessedYet
	local function receipt(userId: number, purchaseId: string, productId: number)
		return market.ProcessReceipt({ PlayerId = userId, ProductId = productId, PurchaseId = purchaseId })
	end
	t.equal("a hatch pack receipt is granted", receipt(42, "p1", 222), granted)
	t.equal("and adds five tokens", session.hatchTokens(buyer), 5)
	t.equal("Roblox replaying it is acknowledged", receipt(42, "p1", 222), granted)
	t.equal("but pays nothing again", session.hatchTokens(buyer), 5)
	t.equal("an unknown product is not acknowledged (Roblox retries)", receipt(42, "p2", 999), retry)
	t.equal("a receipt for someone who left is not acknowledged", receipt(7, "p3", 222), retry)
	t.equal("an unset product id is never sold", receipt(42, "p4", 0), retry)

	-- instant hatch with a token
	local state = session.get(buyer)
	state.base.slots[2] = { kind = "egg", tier = "Disco", hatchLeft = 15 }
	session.changed(buyer)
	local plot = plots.of(buyer)
	local instants = world.prompts(plot.model, "Instant hatch")
	t.check("a hatching egg has an instant-hatch prompt", #instants >= 1)
	instants[1].Triggered:Fire(owner)
	t.equal("only the owner can use it", state.base.slots[2].kind, "egg")
	instants[1].Triggered:Fire(buyer)
	t.equal("using a token hatches the egg", state.base.slots[2].kind, "char")
	t.equal("and spends one token", session.hatchTokens(buyer), 4)

	-- instant hatch bought right now (no tokens): prompt the product, then the receipt hatches the waiting egg
	local solo = world.addPlayer("Solo", 43)
	world.advance(1)
	local soloState = session.get(solo)
	soloState.base.slots[1] = { kind = "egg", tier = "Spicy", hatchLeft = 30 }
	session.changed(solo)
	local soloPlot = plots.of(solo)
	local before = #market.prompts
	world.prompts(soloPlot.model, "Instant hatch")[1].Triggered:Fire(solo)
	t.check(
		"with no tokens it offers the real product",
		#market.prompts == before + 1 and market.prompts[#market.prompts].id == 221
	)
	t.equal("the egg is still waiting", soloState.base.slots[1].kind, "egg")
	t.equal("the receipt is granted", receipt(43, "s1", 221), granted)
	t.equal("and hatches the egg that was waiting", soloState.base.slots[1].kind, "char")
	t.equal("using the token it just bought", session.hatchTokens(solo), 0)

	-- paid limited eggs
	local current = Limited.current(world.workspace:GetServerTimeNow())
	local goose = (Eggs.LimitedTiers[1] :: Eggs.Tier).id
	local lim = world.addPlayer("Lim", 44)
	world.advance(1)
	local limState = session.get(lim)
	t.equal("a paid limited egg is granted", receipt(44, "l1", 231), granted)
	local placed = false
	for n = 1, limState.base.size do
		local item = limState.base.slots[n]
		if item and item.kind == "egg" and item.tier == goose then
			placed = true
		end
	end
	t.check("and goes into the base", placed)
	t.check("the rotation key exists", current.key ~= "")
	for n = 1, limState.base.size do
		limState.base.slots[n] = { kind = "char", id = "SoggyToast", mutation = "Normal" }
	end
	t.equal("a limited egg bought with a full base is still granted", receipt(44, "l2", 231), granted)
	t.equal("and waits for room", #session.purchases(lim).pendingLimited, 1)
	limState.base.slots[3] = nil
	session.changed(lim)
	t.equal("a freed slot delivers it", limState.base.slots[3] ~= nil and limState.base.slots[3].tier or "", goose)
	t.equal("and the waiting list is empty", #session.purchases(lim).pendingLimited, 0)

	-- a pass bought now
	world.setLocal(buyer)
	market.PromptGamePassPurchaseFinished:Fire(buyer, 112, false)
	t.check("cancelling a pass grants nothing", session.purchases(buyer).passes.luck2x == nil)
	market.PromptGamePassPurchaseFinished:Fire(buyer, 112, true)
	t.check("buying the pass turns it on", session.purchases(buyer).passes.luck2x == true)
	t.equal("with its multiplier", (session.passMultipliers(buyer)), 2)
	market.PromptGamePassPurchaseFinished:Fire(buyer, 999, true)
	t.check("an unknown pass id turns nothing on", session.purchases(buyer).passes.nope == nil)

	-- the client asks by key and cannot name an id
	local buy = remotes:FindFirstChild("Buy")
	world.advance(1.1)
	local n0 = #market.prompts
	buy:FireServer("pass", "coins2x")
	t.check(
		"asking for a pass prompts the real id",
		#market.prompts == n0 + 1 and market.prompts[#market.prompts].id == 111
	)
	world.advance(1.1)
	buy:FireServer("product", 221)
	buy:FireServer("product", "nope")
	t.equal("a raw id or an unknown key prompts nothing", #market.prompts, n0 + 1)
	world.advance(1.1)
	buy:FireServer("product", "unsold")
	t.equal("an item with no Creator Hub id prompts nothing", #market.prompts, n0 + 1)
	world.advance(1.1)
	buy:FireServer("product", "hatch5")
	t.check(
		"a product key prompts the real id",
		#market.prompts == n0 + 2 and market.prompts[#market.prompts].id == 222
	)

	-- a receipt is only acknowledged once the player is saved: with the DataStore down Roblox must retry
	local down = Fake.world()
	local failing = true
	down.service("DataStoreService").GetDataStore = function()
		return {
			GetAsync = function()
				return nil
			end,
			UpdateAsync = function(_, _, fn)
				if failing then
					error("DataStore is down")
				end
				return fn(nil)
			end,
		}
	end
	pcall(down.load, "src/server/main.server")
	local session2 = down.load("src/server/Session")
	session2.setCatalog(catalog)
	local market2 = down.service("MarketplaceService")
	local payer = down.addPlayer("Payer", 61)
	down.advance(1)
	local function receipt2(purchaseId: string)
		return market2.ProcessReceipt({ PlayerId = 61, ProductId = 222, PurchaseId = purchaseId })
	end
	local retry2 = down.enum.ProductPurchaseDecision.NotProcessedYet
	local granted2 = down.enum.ProductPurchaseDecision.PurchaseGranted
	t.equal("with the DataStore down the receipt is NOT acknowledged", receipt2("d1"), retry2)
	t.equal("the player has the tokens in the meantime", session2.hatchTokens(payer), 5)
	failing = false
	t.equal("when Roblox retries and the save works it is acknowledged", receipt2("d1"), granted2)
	t.equal("and the retry did not pay twice", session2.hatchTokens(payer), 5)
end
