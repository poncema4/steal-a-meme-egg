--!strict
-- The shop screen: the limited egg on sale (with its stock and countdown), the passes, and the instant-hatch packs.
-- Items without a Creator Hub id are simply not listed. The client only sends a KEY; the server maps it to the real id.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Economy = require(ReplicatedStorage.Shared.Game.Economy)
local Eggs = require(ReplicatedStorage.Shared.Game.Eggs)
local Store = require(ReplicatedStorage.Shared.Game.Store)
local Ui = require(script.Parent.Ui)

local Shop = {}

local catalog: Store.Catalog = Config.Monetization :: any

local function clock(seconds: number): string
	seconds = math.max(0, math.floor(seconds))
	return string.format("%d:%02d", seconds // 60, seconds % 60)
end

local function sortedKeys(map: { [string]: any }): { string }
	local keys = {}
	for key in map do
		table.insert(keys, key)
	end
	table.sort(keys, function(a, b)
		return (map[a].robux :: number) < (map[b].robux :: number)
	end)
	return keys
end

-- Opens or closes the shop (the Shop button on the HUD calls this). A no-op until Shop.start has run.
Shop.toggle = function() end

function Shop.start(player: Player)
	local remotes = ReplicatedStorage:WaitForChild("Remotes")
	local buyKey = remotes:WaitForChild("Buy") :: RemoteEvent
	local buyLimited = remotes:WaitForChild("BuyLimited") :: RemoteEvent

	local gui = Ui.screen(player, "Shop", 5)
	local panel = Ui.panel(gui, "SHOP", 560, 520)
	Shop.toggle = panel.toggle
	local body = panel.body

	local CARD = Color3.fromRGB(46, 46, 62)
	local function round(inst: Instance, radius: number)
		local c = Instance.new("UICorner")
		c.CornerRadius = UDim.new(0, radius)
		c.Parent = inst
	end
	local function outline(inst: Instance)
		local st = Instance.new("UIStroke")
		st.Thickness = 3
		st.Color = Color3.new(0, 0, 0)
		st.Parent = inst
	end

	-- everything scrolls, so a phone can reach every card
	local list = Instance.new("ScrollingFrame")
	list.Name = "List"
	list.BackgroundTransparency = 1
	list.BorderSizePixel = 0
	list.Size = UDim2.fromScale(1, 1)
	list.ScrollBarThickness = 6
	list.Parent = body

	-- the limited egg: a banner with the pet that hatches from it, the stock and the countdown
	local banner = Instance.new("Frame")
	banner.Name = "LimitedCard"
	banner.Size = UDim2.new(1, -8, 0, 124)
	banner.BackgroundColor3 = Color3.fromRGB(74, 52, 120)
	banner.BorderSizePixel = 0
	banner.Parent = list
	round(banner, 14)
	outline(banner)
	local bannerArt = Ui.label(banner, "Art", 40)
	bannerArt.Size = UDim2.fromOffset(100, 100)
	bannerArt.Position = UDim2.fromOffset(10, 12)
	bannerArt.Text = "?"
	local bannerPet: ViewportFrame? = nil
	local function line(
		parent: Instance,
		name: string,
		x: number,
		y: number,
		w: number,
		h: number,
		size: number,
		color: Color3?
	)
		local l = Ui.label(parent, name, size, color)
		l.Position = UDim2.fromOffset(x, y)
		l.Size = UDim2.fromOffset(w, h)
		l.TextXAlignment = Enum.TextXAlignment.Left
		return l
	end
	local limitedTitle = line(banner, "LimitedTitle", 120, 8, 400, 30, 24, Color3.fromRGB(255, 221, 68))
	local limitedInfo = line(banner, "LimitedInfo", 120, 38, 400, 22, 16)
	local limitedCoins =
		Ui.button(banner, "LimitedCoins", "", Ui.Palettes.Green, UDim2.fromOffset(210, Ui.tap(gui, 42)))
	limitedCoins.Position = UDim2.fromOffset(120, 72)
	local limitedRobux = Ui.button(banner, "LimitedRobux", "", Ui.Palettes.Blue, UDim2.fromOffset(150, Ui.tap(gui, 42)))
	limitedRobux.Position = UDim2.fromOffset(340, 72)
	limitedRobux.Visible = false

	-- the shop lists are grids of item cards built from the catalogue (only items with a real id): a picture, the name, what it
	-- does and a buy button
	local rows: { { key: string, kind: string, button: TextButton, name: string, robux: number } } = {}
	local ICONS: { [string]: string } = {
		coins2x = "cash",
		vip = "trophy",
		luck2x = "potion",
		train2x = "shoe",
		fastHatch = "egg",
		trapMaster = "trap",
		bossSlow = "paw",
		hatch1 = "egg",
		hatch5 = "egg",
	}
	local y = 124 + 14
	local CARD_W, CARD_H, GAP = 166, 240, 10
	local function section(title: string)
		local l = line(list, "Section", 4, y, 400, 26, 20, Color3.fromRGB(150, 220, 255))
		l.Text = title
		y += 32
	end
	local function addCards(
		kind: string,
		map: { [string]: { id: number, name: string, robux: number, blurb: string? } },
		title: string
	)
		local keys = {}
		for _, key in sortedKeys(map) do
			if map[key].id ~= 0 then
				table.insert(keys, key)
			end
		end
		if #keys == 0 then
			return
		end
		section(title)
		for i, key in keys do
			local item = map[key]
			local col, row = (i - 1) % 3, (i - 1) // 3
			local card = Instance.new("Frame")
			card.Name = `Card_{key}`
			card.Size = UDim2.fromOffset(CARD_W, CARD_H)
			card.Position = UDim2.fromOffset(col * (CARD_W + GAP), y + row * (CARD_H + GAP))
			card.BackgroundColor3 = CARD
			card.BorderSizePixel = 0
			card.Parent = list
			round(card, 14)
			outline(card)
			local art = Ui.label(card, "Art", 40)
			art.Size = UDim2.fromOffset(92, 92)
			art.Position = UDim2.new(0.5, -46, 0, 6)
			-- the card's own picture (a sticker with the pass's art), else a HUD icon
			local pictureId = (Config.ShopArt :: { [string]: string })[key]
			if pictureId then
				local picture = Instance.new("ImageLabel")
				picture.Name = "Picture"
				picture.BackgroundTransparency = 1
				picture.Size = UDim2.fromScale(1, 1)
				picture.Image = pictureId
				picture.ScaleType = Enum.ScaleType.Fit
				picture.Parent = art
				art.Text = ""
			else
				Ui.addIcon(art, ICONS[key] or "egg", "center", "?")
			end
			local name = Ui.label(card, "Name", 20)
			name.Size = UDim2.new(1, -8, 0, 26)
			name.Position = UDim2.fromOffset(4, 102)
			name.TextScaled = true
			name.Text = item.name
			local blurb = Ui.label(card, "Blurb", 13, Color3.fromRGB(200, 205, 225))
			blurb.Size = UDim2.new(1, -12, 0, 62)
			blurb.Position = UDim2.fromOffset(6, 130)
			blurb.TextWrapped = true
			blurb.TextYAlignment = Enum.TextYAlignment.Top
			blurb.Text = item.blurb or ""
			local b = Ui.button(card, `Row_{key}`, "", Ui.Palettes.Purple, UDim2.new(1, -16, 0, Ui.tap(gui, 38)))
			b.AnchorPoint = Vector2.new(0.5, 1)
			b.Position = UDim2.new(0.5, 0, 1, -8)
			b.TextSize = 20
			table.insert(rows, { key = key, kind = kind, button = b, name = item.name, robux = item.robux })
			b.Activated:Connect(function()
				buyKey:FireServer(kind, key)
			end)
		end
		y += math.ceil(#keys / 3) * (CARD_H + GAP) + 6
	end
	-- three sections of passes: boosts that multiply things, perks that change how you play
	local boosts: { [string]: Store.Pass } = {}
	local perks: { [string]: Store.Pass } = {}
	for key, pass in catalog.Passes do
		if pass.effect == "luck" or pass.effect == "income" or pass.effect == "train" then
			boosts[key] = pass
		else
			perks[key] = pass
		end
	end
	addCards("pass", boosts :: any, "BOOSTS")
	addCards("pass", perks :: any, "PERKS")
	local hatchOnly: { [string]: Store.Product } = {}
	for key, product in catalog.Products do
		if product.kind == "hatch" then
			hatchOnly[key] = product
		end
	end
	addCards("product", hatchOnly :: any, "INSTANT HATCH")
	list.CanvasSize = UDim2.fromOffset(0, y)

	limitedCoins.Activated:Connect(function()
		buyLimited:FireServer()
	end)
	limitedRobux.Activated:Connect(function()
		for key, product in catalog.Products do
			if
				product.kind == "limited"
				and product.tier == ReplicatedStorage:GetAttribute("LimitedTier")
				and product.id ~= 0
			then
				buyKey:FireServer("product", key)
			end
		end
	end)

	local function refresh()
		local tierId = ReplicatedStorage:GetAttribute("LimitedTier")
		local tier = if typeof(tierId) == "string" then Eggs.tier(tierId) else nil
		if tier then
			local left = (ReplicatedStorage:GetAttribute("LimitedLeft") :: number?) or 0
			local ends = (ReplicatedStorage:GetAttribute("LimitedEnds") :: number?) or 0
			limitedTitle.Text = `LIMITED: {tier.name}`
			-- the banner shows the pet this egg hatches (its most common one), as a 3D model
			if bannerPet and bannerPet:GetAttribute("For") ~= tier.id then
				bannerPet:Destroy()
				bannerPet = nil
			end
			if not bannerPet and tier.pool[1] then
				local view = Ui.modelView(bannerArt, "Pets", tier.pool[1].id)
				if view then
					view:SetAttribute("For", tier.id)
					bannerArt.Text = ""
					bannerPet = view
				end
			end
			limitedInfo.Text = `{left} left in the world, next egg in {clock(ends - workspace:GetServerTimeNow())}`
			limitedCoins.Text = if left > 0 then `Buy: {Economy.format(tier.price)} coins` else "SOLD OUT"
			Ui.setPalette(limitedCoins, if left > 0 then Ui.Palettes.Green else Ui.Palettes.Grey)
			limitedRobux.Visible = false
			for _, product in catalog.Products do
				if product.kind == "limited" and product.tier == tier.id and product.id ~= 0 and left > 0 then
					limitedRobux.Visible = true
					limitedRobux.Text = `R${product.robux}`
				end
			end
		end
		local owned = "," .. tostring(player:GetAttribute("Passes") or "") .. ","
		for _, row in rows do
			local own = row.kind == "pass" and string.find(owned, "," .. row.key .. ",", 1, true) ~= nil
			row.button.Text = if own then "OWNED" else `R$ {row.robux}`
			Ui.setPalette(row.button, if own then Ui.Palettes.Green else Ui.Palettes.Purple)
		end
	end

	task.spawn(function()
		while true do
			refresh()
			task.wait(0.5)
		end
	end)
end

return Shop
