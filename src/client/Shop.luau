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

	-- the limited egg: sold for Robux only. A banner with the egg, its stock and countdown, one Robux button, and the pets it can
	-- hatch: hover one (or tap it on a phone) to see its stats
	local banner = Instance.new("Frame")
	banner.Name = "LimitedCard"
	banner.BackgroundColor3 = Color3.fromRGB(74, 52, 120)
	banner.BorderSizePixel = 0
	banner.Parent = list
	round(banner, 14)
	outline(banner)
	local bannerArt = Ui.label(banner, "Art", 40)
	bannerArt.Size = UDim2.fromOffset(90, 90)
	bannerArt.Position = UDim2.fromOffset(12, 12)
	bannerArt.Text = ""
	local bannerPicture = Instance.new("ImageLabel")
	bannerPicture.Name = "Picture"
	bannerPicture.BackgroundTransparency = 1
	bannerPicture.Size = UDim2.fromScale(1, 1)
	bannerPicture.ScaleType = Enum.ScaleType.Fit
	bannerPicture.Parent = bannerArt
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
	-- the right of the picture is laid out top to bottom so nothing can overlap: the title, the stock line, the pets it can hatch
	-- (with their stats beside them), then the Buy button. Every row starts below the one above it, and the button's REAL height
	-- (a phone makes it taller) decides how tall the banner is.
	local limitedTitle = line(banner, "LimitedTitle", 120, 8, 340, 30, 24, Color3.fromRGB(255, 221, 68))
	limitedTitle.Size = UDim2.new(1, -130, 0, 30)
	limitedTitle.TextScaled = true
	local limitedInfo = line(banner, "LimitedInfo", 120, 40, 340, 20, 16)
	limitedInfo.Size = UDim2.new(1, -130, 0, 20)
	local PET_Y, PET_H, PET_STEP = 64, 48, 58
	local petRow = Instance.new("Frame")
	petRow.Name = "Pets"
	petRow.BackgroundTransparency = 1
	petRow.Position = UDim2.fromOffset(120, PET_Y)
	petRow.Size = UDim2.fromOffset(PET_STEP * 3, PET_H)
	petRow.Parent = banner
	local statsX = 120 + PET_STEP * 3 + 8
	local petStats = line(banner, "PetStats", statsX, PET_Y, 200, PET_H, 15, Color3.fromRGB(220, 225, 245))
	petStats.Size = UDim2.new(1, -(statsX + 10), 0, PET_H)
	petStats.TextWrapped = true
	petStats.TextScaled = true
	local statsMax = Instance.new("UITextSizeConstraint")
	statsMax.MaxTextSize = 15
	statsMax.Parent = petStats
	petStats.Text = "Hover a pet to see its stats"
	local limitedRobux =
		Ui.button(banner, "LimitedRobux", "", Ui.Palettes.Purple, UDim2.fromOffset(132, Ui.tap(gui, 30)))
	limitedRobux.Position = UDim2.fromOffset(120, PET_Y + PET_H + 10)
	-- the price always fills the small button legibly (it scales to the button, up to 20 px)
	limitedRobux.TextScaled = true
	local buyMax = Instance.new("UITextSizeConstraint")
	buyMax.MaxTextSize = 20
	buyMax.Parent = limitedRobux
	local buyPad = Instance.new("UIPadding")
	buyPad.PaddingTop, buyPad.PaddingBottom = UDim.new(0, 4), UDim.new(0, 4)
	buyPad.PaddingLeft, buyPad.PaddingRight = UDim.new(0, 8), UDim.new(0, 8)
	buyPad.Parent = limitedRobux
	local BANNER_H = math.max(12 + 90, PET_Y + PET_H + 10 + limitedRobux.Size.Y.Offset) + 12
	banner.Size = UDim2.new(1, -8, 0, BANNER_H)
	local petButtons: { ImageButton } = {}
	local shownTier = ""

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
	local y = BANNER_H + 14
	-- compact cards, four to a row (Marco: the things inside the shop should be smaller). The card's height follows its button's
	-- real height (taller on a phone), so the blurb always sits above the button, never under it.
	local COLS, CARD_W, GAP = 4, 124, 10
	local BUTTON_H = Ui.tap(gui, 22) -- slim: purple R$ price until bought, then a green OWNED
	local BLURB_Y, BLURB_H = 94, 42
	local CARD_H = BLURB_Y + BLURB_H + 6 + BUTTON_H + 6
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
			local col, row = (i - 1) % COLS, (i - 1) // COLS
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
			art.Size = UDim2.fromOffset(62, 62)
			art.Position = UDim2.new(0.5, -31, 0, 6)
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
			local name = Ui.label(card, "Name", 17)
			name.Size = UDim2.new(1, -8, 0, 22)
			name.Position = UDim2.fromOffset(4, 70)
			name.TextScaled = true
			name.Text = item.name
			local blurb = Ui.label(card, "Blurb", 12, Color3.fromRGB(200, 205, 225))
			blurb.Size = UDim2.new(1, -10, 0, BLURB_H)
			blurb.Position = UDim2.fromOffset(5, BLURB_Y)
			blurb.TextWrapped = true
			blurb.TextScaled = true -- a long blurb shrinks to fit its box instead of running under the button
			local blurbMax = Instance.new("UITextSizeConstraint")
			blurbMax.MaxTextSize = 12
			blurbMax.Parent = blurb
			blurb.TextYAlignment = Enum.TextYAlignment.Top
			blurb.Text = item.blurb or ""
			local b = Ui.button(card, `Row_{key}`, "", Ui.Palettes.Purple, UDim2.new(0.62, 0, 0, BUTTON_H))
			b.AnchorPoint = Vector2.new(0.5, 1)
			b.Position = UDim2.new(0.5, 0, 1, -6)
			b.TextSize = 13
			table.insert(rows, { key = key, kind = kind, button = b, name = item.name, robux = item.robux })
			b.Activated:Connect(function()
				buyKey:FireServer(kind, key)
			end)
		end
		y += math.ceil(#keys / COLS) * (CARD_H + GAP) + 6
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

	limitedRobux.Activated:Connect(function()
		if ((ReplicatedStorage:GetAttribute("LimitedLeft") :: number?) or 0) <= 0 then
			return -- sold out
		end
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
			bannerPicture.Image = (Config.EggIcons :: { [string]: string })[tier.id]
				or Ui.petIconId((tier.pool[#tier.pool] or { id = "" }).id)
				or ""
			-- the pets this egg can hatch, rebuilt when the egg changes
			if shownTier ~= tier.id then
				shownTier = tier.id
				for _, b in petButtons do
					b:Destroy()
				end
				table.clear(petButtons)
				local total = 0
				for _, entry in tier.pool do
					total += entry.weight
				end
				for i, entry in tier.pool do
					local c = Eggs.character(entry.id)
					local b = Instance.new("ImageButton")
					b.Name = `Pet_{entry.id}`
					b.Size = UDim2.fromOffset(52, 48)
					b.Position = UDim2.fromOffset((i - 1) * 58, 0)
					b.BackgroundColor3 = Color3.fromRGB(46, 34, 80)
					b.Image = Ui.petIconId(entry.id) or ""
					b.ScaleType = Enum.ScaleType.Fit
					b.Parent = petRow
					round(b, 10)
					local stats = if c
						then `{c.name}: {c.rarity}, {math.floor(entry.weight / total * 100 + 0.5)}% chance, +{Economy.format(
							c.income
						)}/s`
						else entry.id
					local function show()
						petStats.Text = stats
					end
					b.MouseEnter:Connect(show)
					b.Activated:Connect(show) -- a tap on a phone, a press on a gamepad
					b.SelectionGained:Connect(show)
					table.insert(petButtons, b)
				end
				petStats.Text = "Hover a pet to see its stats"
			end
			limitedInfo.Text = `{left} left in the world, next egg in {clock(ends - workspace:GetServerTimeNow())}`
			limitedRobux.Text = "SOLD OUT"
			Ui.setPalette(limitedRobux, Ui.Palettes.Grey)
			for _, product in catalog.Products do
				if product.kind == "limited" and product.tier == tier.id and product.id ~= 0 and left > 0 then
					limitedRobux.Text = `Buy R${product.robux}`
					Ui.setPalette(limitedRobux, Ui.Palettes.Purple) -- a Robux buy is purple, like every pass that is not owned yet
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
