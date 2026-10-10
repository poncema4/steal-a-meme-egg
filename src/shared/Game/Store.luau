--!strict
-- What a purchase does. Pure: the server calls these from MarketplaceService callbacks and tests call them directly.
-- Passes are permanent multipliers; products are consumed (instant-hatch tokens) or hand over a limited egg.
local Store = {}

export type Pass = { id: number, name: string, blurb: string, robux: number, effect: string, factor: number }
export type Product = { id: number, name: string, robux: number, kind: string, amount: number, tier: string? }
export type Catalog = { Passes: { [string]: Pass }, Products: { [string]: Product } }
export type Purchases = {
	passes: { [string]: boolean },
	receipts: { [string]: boolean },
	receiptOrder: { string },
	hatchTokens: number,
	pendingLimited: { string }, -- paid limited eggs waiting for a free slot
}

Store.MAX_RECEIPTS = 300

function Store.new(): Purchases
	return { passes = {}, receipts = {}, receiptOrder = {}, hatchTokens = 0, pendingLimited = {} }
end

function Store.passKey(catalog: Catalog, id: number): string?
	for key, pass in catalog.Passes do
		if pass.id ~= 0 and pass.id == id then
			return key
		end
	end
	return nil
end

function Store.productKey(catalog: Catalog, id: number): string?
	for key, product in catalog.Products do
		if product.id ~= 0 and product.id == id then
			return key
		end
	end
	return nil
end

-- Owning a pass turns its multiplier on. Returns false if it was already owned.
function Store.grantPass(p: Purchases, key: string): boolean
	if p.passes[key] then
		return false
	end
	p.passes[key] = true
	return true
end

-- The combined multipliers from owned passes: (luck, income, training).
function Store.multipliers(catalog: Catalog, p: Purchases): (number, number, number)
	local luck, income, train = 1, 1, 1
	for key, owned in p.passes do
		local pass = catalog.Passes[key]
		if owned and pass then
			if pass.effect == "luck" then
				luck *= pass.factor
			elseif pass.effect == "income" then
				income *= pass.factor
			elseif pass.effect == "train" then
				train *= pass.factor
			end
		end
	end
	return luck, income, train
end

export type Outcome = "granted" | "duplicate" | "unknown"
export type Effect = { kind: string, tier: string?, amount: number }

local function remember(p: Purchases, receiptId: string)
	p.receipts[receiptId] = true
	table.insert(p.receiptOrder, receiptId)
	while #p.receiptOrder > Store.MAX_RECEIPTS do
		local old = table.remove(p.receiptOrder, 1)
		if old then
			p.receipts[old] = nil
		end
	end
end

-- A developer-product receipt. Each receipt id pays once, however many times Roblox replays it. For a limited egg the
-- caller places the egg (or queues it); for hatch tokens this adds them.
function Store.grantProduct(catalog: Catalog, p: Purchases, productId: number, receiptId: string): (Outcome, Effect?)
	local key = Store.productKey(catalog, productId)
	local product = if key then catalog.Products[key] else nil
	if not product then
		return "unknown", nil
	end
	if p.receipts[receiptId] then
		return "duplicate", nil
	end
	remember(p, receiptId)
	if product.kind == "hatch" then
		p.hatchTokens += product.amount
	end
	return "granted", { kind = product.kind, tier = product.tier, amount = product.amount }
end

-- Spends one instant-hatch token. Returns false if there are none.
function Store.useToken(p: Purchases): boolean
	if p.hatchTokens <= 0 then
		return false
	end
	p.hatchTokens -= 1
	return true
end

function Store.queueLimited(p: Purchases, tier: string)
	table.insert(p.pendingLimited, tier)
end

-- Takes the oldest waiting limited egg, or nil.
function Store.popLimited(p: Purchases): string?
	return table.remove(p.pendingLimited, 1)
end

-- Every pass effect and product kind the catalogue uses is one the game understands (a typo would sell nothing).
function Store.invalid(catalog: Catalog): { string }
	local bad = {}
	for key, pass in catalog.Passes do
		if pass.effect ~= "luck" and pass.effect ~= "income" and pass.effect ~= "train" then
			table.insert(bad, `pass {key}: unknown effect {pass.effect}`)
		end
		if pass.factor < 1 then
			table.insert(bad, `pass {key}: factor below 1`)
		end
	end
	for key, product in catalog.Products do
		if product.kind ~= "hatch" and product.kind ~= "limited" then
			table.insert(bad, `product {key}: unknown kind {product.kind}`)
		end
		if product.kind == "limited" and not product.tier then
			table.insert(bad, `product {key}: limited product with no egg`)
		end
	end
	return bad
end

return Store
