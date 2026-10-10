--!strict
-- The shop screen: the limited egg on sale (with its stock and countdown), the passes, and the instant-hatch packs.
-- Items without a Creator Hub id are simply not listed. The client only sends a KEY; the server maps it to the real id.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Economy = require(ReplicatedStorage.Shared.Game.Economy)
local Eggs = require(ReplicatedStorage.Shared.Game.Eggs)
local Store = require(ReplicatedStorage.Shared.Game.Store)

local Shop = {}

local catalog: Store.Catalog = Config.Monetization :: any

local function text(parent: Instance, name: string, size: UDim2, position: UDim2, textSize: number): TextLabel
	local l = Instance.new("TextLabel")
	l.Name = name
	l.Size = size
	l.Position = position
	l.BackgroundTransparency = 1
	l.Font = Enum.Font.FredokaOne
	l.TextColor3 = Color3.new(1, 1, 1)
	l.TextSize = textSize
	l.TextXAlignment = Enum.TextXAlignment.Left
	l.Text = ""
	l.Parent = parent
	return l
end

local function button(parent: Instance, name: string, size: UDim2, position: UDim2, color: Color3): TextButton
	local b = Instance.new("TextButton")
	b.Name = name
	b.Size = size
	b.Position = position
	b.BackgroundColor3 = color
	b.BorderSizePixel = 0
	b.Font = Enum.Font.FredokaOne
	b.TextColor3 = Color3.new(1, 1, 1)
	b.TextSize = 20
	b.AutoButtonColor = true
	b.Text = ""
	b.Parent = parent
	return b
end

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

function Shop.start(player: Player)
	local remotes = ReplicatedStorage:WaitForChild("Remotes")
	local buyKey = remotes:WaitForChild("Buy") :: RemoteEvent
	local buyLimited = remotes:WaitForChild("BuyLimited") :: RemoteEvent

	local gui = Instance.new("ScreenGui")
	gui.Name = "RaidShop"
	gui.ResetOnSpawn = false
	gui.Parent = player:WaitForChild("PlayerGui")

	local open =
		button(gui, "ShopButton", UDim2.fromOffset(120, 44), UDim2.new(1, -136, 1, -64), Color3.fromRGB(255, 160, 20))
	open.Text = "SHOP"

	local panel = Instance.new("Frame")
	panel.Name = "Panel"
	panel.Size = UDim2.fromOffset(520, 460)
	panel.Position = UDim2.new(0.5, -260, 0.5, -230)
	panel.BackgroundColor3 = Color3.fromRGB(28, 28, 40)
	panel.BorderSizePixel = 0
	panel.Visible = false
	panel.Parent = gui
	text(panel, "Title", UDim2.new(1, -60, 0, 40), UDim2.fromOffset(20, 10), 30).Text = "SHOP"
	local close = button(panel, "Close", UDim2.fromOffset(40, 36), UDim2.new(1, -52, 0, 8), Color3.fromRGB(200, 60, 60))
	close.Text = "X"

	-- the limited egg card
	local limitedTitle = text(panel, "LimitedTitle", UDim2.new(1, -40, 0, 26), UDim2.fromOffset(20, 56), 22)
	limitedTitle.TextColor3 = Color3.fromRGB(255, 221, 68)
	local limitedInfo = text(panel, "LimitedInfo", UDim2.new(1, -40, 0, 22), UDim2.fromOffset(20, 84), 18)
	local limitedCoins =
		button(panel, "LimitedCoins", UDim2.fromOffset(240, 40), UDim2.fromOffset(20, 112), Color3.fromRGB(60, 160, 80))
	local limitedRobux = button(
		panel,
		"LimitedRobux",
		UDim2.fromOffset(200, 40),
		UDim2.fromOffset(280, 112),
		Color3.fromRGB(40, 120, 220)
	)
	limitedRobux.Visible = false

	-- everything below is a list of rows built from the catalogue (only items with a real id)
	local rows: { { key: string, kind: string, button: TextButton, name: string, robux: number } } = {}
	local y = 172
	local function section(title: string)
		local header = text(panel, "Section", UDim2.new(1, -40, 0, 24), UDim2.fromOffset(20, y), 20)
		header.TextColor3 = Color3.fromRGB(150, 220, 255)
		header.Text = title
		y += 28
	end
	local function addRows(kind: string, map: { [string]: { id: number, name: string, robux: number } })
		local any = false
		for _, key in sortedKeys(map) do
			local item = map[key]
			if item.id ~= 0 then
				if not any then
					section(if kind == "pass" then "BOOSTS" else "INSTANT HATCH")
					any = true
				end
				local b = button(
					panel,
					`Row_{key}`,
					UDim2.new(1, -40, 0, 40),
					UDim2.fromOffset(20, y),
					Color3.fromRGB(70, 70, 100)
				)
				table.insert(rows, { key = key, kind = kind, button = b, name = item.name, robux = item.robux })
				b.Activated:Connect(function()
					buyKey:FireServer(kind, key)
				end)
				y += 46
			end
		end
	end
	addRows("pass", catalog.Passes :: any)
	local hatchOnly: { [string]: Store.Product } = {}
	for key, product in catalog.Products do
		if product.kind == "hatch" then
			hatchOnly[key] = product
		end
	end
	addRows("product", hatchOnly :: any)

	open.Activated:Connect(function()
		panel.Visible = not panel.Visible
	end)
	close.Activated:Connect(function()
		panel.Visible = false
	end)
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
			limitedInfo.Text = `{left} left in the world, next egg in {clock(ends - workspace:GetServerTimeNow())}`
			limitedCoins.Text = if left > 0 then `Buy: {Economy.format(tier.price)} coins` else "SOLD OUT"
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
			row.button.Text = if own then `{row.name}: OWNED` else `{row.name}  R${row.robux}`
			row.button.BackgroundColor3 = if own then Color3.fromRGB(60, 130, 70) else Color3.fromRGB(70, 70, 100)
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
