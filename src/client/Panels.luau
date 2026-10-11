--!strict
-- The three panels behind the HUD buttons: the Index (every character and which mutations you have seen), Eggs (what is
-- hatching, with Skip and Instant buttons) and Pets (the characters in your base and what each earns). Everything is read
-- from attributes the server publishes (Index, BaseItems, Coins...), so the panels never trust the client.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local BaseView = require(ReplicatedStorage.Shared.Game.BaseView)
local Collection = require(ReplicatedStorage.Shared.Game.Collection)
local Economy = require(ReplicatedStorage.Shared.Game.Economy)
local Eggs = require(ReplicatedStorage.Shared.Game.Eggs)
local Bats = require(ReplicatedStorage.Shared.Game.Bats)
local Zones = require(ReplicatedStorage.Shared.Game.Zones)
local Ui = require(script.Parent.Ui)

local Panels = {}

local RARITY_COLORS: { [string]: Color3 } = {
	Common = Color3.fromRGB(150, 150, 165),
	Rare = Color3.fromRGB(70, 150, 255),
	Epic = Color3.fromRGB(180, 80, 255),
	Legendary = Color3.fromRGB(255, 170, 40),
	Mythic = Color3.fromRGB(255, 70, 90),
}
local MUTATION_COLORS: { [string]: Color3 } = {
	Gold = Color3.fromRGB(255, 205, 40),
	Rainbow = Color3.fromRGB(255, 110, 200),
}
local CARD = Color3.fromRGB(46, 46, 60)

local function corner(parent: Instance, radius: number)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, radius)
	c.Parent = parent
end

local function frame(parent: Instance, name: string, size: UDim2, color: Color3?): Frame
	local f = Instance.new("Frame")
	f.Name = name
	f.Size = size
	f.BorderSizePixel = 0
	f.BackgroundColor3 = color or CARD
	f.BackgroundTransparency = if color then 0 else 0
	f.Parent = parent
	return f
end

local function scroller(parent: Instance, name: string, position: UDim2, size: UDim2): ScrollingFrame
	local s = Instance.new("ScrollingFrame")
	s.Name = name
	s.Position = position
	s.Size = size
	s.BackgroundTransparency = 1
	s.BorderSizePixel = 0
	s.ScrollBarThickness = 6
	s.AutomaticCanvasSize = Enum.AutomaticSize.Y
	s.CanvasSize = UDim2.new()
	s.Parent = parent
	return s
end

local function attr(player: Player, name: string): string
	local v = player:GetAttribute(name)
	return if typeof(v) == "string" then v else ""
end

local function number(player: Player, name: string): number
	local v = player:GetAttribute(name)
	return if typeof(v) == "number" then v else 0
end

-- the Index is grouped by world: each terrain shows the characters its eggs hatch, weakest first, then the limited ones
type Section = { title: string, name: string, zoneId: string, characters: { Eggs.Character } }

local function sections(): { Section }
	local byWorld: { [string]: { Eggs.Character } } = {}
	local function add(world: string, tiers: { Eggs.Tier })
		for _, tier in tiers do
			for _, entry in tier.pool do
				local c = Eggs.character(entry.id)
				if c then
					byWorld[world] = byWorld[world] or {}
					table.insert(byWorld[world], c)
				end
			end
		end
	end
	for _, zone in Zones.List do
		local tiers = {}
		for _, tier in Eggs.Tiers do
			local home = Zones.forTier(tier.id)
			if home and home.id == zone.id then
				table.insert(tiers, tier)
			end
		end
		add(zone.id, tiers)
	end
	add("Limited", Eggs.LimitedTiers)
	local list: { Section } = {}
	for _, zone in Zones.List do
		table.insert(
			list,
			{ title = string.upper(zone.name), name = zone.name, zoneId = zone.id, characters = byWorld[zone.id] or {} }
		)
	end
	table.insert(
		list,
		{ title = "LIMITED EGGS", name = "Limited", zoneId = "Limited", characters = byWorld.Limited or {} }
	)
	for _, section in list do
		table.sort(section.characters, function(a, b)
			return a.income < b.income
		end)
	end
	return list
end

function Panels.start(player: Player): { index: () -> (), eggs: () -> (), pets: () -> (), trophy: () -> () }
	local gui = Ui.screen(player, "Panels", 4)
	local remotes = ReplicatedStorage:WaitForChild("Remotes")
	local action = remotes:WaitForChild("BaseAction") :: RemoteEvent

	-- ---------------------------------------------------------------- Index
	local indexPanel = Ui.panel(gui, "INDEX", 720, 540)
	local progress = Ui.label(indexPanel.body, "Progress", 22, Color3.fromRGB(255, 240, 150))
	progress.Size = UDim2.new(1, 0, 0, 30)
	-- one long list you scroll down: a section per world, each on its world's own colours (its ground fading into its sky),
	-- with the world's name, how many you have found, what finishing it pays (coins and a better bat), then its characters
	local cards = scroller(indexPanel.body, "Cards", UDim2.fromOffset(0, 34), UDim2.new(1, 0, 1, -34))
	local stack = Instance.new("UIListLayout")
	stack.Padding = UDim.new(0, 12)
	stack.SortOrder = Enum.SortOrder.LayoutOrder
	stack.Parent = cards
	type Card = {
		root: Frame,
		portrait: Frame,
		letter: TextLabel,
		picture: ImageLabel?,
		view: ViewportFrame?,
		name: TextLabel,
		income: TextLabel,
		chips: { [string]: TextLabel },
		char: Eggs.Character,
	}
	local cardList: { Card } = {}
	type SectionView =
		{ title: string, zoneId: string, header: TextLabel, reward: TextLabel, grid: Frame, total: number }
	local sectionViews: { SectionView } = {}
	local order = 0
	local LIMITED_THEME = { ground = { 120, 60, 170 }, sky = { 255, 150, 60 } }
	for sectionNumber, section in sections() do
		local zone = Zones.get(section.zoneId)
		local theme = if zone then zone else LIMITED_THEME
		local ground, sky = theme.ground :: { number }, theme.sky :: { number }
		local holder = Instance.new("Frame")
		holder.Name = `Section_{sectionNumber}`
		holder.BackgroundColor3 = Color3.fromRGB(ground[1], ground[2], ground[3])
		holder.BorderSizePixel = 0
		holder.Size = UDim2.new(1, -8, 0, 0)
		holder.AutomaticSize = Enum.AutomaticSize.Y
		holder.LayoutOrder = sectionNumber
		holder.Parent = cards
		corner(holder, 14)
		local gradient = Instance.new("UIGradient")
		gradient.Rotation = 90
		gradient.Color = ColorSequence.new(
			Color3.fromRGB(sky[1], sky[2], sky[3]),
			Color3.fromRGB(math.floor(ground[1] * 0.75), math.floor(ground[2] * 0.75), math.floor(ground[3] * 0.75))
		)
		gradient.Parent = holder
		local stroke = Instance.new("UIStroke")
		stroke.Thickness = 3
		stroke.Color = Color3.new(0, 0, 0)
		stroke.Parent = holder
		local pad = Instance.new("UIPadding")
		pad.PaddingTop, pad.PaddingBottom = UDim.new(0, 8), UDim.new(0, 10)
		pad.PaddingLeft, pad.PaddingRight = UDim.new(0, 10), UDim.new(0, 10)
		pad.Parent = holder
		local column = Instance.new("UIListLayout")
		column.Padding = UDim.new(0, 4)
		column.SortOrder = Enum.SortOrder.LayoutOrder
		column.Parent = holder
		local header = Ui.label(holder, "Header", 26)
		header.LayoutOrder = 1
		header.Size = UDim2.new(1, 0, 0, 32)
		header.TextXAlignment = Enum.TextXAlignment.Left
		local rewardLine = Ui.label(holder, "Reward", 16, Color3.fromRGB(255, 245, 190))
		rewardLine.LayoutOrder = 2
		rewardLine.Size = UDim2.new(1, 0, 0, 22)
		rewardLine.TextXAlignment = Enum.TextXAlignment.Left
		rewardLine.TextWrapped = true
		local gridFrame = Instance.new("Frame")
		gridFrame.Name = "Grid"
		gridFrame.LayoutOrder = 3
		gridFrame.BackgroundTransparency = 1
		gridFrame.Size = UDim2.fromScale(1, 0)
		gridFrame.AutomaticSize = Enum.AutomaticSize.Y
		gridFrame.Parent = holder
		sectionViews[sectionNumber] = {
			title = section.name,
			zoneId = section.zoneId,
			header = header,
			reward = rewardLine,
			grid = gridFrame,
			total = #section.characters,
		}
		local grid = Instance.new("UIGridLayout")
		grid.CellSize = UDim2.fromOffset(150, 168)
		grid.CellPadding = UDim2.fromOffset(10, 10)
		grid.SortOrder = Enum.SortOrder.LayoutOrder
		grid.Parent = gridFrame
		for _, c in section.characters do
			order += 1
			local root = frame(gridFrame, `Card_{c.id}`, UDim2.fromOffset(150, 168))
			root.LayoutOrder = order
			corner(root, 10)
			local portrait =
				frame(root, "Portrait", UDim2.fromOffset(78, 78), RARITY_COLORS[c.rarity] or RARITY_COLORS.Common)
			portrait.AnchorPoint = Vector2.new(0.5, 0)
			portrait.Position = UDim2.new(0.5, 0, 0, 8)
			corner(portrait, 12)
			local letter = Ui.label(portrait, "Letter", 44)
			letter.Size = UDim2.fromScale(1, 1)
			-- the portrait: a rendered picture where we have one (a black silhouette until discovered), else the letter tile
			local picture: ImageLabel? = nil
			local view = Ui.modelView(portrait, "Pets", c.id)
			if view then
				letter.Visible = false
			end
			local artId = Ui.petIconId(c.id)
			if artId and not view then
				local image = Instance.new("ImageLabel")
				image.Name = "Picture"
				image.BackgroundTransparency = 1
				image.Size = UDim2.fromScale(1.05, 1.05)
				image.Position = UDim2.fromScale(-0.025, -0.025)
				image.Image = artId
				image.ScaleType = Enum.ScaleType.Fit
				image.Parent = portrait
				letter.Visible = false
				picture = image
			end
			local name = Ui.label(root, "Name", 17)
			name.Position = UDim2.fromOffset(0, 90)
			name.Size = UDim2.new(1, 0, 0, 22)
			name.TextScaled = true
			local income = Ui.label(root, "Income", 16, Color3.fromRGB(80, 255, 90))
			income.Position = UDim2.fromOffset(0, 114)
			income.Size = UDim2.new(1, 0, 0, 20)
			local chips: { [string]: TextLabel } = {}
			for i, mutation in { "Gold", "Rainbow" } do
				local chip = Ui.label(root, `Chip_{mutation}`, 13, MUTATION_COLORS[mutation])
				chip.Size = UDim2.fromOffset(66, 18)
				chip.Position = UDim2.fromOffset(6 + (i - 1) * 72, 140)
				chips[mutation] = chip
			end
			table.insert(cardList, {
				root = root,
				portrait = portrait,
				letter = letter,
				picture = picture,
				view = view,
				name = name,
				income = income,
				chips = chips,
				char = c,
			})
		end
	end

	local function refreshSections()
		local found = Collection.decode(attr(player, "Index"))
		local claims: { [string]: boolean } = {}
		local claimedCount = 0
		for id in string.gmatch(attr(player, "IndexClaims"), "[^,]+") do
			claims[id] = true
			claimedCount += 1
		end
		local nextBat = Bats.get(claimedCount + 1).name
		for _, view in sectionViews do
			local count, total = Collection.worldProgress(found, view.zoneId)
			if view.zoneId == "Limited" then
				count, total = 0, view.total
				for _, card in cardList do
					if card.root.Parent == view.grid and Collection.has(found, card.char.id) then
						count += 1
					end
				end
			end
			local done = claims[view.zoneId] == true
			view.header.Text = `{string.upper(view.title)}   {count}/{total}{if done then "  ✓" else ""}`
			local tier = Eggs.tier(((Zones.get(view.zoneId) or { eggs = { "" } }).eggs :: { string })[1])
			if view.zoneId == "Limited" then
				view.reward.Text = "Limited eggs come and go in the shop: collect them while you can."
			elseif done then
				view.reward.Text = "Complete! Reward claimed: coins and a better bat."
			elseif tier then
				view.reward.Text =
					`Find all {view.total}: win {Economy.format(tier.price * Config.Index.RewardEggs)} coins and the {nextBat}`
			end
		end
	end

	local function refreshIndex()
		refreshSections()
		local found = Collection.decode(attr(player, "Index"))
		local count, total = Collection.progress(found)
		progress.Text = `Discovered {count} / {total}`
		for _, card in cardList do
			local seen = Collection.has(found, card.char.id)
			card.name.Text = if seen then card.char.name else "???"
			card.letter.Text = if seen then string.sub(card.char.name, 1, 1) else "?"
			if card.view then
				Ui.silhouette(card.view, not seen)
			end
			if card.picture then
				card.picture.ImageColor3 = if seen then Color3.new(1, 1, 1) else Color3.new(0, 0, 0) -- undiscovered: a silhouette
			end
			card.portrait.BackgroundColor3 = if seen
				then (RARITY_COLORS[card.char.rarity] or RARITY_COLORS.Common)
				else Color3.fromRGB(70, 70, 84)
			card.income.Text = if seen then `+{Economy.format(card.char.income)}/s` else ""
			for mutation, chip in card.chips do
				local has = seen and Collection.hasMutation(found, card.char.id, mutation)
				chip.Text = if has then `✓ {mutation}` else mutation
				chip.TextTransparency = if has then 0 else 0.7
			end
		end
	end

	-- ---------------------------------------------------------------- Eggs
	local eggsPanel = Ui.panel(gui, "EGGS", 600, 460)
	local eggsNote = Ui.label(eggsPanel.body, "Note", 18, Color3.fromRGB(255, 240, 150))
	eggsNote.Size = UDim2.new(1, 0, 0, 26)
	local eggList = scroller(eggsPanel.body, "Rows", UDim2.fromOffset(0, 32), UDim2.new(1, 0, 1, -32))
	local eggLayout = Instance.new("UIListLayout")
	eggLayout.Padding = UDim.new(0, 8)
	eggLayout.SortOrder = Enum.SortOrder.LayoutOrder
	eggLayout.Parent = eggList
	type EggRow = { root: Frame, title: TextLabel, timer: TextLabel, instant: TextButton, picture: ImageLabel }
	local eggRows: { [number]: EggRow } = {}
	local hatchProducts = false
	for _, product in (Config.Monetization :: any).Products :: { [string]: { kind: string, id: number } } do
		if product.kind == "hatch" and product.id ~= 0 then
			hatchProducts = true
		end
	end

	local function newEggRow(slot: number): EggRow
		local root = frame(eggList, `EggRow_{slot}`, UDim2.new(1, -8, 0, Ui.tap(gui, 64)))
		root.LayoutOrder = slot
		corner(root, 10)
		-- the egg's own picture on the left
		local picture = Instance.new("ImageLabel")
		picture.Name = "Picture"
		picture.BackgroundTransparency = 1
		picture.Size = UDim2.fromOffset(52, 52)
		picture.Position = UDim2.fromOffset(8, 6)
		picture.ScaleType = Enum.ScaleType.Fit
		picture.Parent = root
		local title = Ui.label(root, "Title", 22)
		title.Position = UDim2.fromOffset(68, 4)
		title.Size = UDim2.new(0.4, 0, 0, 28)
		title.TextXAlignment = Enum.TextXAlignment.Left
		local timer = Ui.label(root, "Timer", 17, Color3.fromRGB(170, 220, 255))
		timer.Position = UDim2.fromOffset(68, 32)
		timer.Size = UDim2.new(0.45, 0, 0, 24)
		timer.TextXAlignment = Enum.TextXAlignment.Left
		local instant = Ui.button(root, "Instant", "Instant", Ui.Palettes.Gold, UDim2.fromOffset(110, Ui.tap(gui, 36)))
		instant.AnchorPoint = Vector2.new(1, 0.5)
		instant.Position = UDim2.new(1, -10, 0.5, 0)
		instant.TextSize = 18
		instant.Activated:Connect(function()
			action:FireServer("instant", slot)
		end)
		return { root = root, title = title, timer = timer, instant = instant, picture = picture }
	end

	local function refreshEggs()
		local rows = BaseView.decode(attr(player, "BaseItems"))
		local seen: { [number]: boolean } = {}
		local count = 0
		local tokens = number(player, "HatchTokens")
		for _, row in rows do
			if row.kind == "egg" then
				count += 1
				seen[row.slot] = true
				local entry = eggRows[row.slot]
				if not entry then
					entry = newEggRow(row.slot)
					eggRows[row.slot] = entry
				end
				local tier = Eggs.tier(row.id)
				local left = row.secondsLeft or 0
				local mutated = row.mutation ~= nil and row.mutation ~= "Normal"
				entry.title.Text = (if mutated then `{row.mutation} ` else "") .. (if tier then tier.name else row.id)
				entry.title.TextColor3 = (if row.mutation then MUTATION_COLORS[row.mutation] else nil)
					or Color3.new(1, 1, 1)
				entry.timer.Text = `hatching in {left}s`
				entry.picture.Image = (Config.EggIcons :: { [string]: string })[row.id] or ""
				entry.instant.Visible = tokens > 0 or hatchProducts
				entry.instant.Text = if tokens > 0 then `Instant ({tokens})` else "Instant"
			end
		end
		for slot, entry in eggRows do
			if not seen[slot] then
				entry.root:Destroy()
				eggRows[slot] = nil
			end
		end
		eggsNote.Text = if count == 0
			then "No eggs hatching. Steal one from a guardian in the Wilds!"
			else `{count} hatching`
	end

	-- ---------------------------------------------------------------- Pets
	local petsPanel = Ui.panel(gui, "PETS", 600, 460)
	local petsNote = Ui.label(petsPanel.body, "Note", 18, Color3.fromRGB(80, 255, 90))
	petsNote.Size = UDim2.new(1, 0, 0, 26)
	local petList = scroller(petsPanel.body, "Rows", UDim2.fromOffset(0, 32), UDim2.new(1, 0, 1, -32))
	local petLayout = Instance.new("UIListLayout")
	petLayout.Padding = UDim.new(0, 8)
	petLayout.SortOrder = Enum.SortOrder.LayoutOrder
	petLayout.Parent = petList
	local petRows: { [number]: { root: Frame, title: TextLabel, income: TextLabel, picture: ImageLabel, view: ViewportFrame? } } =
		{}

	local function refreshPets()
		local rows = BaseView.decode(attr(player, "BaseItems"))
		local seen: { [number]: boolean } = {}
		local count = 0
		for _, row in rows do
			if row.kind == "char" then
				count += 1
				seen[row.slot] = true
				local entry = petRows[row.slot]
				if not entry then
					local root = frame(petList, `PetRow_{row.slot}`, UDim2.new(1, -8, 0, Ui.tap(gui, 56)))
					root.LayoutOrder = row.slot
					corner(root, 10)
					local picture = Instance.new("ImageLabel")
					picture.Name = "Picture"
					picture.BackgroundTransparency = 1
					picture.Size = UDim2.fromOffset(48, 48)
					picture.Position = UDim2.new(0, 8, 0.5, -24)
					picture.ScaleType = Enum.ScaleType.Fit
					picture.Parent = root
					local holder = frame(root, "ModelHolder", UDim2.fromOffset(52, 52))
					holder.BackgroundTransparency = 1
					holder.Position = UDim2.new(0, 6, 0.5, -26)
					local view = Ui.modelView(holder, "Pets", row.id)
					if view then
						picture.Visible = false
					end
					local title = Ui.label(root, "Title", 22)
					title.Position = UDim2.fromOffset(64, 0)
					title.Size = UDim2.fromScale(0.55, 1)
					title.TextXAlignment = Enum.TextXAlignment.Left
					local income = Ui.label(root, "Income", 22, Color3.fromRGB(80, 255, 90))
					income.AnchorPoint = Vector2.new(1, 0)
					income.Position = UDim2.new(1, -12, 0, 0)
					income.Size = UDim2.fromScale(0.34, 1)
					income.TextXAlignment = Enum.TextXAlignment.Right
					entry = { root = root, title = title, income = income, picture = picture, view = view }
					petRows[row.slot] = entry
				end
				local c = Eggs.character(row.id)
				entry.picture.Image = Ui.petIconId(row.id) or ""
				local mutation = row.mutation or "Normal"
				local multiplier = Eggs.Mutations[mutation] or 1
				entry.title.Text = (if c then c.name else row.id)
					.. (if mutation ~= "Normal" then `  ({mutation})` else "")
				entry.title.TextColor3 = MUTATION_COLORS[mutation] or Color3.new(1, 1, 1)
				entry.income.Text = `+{Economy.format(if c then c.income * multiplier else 0)}/s`
			end
		end
		for slot, entry in petRows do
			if not seen[slot] then
				entry.root:Destroy()
				petRows[slot] = nil
			end
		end
		petsNote.Text = if count == 0
			then "No pets yet. Hatch an egg!"
			else `{count} pets  |  base income +{Economy.format(number(player, "Income"))}/s  |  {number(
				player,
				"Slots"
			)} slots`
	end

	-- ---------------------------------------------------------------- Trophy: who is ahead in this server
	local trophyPanel = Ui.panel(gui, "TOP PLAYERS", 600, 460)
	local trophyList = scroller(trophyPanel.body, "Rows", UDim2.fromOffset(0, 0), UDim2.fromScale(1, 1))
	local trophyLayout = Instance.new("UIListLayout")
	trophyLayout.Padding = UDim.new(0, 6)
	trophyLayout.SortOrder = Enum.SortOrder.LayoutOrder
	trophyLayout.Parent = trophyList

	local function refreshTrophy()
		for _, child in trophyList:GetChildren() do
			if child:IsA("Frame") then
				child:Destroy()
			end
		end
		local people = Players:GetPlayers()
		table.sort(people, function(a, b)
			return number(a, "SpeedStat") > number(b, "SpeedStat")
		end)
		local function row(name: string, place: number, cells: { string }, color: Color3)
			local r = frame(
				trophyList,
				name,
				UDim2.new(1, -8, 0, Ui.tap(gui, 40)),
				if place == 0 then Color3.fromRGB(30, 30, 42) else nil
			)
			r.LayoutOrder = place
			corner(r, 8)
			Ui.tableCells(r, cells, if place == 0 then 15 else 19, color)
		end
		row("Header", 0, { "Player", "Speed", "Money/s", "Rebirths" }, Color3.fromRGB(170, 175, 190))
		for i, p in people do
			row(`Row_{p.Name}`, i, {
				p.DisplayName,
				Economy.speed(number(p, "SpeedStat")),
				Economy.format(number(p, "Income")),
				tostring(number(p, "Rebirths")),
			}, if p == player then Color3.fromRGB(255, 240, 120) else Color3.new(1, 1, 1))
		end
	end

	task.spawn(function()
		while true do
			if indexPanel.isOpen() then
				refreshIndex()
			end
			if eggsPanel.isOpen() then
				refreshEggs()
			end
			if petsPanel.isOpen() then
				refreshPets()
			end
			if trophyPanel.isOpen() then
				refreshTrophy()
			end
			task.wait(0.4)
		end
	end)
	-- show fresh numbers the moment a panel opens, not 0.4 s later
	local function opening(panel: Ui.Panel, refresh: () -> ()): () -> ()
		return function()
			panel.toggle()
			if panel.isOpen() then
				refresh()
			end
		end
	end
	return {
		index = opening(indexPanel, refreshIndex),
		eggs = opening(eggsPanel, refreshEggs),
		pets = opening(petsPanel, refreshPets),
		trophy = opening(trophyPanel, refreshTrophy),
	}
end

return Panels
