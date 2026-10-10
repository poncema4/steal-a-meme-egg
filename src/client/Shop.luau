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

	local function line(name: string, y: number, height: number, textSize: number, color: Color3?): TextLabel
		local l = Ui.label(body, name, textSize, color)
		l.Position = UDim2.fromOffset(0, y)
		l.Size = UDim2.new(1, 0, 0, height)
		l.TextXAlignment = Enum.TextXAlignment.Left
		return l
	end

	-- the limited egg card
	local limitedTitle = line("LimitedTitle", 0, 30, 24, Color3.fromRGB(255, 221, 68))
	local limitedInfo = line("LimitedInfo", 32, 24, 17)
	local limitedCoins = Ui.button(body, "LimitedCoins", "", Ui.Palettes.Green, UDim2.fromOffset(250, Ui.tap(gui, 46)))
	limitedCoins.Position = UDim2.fromOffset(0, 64)
	local limitedRobux = Ui.button(body, "LimitedRobux", "", Ui.Palettes.Blue, UDim2.fromOffset(210, Ui.tap(gui, 46)))
	limitedRobux.Position = UDim2.fromOffset(264, 64)
	limitedRobux.Visible = false

	-- everything below is a list of rows built from the catalogue (only items with a real id)
	local rows: { { key: string, kind: string, button: TextButton, name: string, robux: number } } = {}
	local y = 128
	local function section(title: string)
		line("Section", y, 26, 20, Color3.fromRGB(150, 220, 255)).Text = title
		y += 30
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
				local b = Ui.button(body, `Row_{key}`, "", Ui.Palettes.Grey, UDim2.new(1, 0, 0, Ui.tap(gui, 44)))
				b.Position = UDim2.fromOffset(0, y)
				b.TextSize = 20
				table.insert(rows, { key = key, kind = kind, button = b, name = item.name, robux = item.robux })
				b.Activated:Connect(function()
					buyKey:FireServer(kind, key)
				end)
				y += Ui.tap(gui, 44) + 8
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
			row.button.Text = if own then `{row.name}: OWNED` else `{row.name}  R${row.robux}`
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
