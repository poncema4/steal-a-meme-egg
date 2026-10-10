--!strict
-- Robux purchases: game passes (checked when a player joins and when one is bought) and developer products (instant-hatch
-- tokens, limited eggs). A purchase is only acknowledged to Roblox once the player is SAVED, so a failed save makes Roblox
-- retry the receipt instead of the player losing what they paid for; receipt ids are remembered so a replay never pays twice.
-- What each purchase does is in Shared/Game/Store; this file only talks to Roblox.
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Eggs = require(ReplicatedStorage.Shared.Game.Eggs)
local Limited = require(ReplicatedStorage.Shared.Game.Limited)
local Store = require(ReplicatedStorage.Shared.Game.Store)
local LimitedService = require(script.Parent.LimitedService)
local Session = require(script.Parent.Session)

local PurchaseService = {}

local notify: (Player, string) -> () = function(_player: Player, _text: string) end
local pendingHatch: { [Player]: number } = {} -- the slot someone is buying an instant hatch for

local function catalog(): Store.Catalog
	return Session.catalog()
end

local function grantOwnedPasses(player: Player)
	local purchases = Session.purchases(player)
	if not purchases then
		return
	end
	local changed = false
	for key, pass in catalog().Passes do
		if pass.id ~= 0 and not purchases.passes[key] then
			local ok, owns = pcall(function()
				return MarketplaceService:UserOwnsGamePassAsync(player.UserId, pass.id)
			end)
			if ok and owns and Store.grantPass(purchases, key) then
				changed = true
			end
		end
	end
	if changed then
		Session.changed(player)
	end
end

-- Can this player get an instant hatch right now (a token, or a product to buy)?
function PurchaseService.instantAvailable(player: Player): boolean
	if Session.hatchTokens(player) > 0 then
		return true
	end
	local product = catalog().Products.hatch1
	return product ~= nil and product.id ~= 0
end

-- The "Instant hatch" prompt on an egg: spends a token if there is one, otherwise offers the Robux product.
function PurchaseService.instantHatch(player: Player, slot: number)
	if Session.hatchTokens(player) > 0 then
		local _, message = Session.useHatchToken(player, slot)
		notify(player, message)
		return
	end
	local product = catalog().Products.hatch1
	if product and product.id ~= 0 then
		pendingHatch[player] = slot
		MarketplaceService:PromptProductPurchase(player, product.id)
	end
end

local function applyEffect(player: Player, effect: Store.Effect)
	if effect.kind == "hatch" then
		local slot = pendingHatch[player]
		pendingHatch[player] = nil
		if slot then
			local ok, message = Session.useHatchToken(player, slot)
			if ok then
				notify(player, message)
				return
			end
		end
		notify(player, `+{effect.amount} instant hatch`)
		Session.changed(player)
	elseif effect.kind == "limited" and effect.tier then
		local key = Limited.current(Session.now()).key
		LimitedService.claimStock(key) -- the player paid, so they get it even if the last one just went
		local purchases = Session.purchases(player)
		if not Session.grantEgg(player, effect.tier) and purchases then
			Store.queueLimited(purchases, effect.tier)
			notify(player, "Your limited egg is waiting for a free slot!")
			Session.changed(player)
		else
			local tier = Eggs.tier(effect.tier)
			notify(player, `You got a {if tier then tier.name else "limited egg"}!`)
		end
	end
end

-- `override` lets a test sell things with real-looking ids (the shipped catalogue keeps 0 until Creator Hub ids exist).
function PurchaseService.start(remotes: Folder, notifyFn: (Player, string) -> (), override: Store.Catalog?)
	notify = notifyFn
	if override then
		Session.setCatalog(override)
	end
	local buy = Instance.new("RemoteEvent")
	buy.Name = "Buy"
	buy.Parent = remotes
	local last: { [Player]: number } = {}

	-- the client asks to buy something by KEY; the server maps it to the real id (a client never sends an id)
	buy.OnServerEvent:Connect(function(player: Player, kind: any, key: any)
		if typeof(kind) ~= "string" or typeof(key) ~= "string" then
			return
		end
		local now = os.clock()
		if now - (last[player] or -10) < 1 then
			return
		end
		last[player] = now
		if kind == "pass" then
			local pass = catalog().Passes[key]
			if not pass then
				return
			end
			if pass.id == 0 then
				notify(player, "Not for sale yet")
			else
				MarketplaceService:PromptGamePassPurchase(player, pass.id)
			end
		elseif kind == "product" then
			local product = catalog().Products[key]
			if not product then
				return
			end
			if product.id == 0 then
				notify(player, "Not for sale yet")
			else
				MarketplaceService:PromptProductPurchase(player, product.id)
			end
		end
	end)

	MarketplaceService.PromptGamePassPurchaseFinished:Connect(
		function(player: Player, passId: number, purchased: boolean)
			local purchases = Session.purchases(player)
			local key = Store.passKey(catalog(), passId)
			if purchased and purchases and key and Store.grantPass(purchases, key) then
				Session.changed(player)
				Session.save(player)
				notify(player, "Thank you! Your pass is on.")
			end
		end
	)

	MarketplaceService.PromptProductPurchaseFinished:Connect(
		function(userId: number, _productId: number, purchased: boolean)
			if not purchased then
				local player = Players:GetPlayerByUserId(userId)
				if player then
					pendingHatch[player] = nil
				end
			end
		end
	)

	MarketplaceService.ProcessReceipt = function(info)
		local player = Players:GetPlayerByUserId(info.PlayerId)
		local purchases = if player then Session.purchases(player) else nil
		if not player or not purchases then
			return Enum.ProductPurchaseDecision.NotProcessedYet
		end
		local outcome, effect = Store.grantProduct(catalog(), purchases, info.ProductId, tostring(info.PurchaseId))
		if outcome == "unknown" then
			return Enum.ProductPurchaseDecision.NotProcessedYet
		end
		if outcome == "granted" and effect then
			applyEffect(player, effect)
		end
		-- acknowledged only once saved, for both a first receipt and a replay of one that did not save last time
		if not Session.save(player) then
			return Enum.ProductPurchaseDecision.NotProcessedYet
		end
		return Enum.ProductPurchaseDecision.PurchaseGranted
	end

	Session.onLoaded(function(player)
		task.spawn(grantOwnedPasses, player)
	end)
end

return PurchaseService
