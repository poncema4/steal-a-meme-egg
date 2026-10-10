--!strict
-- The three panels behind the HUD buttons: the Index (every character and which mutations you have seen), Eggs (what is
-- hatching, with Skip and Instant buttons) and Pets (the characters in your base and what each earns). Everything is read
-- from attributes the server publishes (Index, BaseItems, Coins...), so the panels never trust the client.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local BaseView = require(ReplicatedStorage.Shared.Game.BaseView)
local Collection = require(ReplicatedStorage.Shared.Game.Collection)
local Economy = require(ReplicatedStorage.Shared.Game.Economy)
local Eggs = require(ReplicatedStorage.Shared.Game.Eggs)
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

-- every character in the game, weakest first
local function allCharacters(): { Eggs.Character }
	local list = {}
	for _, c in Eggs.Characters do
		table.insert(list, c)
	end
	table.sort(list, function(a, b)
		return a.income < b.income
	end)
	return list
end

function Panels.start(player: Player): { index: () -> (), eggs: () -> (), pets: () -> () }
	local gui = Ui.screen(player, "Panels", 4)
	local remotes = ReplicatedStorage:WaitForChild("Remotes")
	local action = remotes:WaitForChild("BaseAction") :: RemoteEvent

	-- ---------------------------------------------------------------- Index
	local indexPanel = Ui.panel(gui, "INDEX", 720, 540)
	local progress = Ui.label(indexPanel.body, "Progress", 22, Color3.fromRGB(255, 240, 150))
	progress.Size = UDim2.new(1, 0, 0, 30)
	local cards = scroller(indexPanel.body, "Cards", UDim2.fromOffset(0, 36), UDim2.new(1, 0, 1, -36))
	local grid = Instance.new("UIGridLayout")
	grid.CellSize = UDim2.fromOffset(150, 168)
	grid.CellPadding = UDim2.fromOffset(10, 10)
	grid.SortOrder = Enum.SortOrder.LayoutOrder
	grid.Parent = cards
	type Card = {
		root: Frame,
		portrait: Frame,
		letter: TextLabel,
		name: TextLabel,
		income: TextLabel,
		chips: { [string]: TextLabel },
		char: Eggs.Character,
	}
	local cardList: { Card } = {}
	for order, c in allCharacters() do
		local root = frame(cards, `Card_{c.id}`, UDim2.fromOffset(150, 168))
		root.LayoutOrder = order
		corner(root, 10)
		local portrait =
			frame(root, "Portrait", UDim2.fromOffset(78, 78), RARITY_COLORS[c.rarity] or RARITY_COLORS.Common)
		portrait.AnchorPoint = Vector2.new(0.5, 0)
		portrait.Position = UDim2.new(0.5, 0, 0, 8)
		corner(portrait, 12)
		local letter = Ui.label(portrait, "Letter", 44)
		letter.Size = UDim2.fromScale(1, 1)
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
		table.insert(
			cardList,
			{ root = root, portrait = portrait, letter = letter, name = name, income = income, chips = chips, char = c }
		)
	end

	local function refreshIndex()
		local found = Collection.decode(attr(player, "Index"))
		local count, total = Collection.progress(found)
		progress.Text = `Discovered {count} / {total}`
		for _, card in cardList do
			local seen = Collection.has(found, card.char.id)
			card.name.Text = if seen then card.char.name else "???"
			card.letter.Text = if seen then string.sub(card.char.name, 1, 1) else "?"
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
	type EggRow = { root: Frame, title: TextLabel, timer: TextLabel, skip: TextButton, instant: TextButton }
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
		local title = Ui.label(root, "Title", 22)
		title.Position = UDim2.fromOffset(12, 4)
		title.Size = UDim2.new(0.45, 0, 0, 28)
		title.TextXAlignment = Enum.TextXAlignment.Left
		local timer = Ui.label(root, "Timer", 17, Color3.fromRGB(170, 220, 255))
		timer.Position = UDim2.fromOffset(12, 32)
		timer.Size = UDim2.new(0.45, 0, 0, 24)
		timer.TextXAlignment = Enum.TextXAlignment.Left
		local skip = Ui.button(root, "Skip", "", Ui.Palettes.Green, UDim2.fromOffset(120, Ui.tap(gui, 44)))
		skip.AnchorPoint = Vector2.new(1, 0.5)
		skip.Position = UDim2.new(1, -140, 0.5, 0)
		skip.TextSize = 18
		local instant = Ui.button(root, "Instant", "Instant", Ui.Palettes.Gold, UDim2.fromOffset(120, Ui.tap(gui, 44)))
		instant.AnchorPoint = Vector2.new(1, 0.5)
		instant.Position = UDim2.new(1, -10, 0.5, 0)
		instant.TextSize = 18
		skip.Activated:Connect(function()
			action:FireServer("skip", slot)
		end)
		instant.Activated:Connect(function()
			action:FireServer("instant", slot)
		end)
		return { root = root, title = title, timer = timer, skip = skip, instant = instant }
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
				entry.title.Text = if tier then tier.name else row.id
				entry.timer.Text = `hatching in {left}s`
				entry.skip.Text = if tier
					then `Skip {Economy.format(Economy.skipCost(tier.price, left, tier.hatchSeconds))}`
					else "Skip"
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
	local petRows: { [number]: { root: Frame, title: TextLabel, income: TextLabel } } = {}

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
					local title = Ui.label(root, "Title", 22)
					title.Position = UDim2.fromOffset(12, 0)
					title.Size = UDim2.fromScale(0.62, 1)
					title.TextXAlignment = Enum.TextXAlignment.Left
					local income = Ui.label(root, "Income", 22, Color3.fromRGB(80, 255, 90))
					income.AnchorPoint = Vector2.new(1, 0)
					income.Position = UDim2.new(1, -12, 0, 0)
					income.Size = UDim2.fromScale(0.34, 1)
					income.TextXAlignment = Enum.TextXAlignment.Right
					entry = { root = root, title = title, income = income }
					petRows[row.slot] = entry
				end
				local c = Eggs.character(row.id)
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
	}
end

return Panels
