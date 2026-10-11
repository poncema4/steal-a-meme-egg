--!nocheck
-- Every gamepass and developer product in the SHIPPED catalogue (the real Creator Hub ids in Config.Monetization) gives its benefit
-- when bought (Marco: "make sure the gamepasses work and if they buy it they get the benefits or the special egg"). Nothing here
-- swaps the catalogue: these are the ids players actually buy.
local Config = require("../../src/shared/Config")
local Fake = require("../fake/Roblox")

return function(t)
	local world = Fake.world()
	local market = world.service("MarketplaceService")
	assert(pcall(world.load, "src/server/main.server"))
	local session = world.load("src/server/Session")
	local money = Config.Monetization :: any
	local granted = world.enum.ProductPurchaseDecision.PurchaseGranted

	-- every pass: a buyer who completes the purchase gets the benefit, a player who did not buy gets nothing
	local userId = 300
	for key, pass in money.Passes do
		userId += 1
		local buyer = world.addPlayer(`Buyer_{key}`, userId)
		local other = world.addPlayer(`Other_{key}`, userId + 1000)
		world.advance(0.6)
		t.check(`{key}: has a real Creator Hub id`, pass.id ~= 0)
		local before = { session.passMultipliers(buyer) }
		local perksBefore = session.perks(buyer)
		market.PromptGamePassPurchaseFinished:Fire(buyer, pass.id, true)
		world.advance(0.2)
		t.check(`{key}: buying it turns it on`, session.purchases(buyer).passes[key] == true)
		t.check(`{key}: someone else does not get it`, session.purchases(other).passes[key] == nil)
		local after = { session.passMultipliers(buyer) }
		local perks = session.perks(buyer)
		local gained
		if pass.effect == "luck" then
			gained = after[1] > before[1]
		elseif pass.effect == "income" then
			gained = after[2] > before[2]
		elseif pass.effect == "train" then
			gained = after[3] > before[3]
		elseif pass.effect == "hatch" then
			gained = perks.hatch > perksBefore.hatch
		elseif pass.effect == "traps" then
			gained = perks.trapMax > perksBefore.trapMax
		elseif pass.effect == "bossSlow" then
			gained = perks.bossSlow > perksBefore.bossSlow
		end
		t.check(`{key} ({pass.effect}): its benefit is really on`, gained == true)
		-- owned on the next visit too
		world.removePlayer(buyer)
		market.owned[`{userId}:{pass.id}`] = true
		local back = world.addPlayer(`Back_{key}`, userId)
		world.advance(1)
		t.check(`{key}: still on when they come back`, session.purchases(back).passes[key] == true)
	end

	-- every product: the receipt is granted and the player gets the tokens or the limited egg
	local n = 0
	for key, product in money.Products do
		n += 1
		local p = world.addPlayer(`Prod_{key}`, 600 + n)
		world.advance(0.6)
		t.check(`{key}: has a real Creator Hub id`, product.id ~= 0)
		local tokens = session.hatchTokens(p)
		local decision =
			market.ProcessReceipt({ PlayerId = 600 + n, ProductId = product.id, PurchaseId = `real_{key}` })
		t.equal(`{key}: the receipt is granted`, decision, granted)
		if product.kind == "hatch" then
			t.equal(`{key}: gives {product.amount} instant hatches`, session.hatchTokens(p) - tokens, product.amount)
		elseif product.kind == "limited" then
			local got = false
			for _, item in session.get(p).base.slots do
				if item.kind == "egg" and item.tier == product.tier then
					got = true
				end
			end
			t.check(`{key}: the special egg is in their base`, got)
		end
	end
end
