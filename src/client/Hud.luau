--!strict
-- The screen you play on, laid out like the reference games (docs/REFERENCE.md): Shop / Index / Slow Mode down the left,
-- round icon buttons down the right, speed and money bottom-left, the terrain name on top, a People list (speed and money
-- per second) top-right, and while you carry an egg a big RUN banner with a Drop button. Everything it shows is an
-- attribute the server publishes. Sizes are design pixels: Ui.screen scales them to the real screen.
local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Economy = require(ReplicatedStorage.Shared.Game.Economy)
local Eggs = require(ReplicatedStorage.Shared.Game.Eggs)
local Events = require(ReplicatedStorage.Shared.Game.Events)
local Objective = require(ReplicatedStorage.Shared.Game.Objective)
local Rebirth = require(ReplicatedStorage.Shared.Game.Rebirth)
local UiScale = require(ReplicatedStorage.Shared.Game.UiScale)
local Ui = require(script.Parent.Ui)

local Hud = {}

export type Actions = {
	shop: (() -> ())?,
	index: (() -> ())?,
	eggs: (() -> ())?,
	pets: (() -> ())?,
	trophy: (() -> ())?,
}

local GREEN_TEXT = Color3.fromRGB(80, 255, 90)
local CYAN_TEXT = Color3.fromRGB(80, 220, 255)

local function clock(seconds: number): string
	seconds = math.max(0, math.floor(seconds))
	return string.format("%d:%02d", seconds // 60, seconds % 60)
end

local function number(player: Instance, name: string, default: number): number
	local v = player:GetAttribute(name)
	return if typeof(v) == "number" then v else default
end

local function box(parent: Instance, name: string, size: UDim2, position: UDim2, anchor: Vector2): Frame
	local f = Instance.new("Frame")
	f.Name = name
	f.Size = size
	f.Position = position
	f.AnchorPoint = anchor
	f.BackgroundTransparency = 1
	f.Parent = parent
	return f
end

function Hud.start(player: Player, actions: Actions?)
	local act: Actions = actions or {}
	Ui.hideDefaultList()
	local gui = Ui.screen(player, "Hud", 1)
	local remotes = ReplicatedStorage:WaitForChild("Remotes")

	-- left column: Shop, Index, Slow Mode
	local tapHeight = Ui.tap(gui, 52)
	local left = box(gui, "Left", UDim2.fromOffset(170, 220), UDim2.fromOffset(14, 70), Vector2.new(0, 0))
	local list = Instance.new("UIListLayout")
	list.Padding = UDim.new(0, 10)
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Parent = left
	local function leftButton(
		name: string,
		text: string,
		icon: string,
		palette: Ui.Palette,
		order: number,
		handler: () -> ()
	)
		local b = Ui.button(left, name, text, palette, UDim2.fromOffset(150, tapHeight))
		Ui.addIcon(b, icon, "left", "")
		b.LayoutOrder = order
		b.Activated:Connect(handler)
		return b
	end
	if act.shop then
		leftButton("ShopButton", "Shop", "cart", Ui.Palettes.Green, 1, act.shop)
	end
	if act.index then
		leftButton("IndexButton", "Index", "book", Ui.Palettes.Blue, 2, act.index)
	end
	local slow = Ui.button(left, "SlowToggle", "Slow Mode", Ui.Palettes.Grey, UDim2.fromOffset(150, Ui.tap(gui, 44)))
	slow.LayoutOrder = 3
	slow.TextSize = 20
	local slowRemote = remotes:WaitForChild("SlowMode") :: RemoteEvent
	slow.Activated:Connect(function()
		slowRemote:FireServer(player:GetAttribute("SlowMode") ~= true)
	end)

	-- right column: eggs, pets, trophy
	local side = Ui.tap(gui, 64)
	local right =
		box(gui, "Right", UDim2.fromOffset(side, side * 3 + 20), UDim2.new(1, -14, 0.5, 0), Vector2.new(1, 0.5))
	local rightList = Instance.new("UIListLayout")
	rightList.Padding = UDim.new(0, 10)
	rightList.SortOrder = Enum.SortOrder.LayoutOrder
	rightList.Parent = right
	local badges: { [string]: TextLabel } = {}
	local function iconButton(
		name: string,
		icon: string,
		glyph: string,
		palette: Ui.Palette,
		order: number,
		handler: (() -> ())?
	)
		if not handler then
			return
		end
		local b = Ui.iconButton(right, name, icon, glyph, palette, side)
		b.LayoutOrder = order
		b.Activated:Connect(handler)
		badges[name] = b:FindFirstChild("Badge") :: TextLabel
	end
	iconButton("EggsButton", "egg", "🥚", Ui.Palettes.Red, 1, act.eggs)
	iconButton("PetsButton", "paw", "🐾", Ui.Palettes.Orange, 2, act.pets)
	iconButton("TrophyButton", "trophy", "🏆", Ui.Palettes.Gold, 3, act.trophy)

	-- bottom-left: speed and money
	local stats = box(gui, "Stats", UDim2.fromOffset(420, 120), UDim2.new(0, 16, 1, -12), Vector2.new(0, 1))
	local speed = Ui.label(stats, "Speed", 40, CYAN_TEXT)
	speed.Size = UDim2.new(1, 0, 0, 48)
	speed.Position = UDim2.fromOffset(0, 0)
	speed.TextXAlignment = Enum.TextXAlignment.Left
	local money = Ui.label(stats, "Money", 52, GREEN_TEXT)
	money.Size = UDim2.new(1, 0, 0, 62)
	money.Position = UDim2.fromOffset(0, 54)
	money.TextXAlignment = Enum.TextXAlignment.Left
	local hasShoe = Ui.addIcon(speed, "shoe", "left", "", 60)
	Ui.addIcon(money, "cash", "left", "", 74)

	-- top centre: the terrain you are in, what to do next, and any live event
	local zone = Instance.new("Frame")
	zone.Name = "ZoneBanner"
	zone.AnchorPoint = Vector2.new(0.5, 0)
	zone.Position = UDim2.new(0.5, 0, 0, 10)
	zone.Size = UDim2.fromOffset(360, 48)
	zone.BackgroundColor3 = Color3.new(0, 0, 0)
	zone.BackgroundTransparency = 0.45
	zone.BorderSizePixel = 0
	zone.Parent = gui
	local zoneCorner = Instance.new("UICorner")
	zoneCorner.CornerRadius = UDim.new(0, 12)
	zoneCorner.Parent = zone
	local zoneName = Ui.label(zone, "Name", 34)
	zoneName.Size = UDim2.fromScale(1, 1)
	local objective = Ui.label(gui, "Objective", 20, Color3.fromRGB(255, 240, 150))
	objective.AnchorPoint = Vector2.new(0.5, 0)
	objective.Position = UDim2.new(0.5, 0, 0, 64)
	-- the middle third only, so a long hint wraps instead of running under the buttons and the People list
	objective.Size = UDim2.new(0.34, 0, 0, 44)
	objective.TextWrapped = true
	objective.TextYAlignment = Enum.TextYAlignment.Top
	local banner = Ui.label(gui, "Banner", 24, GREEN_TEXT)
	banner.AnchorPoint = Vector2.new(0.5, 0)
	banner.Position = UDim2.new(0.5, 0, 0, 112)
	banner.Size = UDim2.new(0.34, 0, 0, 30)

	-- carrying an egg: the big RUN banner and a Drop button
	local run = Instance.new("Frame")
	run.Name = "RunBanner"
	run.AnchorPoint = Vector2.new(0.5, 0)
	run.Position = UDim2.new(0.5, 0, 0, 150)
	run.Size = UDim2.fromOffset(280, 76)
	run.BackgroundColor3 = Color3.new(1, 1, 1)
	run.BorderSizePixel = 0
	run.Visible = false
	run.Parent = gui
	local runCorner = Instance.new("UICorner")
	runCorner.CornerRadius = UDim.new(0, 16)
	runCorner.Parent = run
	local runGradient = Instance.new("UIGradient")
	runGradient.Color = ColorSequence.new(Ui.Palettes.Red.top, Ui.Palettes.Red.bottom)
	runGradient.Rotation = 90
	runGradient.Parent = run
	local runStroke = Instance.new("UIStroke")
	runStroke.Thickness = 4
	runStroke.Color = Color3.new(0, 0, 0)
	runStroke.Parent = run
	local runText = Ui.label(run, "Text", 58)
	runText.Size = UDim2.fromScale(1, 1)
	runText.Text = "RUN!!"
	local dropRemote = remotes:WaitForChild("Drop") :: RemoteEvent
	local drop = Ui.button(gui, "DropButton", "🗑 Drop", Ui.Palettes.Red, UDim2.fromOffset(170, Ui.tap(gui, 52)))
	drop.AnchorPoint = Vector2.new(0.5, 1)
	drop.Position = UDim2.new(0.5, 0, 1, -96)
	drop.Visible = false
	drop.Activated:Connect(function()
		dropRemote:FireServer()
	end)

	-- the hotbar: three trap slots (keys 1-3, or tap). At most 3 traps are out at once, so a slot lights up for each one left.
	local trapRemote = remotes:WaitForChild("PlaceTrap") :: RemoteEvent
	local slotSide = Ui.tap(gui, 64)
	local hotbar = box(
		gui,
		"Hotbar",
		UDim2.fromOffset(slotSide * 3 + 20, slotSide),
		UDim2.new(0.5, 0, 1, -14),
		Vector2.new(0.5, 1)
	)
	local hotbarList = Instance.new("UIListLayout")
	hotbarList.FillDirection = Enum.FillDirection.Horizontal
	hotbarList.Padding = UDim.new(0, 10)
	hotbarList.SortOrder = Enum.SortOrder.LayoutOrder
	hotbarList.Parent = hotbar
	local trapSlots: { TextButton } = {}
	for i = 1, 3 do
		local slot = Ui.button(hotbar, `TrapSlot_{i}`, "", Ui.Palettes.Orange, UDim2.fromOffset(slotSide, slotSide))
		slot.LayoutOrder = i
		Ui.addIcon(slot, "trap", "center", "TRAP")
		slot.TextSize = 16
		local key = Ui.label(slot, "Key", 16)
		key.Position = UDim2.fromOffset(4, 0)
		key.Size = UDim2.fromOffset(20, 20)
		key.Text = tostring(i)
		slot.Activated:Connect(function()
			trapRemote:FireServer()
		end)
		trapSlots[i] = slot
	end
	ContextActionService:BindAction("PlaceTrap", function(_, state)
		if state == Enum.UserInputState.Begin then
			trapRemote:FireServer()
		end
		return Enum.ContextActionResult.Pass
	end, false, Enum.KeyCode.One, Enum.KeyCode.Two, Enum.KeyCode.Three, Enum.KeyCode.ButtonX)

	-- top right: who is fastest and richest
	local board = Instance.new("Frame")
	board.Name = "Leaderboard"
	board.AnchorPoint = Vector2.new(1, 0)
	board.Position = UDim2.new(1, -12, 0, 12)
	board.Size = UDim2.fromOffset(300, 30)
	board.BackgroundColor3 = Color3.fromRGB(20, 22, 30)
	board.BackgroundTransparency = 0.25
	board.BorderSizePixel = 0
	board.AutomaticSize = Enum.AutomaticSize.Y
	board.Parent = gui
	local boardCorner = Instance.new("UICorner")
	boardCorner.CornerRadius = UDim.new(0, 8)
	boardCorner.Parent = board
	local boardList = Instance.new("UIListLayout")
	boardList.SortOrder = Enum.SortOrder.LayoutOrder
	boardList.Parent = board
	local function row(name: string, order: number, a: string, b: string, c: string, color: Color3): Frame
		local r = Instance.new("Frame")
		r.Name = name
		r.LayoutOrder = order
		r.Size = UDim2.new(1, 0, 0, 24)
		r.BackgroundTransparency = 1
		r.Parent = board
		for i, text in { a, b, c } do
			local l = Instance.new("TextLabel")
			l.Name = `C{i}`
			l.BackgroundTransparency = 1
			l.Font = Ui.FONT
			l.TextSize = if order == 0 then 14 else 17
			l.TextColor3 = color
			l.Text = text
			l.TextXAlignment = if i == 1 then Enum.TextXAlignment.Left else Enum.TextXAlignment.Right
			l.Size = UDim2.fromScale(if i == 1 then 0.44 else 0.28, 1)
			l.Position = UDim2.fromScale(if i == 1 then 0.03 elseif i == 2 then 0.46 else 0.72, 0)
			l.Parent = r
		end
		return r
	end

	-- messages from the server
	local toast = Ui.label(gui, "Toast", 26)
	toast.AnchorPoint = Vector2.new(0.5, 1)
	toast.Position = UDim2.new(0.5, 0, 1, -90)
	toast.Size = UDim2.fromOffset(700, 40)
	local toastToken = 0
	local function show(text: string)
		toastToken += 1
		local mine = toastToken
		toast.Text = text
		task.delay(4, function()
			if toastToken == mine then
				toast.Text = ""
			end
		end)
	end
	local notice = remotes:WaitForChild("Notice") :: RemoteEvent
	local announce = remotes:WaitForChild("Announce") :: RemoteEvent
	notice.OnClientEvent:Connect(show)
	announce.OnClientEvent:Connect(show)

	local function leaderboard()
		for _, child in board:GetChildren() do
			if child:IsA("Frame") then
				child:Destroy()
			end
		end
		row("Header", 0, "People", "Speed", "Money/s", Color3.fromRGB(170, 175, 190))
		local people = Players:GetPlayers()
		table.sort(people, function(a, b)
			return number(a, "Income", 0) > number(b, "Income", 0)
		end)
		local camera = workspace.CurrentCamera
		local rows = UiScale.leaderboardRows(if camera then camera.ViewportSize.Y else 720, Ui.isTouch())
		for i = 1, math.min(#people, rows) do
			local p = people[i]
			row(
				`Row_{p.Name}`,
				i,
				p.DisplayName,
				Economy.format(number(p, "SpeedStat", 10)),
				Economy.format(number(p, "Income", 0)),
				if p == player then Color3.fromRGB(255, 240, 120) else Color3.new(1, 1, 1)
			)
		end
	end

	local function refresh()
		local coins = number(player, "Coins", 0)
		local rebirths = number(player, "Rebirths", 0)
		money.Text = "$" .. Economy.format(coins)
		speed.Text = (if hasShoe then "" else "👟 ")
			.. Economy.format(number(player, "SpeedStat", 10))
			.. (if rebirths > 0 then ` (x{Rebirth.multiplier(rebirths)})` else "")
		local isSlow = player:GetAttribute("SlowMode") == true
		slow.Text = if isSlow then "Slow Mode: ON" else "Slow Mode"
		Ui.setPalette(slow, if isSlow then Ui.Palettes.Green else Ui.Palettes.Grey)
		zoneName.Text = tostring(player:GetAttribute("Zone") or "Safe Zone")
		local mp = number(player, "MemePoints", 0)
		local level = number(player, "SpeedLevel", 0)
		local carrying = tostring(player:GetAttribute("Carrying") or "")
		local slots = number(player, "Slots", 6)
		local eggs, characters = number(player, "EggsHatching", 0), number(player, "Characters", 0)
		objective.Text = Objective.hint({
			carrying = carrying ~= "",
			eggs = eggs,
			characters = characters,
			freeSlots = slots - eggs - characters,
			coins = coins,
			mp = mp,
			speedLevel = level,
			canRebirth = Rebirth.can(rebirths, coins),
		})
		local def = if carrying ~= "" then Eggs.tier(carrying) else nil
		run.Visible = def ~= nil
		drop.Visible = def ~= nil
		runText.Text = "RUN!!"
		local placed = number(player, "TrapsPlaced", 0)
		local cooling = number(player, "TrapReadyAt", 0) > workspace:GetServerTimeNow()
		for i, slot in trapSlots do
			local ready = i <= 3 - placed and not cooling
			Ui.setPalette(slot, if ready then Ui.Palettes.Orange else Ui.Palettes.Grey)
		end
		local eggBadge = badges.EggsButton
		if eggBadge then
			eggBadge.Visible = eggs > 0
			eggBadge.Text = tostring(eggs)
		end
		local petBadge = badges.PetsButton
		if petBadge then
			petBadge.Visible = characters > 0
			petBadge.Text = tostring(characters)
		end
		local now = workspace:GetServerTimeNow()
		local active = tostring(ReplicatedStorage:GetAttribute("ActiveEvents") or "")
		local lines = {}
		for entry in string.gmatch(active, "[^,]+") do
			local id, ends = string.match(entry, "^(%w+):(%d+%.?%d*)$")
			local eventDef = id and Events.Defs[id]
			if eventDef and ends and tonumber(ends) :: number > now then
				table.insert(lines, `{eventDef.name}  {clock((tonumber(ends) :: number) - now)}`)
			end
		end
		banner.Text = table.concat(lines, "   ")
	end

	task.spawn(function()
		while true do
			refresh()
			leaderboard()
			task.wait(0.5)
		end
	end)
end

return Hud
