--!strict
-- The screen you play on, laid out like the reference games (docs/REFERENCE.md): Shop / Index / Slow Mode down the left,
-- round icon buttons down the right, speed and money bottom-left, the terrain name on top, a People list (speed and money
-- per second) top-right, and while you carry an egg a big RUN banner with a Drop button. Everything it shows is an
-- attribute the server publishes. Sizes are design pixels: Ui.screen scales them to the real screen.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Economy = require(ReplicatedStorage.Shared.Game.Economy)
local Eggs = require(ReplicatedStorage.Shared.Game.Eggs)
local Events = require(ReplicatedStorage.Shared.Game.Events)
local Objective = require(ReplicatedStorage.Shared.Game.Objective)
local Progression = require(ReplicatedStorage.Shared.Game.Progression)
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

-- "3m 16s", or just "45s" under a minute: how the reference's event clock reads
local function clock(seconds: number): string
	seconds = math.max(0, math.floor(seconds))
	if seconds < 60 then
		return `{seconds}s`
	end
	return `{seconds // 60}m {seconds % 60}s`
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
	local left = box(gui, "Left", UDim2.fromOffset(190, 200), UDim2.new(0, 14, 0.34, 0), Vector2.new(0, 0))
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
		-- like the reference: the picture on the left, the word big and bold right next to it, nothing cut off
		local b = Ui.button(left, name, text, palette, UDim2.fromOffset(176, tapHeight))
		Ui.addIcon(b, icon, "left", "", tapHeight + 8, tapHeight - 6)
		b.TextSize = 28
		b.TextXAlignment = Enum.TextXAlignment.Left
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
	-- Slow Mode is a small switch with a label, like the reference: a dark track, a green knob when it is on
	local slow = Instance.new("TextButton")
	slow.Name = "SlowToggle"
	slow.LayoutOrder = 3
	slow.Size = UDim2.fromOffset(176, Ui.tap(gui, 40))
	slow.BackgroundTransparency = 1
	slow.AutoButtonColor = false
	slow.Selectable = true
	slow.Font = Ui.FONT
	slow.TextSize = 17
	slow.TextColor3 = Color3.new(1, 1, 1)
	slow.TextXAlignment = Enum.TextXAlignment.Left
	slow.Text = "Slow Mode"
	slow.Parent = left
	local slowPad = Instance.new("UIPadding")
	slowPad.PaddingLeft = UDim.new(0, 62)
	slowPad.Parent = slow
	local slowTrack = Instance.new("Frame")
	slowTrack.Name = "Track"
	slowTrack.Size = UDim2.fromOffset(52, 28)
	-- centred on the label's line (the label's padding insets its children too: step back out of it)
	slowTrack.AnchorPoint = Vector2.new(0, 0.5)
	slowTrack.Position = UDim2.new(0, -62, 0.5, 0)
	slowTrack.BackgroundColor3 = Color3.fromRGB(70, 60, 58)
	slowTrack.BorderSizePixel = 0
	slowTrack.Parent = slow
	local slowTrackCorner = Instance.new("UICorner")
	slowTrackCorner.CornerRadius = UDim.new(0, 8)
	slowTrackCorner.Parent = slowTrack
	local slowTrackStroke = Instance.new("UIStroke")
	slowTrackStroke.Thickness = 3
	slowTrackStroke.Color = Color3.new(0, 0, 0)
	slowTrackStroke.Parent = slowTrack
	local slowKnob = Instance.new("Frame")
	slowKnob.Name = "Knob"
	slowKnob.Size = UDim2.fromOffset(24, 22)
	slowKnob.Position = UDim2.fromOffset(3, 3)
	slowKnob.BackgroundColor3 = Color3.fromRGB(60, 235, 60)
	slowKnob.BorderSizePixel = 0
	slowKnob.Parent = slowTrack
	local slowKnobCorner = Instance.new("UICorner")
	slowKnobCorner.CornerRadius = UDim.new(0, 6)
	slowKnobCorner.Parent = slowKnob
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
	local hasShoe = Ui.addIcon(speed, "shoe", "left", "", 80, 64)
	Ui.addIcon(money, "cash", "left", "", 92, 76)

	-- top centre: the terrain you are in, what to do next, and any live event
	local zone = Instance.new("Frame")
	zone.Name = "ZoneBanner"
	zone.AnchorPoint = Vector2.new(0.5, 0)
	zone.Position = UDim2.new(0.5, 0, 0, 50)
	zone.Size = UDim2.fromOffset(620, 60)
	zone.BackgroundColor3 = Color3.fromRGB(10, 20, 30)
	zone.BackgroundTransparency = 0.45
	-- like the reference, the band fades out toward both ends
	local fade = Instance.new("UIGradient")
	fade.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.25, 0),
		NumberSequenceKeypoint.new(0.75, 0),
		NumberSequenceKeypoint.new(1, 1),
	})
	fade.Parent = zone
	zone.BorderSizePixel = 0
	zone.Parent = gui
	local zoneName = Ui.label(zone, "Name", 46, Color3.fromRGB(235, 235, 235))
	zoneName.Size = UDim2.fromScale(1, 1)
	local objective = Ui.label(gui, "Objective", 20, Color3.fromRGB(255, 240, 150))
	objective.AnchorPoint = Vector2.new(0.5, 0)
	objective.Position = UDim2.new(0.5, 0, 0, 112)
	-- the middle third only, so a long hint wraps instead of running under the buttons and the People list
	objective.Size = UDim2.new(0.34, 0, 0, 44)
	objective.TextWrapped = true
	objective.TextYAlignment = Enum.TextYAlignment.Top
	local banner = Ui.label(gui, "Banner", 24, GREEN_TEXT)
	banner.AnchorPoint = Vector2.new(0.5, 0)
	banner.Position = UDim2.new(0.5, 0, 0, 160)
	banner.Size = UDim2.new(0.34, 0, 0, 30)

	-- carrying an egg: the big RUN banner and a Drop button
	local run = Instance.new("Frame")
	run.Name = "RunBanner"
	run.AnchorPoint = Vector2.new(0.5, 0)
	run.Position = UDim2.new(0.5, 0, 0, 190)
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

	-- the items (bat, trap) are ordinary Roblox tools in Roblox's own backpack bar at the bottom middle; the event clock keeps
	-- clear of a two-item bar
	local startCamera = workspace.CurrentCamera
	local viewport = if startCamera then startCamera.ViewportSize else Vector2.new(1280, 720)
	local designWidth = viewport.X / UiScale.factor(viewport.X, viewport.Y, Ui.isTouch())
	local bar = UiScale.bottomBar(designWidth, 2, Ui.tap(gui, 46))

	-- bottom right: the event clock (what is on now and how long it lasts, else what comes next and in how long)
	local eventClock = Instance.new("Frame")
	eventClock.Name = "EventClock"
	eventClock.AnchorPoint = Vector2.new(1, 1)
	eventClock.Position = UDim2.new(1, -16, 1, -12)
	eventClock.Size = UDim2.fromOffset(bar.clockWidth, 60)
	eventClock.BackgroundTransparency = 1
	eventClock.Parent = gui
	local clockIcon = Ui.label(eventClock, "ClockIcon", 30)
	clockIcon.AnchorPoint = Vector2.new(1, 0.5)
	clockIcon.Position = UDim2.fromScale(1, 0.5)
	clockIcon.Size = UDim2.fromOffset(56, 56)
	Ui.addIcon(clockIcon, "clock", "center", "")
	local clockText = Ui.label(eventClock, "ClockText", 34, Color3.new(1, 1, 1))
	clockText.AnchorPoint = Vector2.new(1, 0.5)
	clockText.Position = UDim2.new(1, -62, 0.5, 0)
	-- one line tall: TextScaled wraps words whenever that gives bigger text, so a taller box split "4m 12s left" over three lines
	clockText.Size = UDim2.new(1, -62, 0, 36)
	clockText.TextXAlignment = Enum.TextXAlignment.Right
	clockText.TextScaled = true
	clockText.TextWrapped = false
	-- the event's name, small, above the countdown
	local clockName = Ui.label(eventClock, "ClockName", 16, Color3.fromRGB(255, 240, 150))
	clockName.AnchorPoint = Vector2.new(1, 0)
	clockName.Position = UDim2.new(1, -62, 0, -16)
	clockName.Size = UDim2.new(1, -62, 0, 20)
	clockName.TextXAlignment = Enum.TextXAlignment.Right

	-- top right: who is fastest and richest
	local board = Instance.new("Frame")
	board.Name = "Leaderboard"
	board.AnchorPoint = Vector2.new(1, 0)
	board.Position = UDim2.new(1, -12, 0, 12)
	board.Size = UDim2.fromOffset(340, 24)
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
	local function row(name: string, order: number, a: string, b: string, c: string, d: string, color: Color3): Frame
		local r = Instance.new("Frame")
		r.Name = name
		r.LayoutOrder = order
		r.Size = UDim2.new(1, 0, 0, 20)
		r.BackgroundTransparency = 1
		r.Parent = board
		Ui.tableCells(r, { a, b, c, d }, if order == 0 then 12 else 14, color)
		return r
	end

	-- messages from the server
	local toast = Ui.label(gui, "Toast", 26)
	toast.AnchorPoint = Vector2.new(0.5, 1)
	toast.Position = UDim2.new(0.5, 0, 1, -176) -- above the Drop button (bottom -96, 52 tall), never on it
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
		row("Header", 0, "People", "Speed", "Money/s", "Rebirths", Color3.fromRGB(170, 175, 190))
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
				Economy.speed(number(p, "SpeedStat", Progression.SPEED_STAT_BASE)),
				Economy.format(number(p, "Income", 0)),
				tostring(number(p, "Rebirths", 0)),
				if p == player then Color3.fromRGB(255, 240, 120) else Color3.new(1, 1, 1)
			)
		end
	end

	-- the numbers you watch: updated every frame, so your speed climbs in real time while you train
	local shownCoins, coinsSince = -1, os.clock()
	local function liveStats()
		local rebirths = number(player, "Rebirths", 0)
		local coins = number(player, "Coins", 0)
		if coins ~= shownCoins then
			shownCoins, coinsSince = coins, os.clock()
		end
		-- the server adds income twice a second; between those the number climbs smoothly instead of jumping
		local counting = math.min(os.clock() - coinsSince, 0.6) * number(player, "Income", 0)
		money.Text = "$" .. Economy.format(coins + counting)
		speed.Text = (if hasShoe then "" else "👟 ")
			.. Economy.speed(number(player, "SpeedStat", Progression.SPEED_STAT_BASE))
			.. (if rebirths > 0 then ` (x{Rebirth.multiplier(rebirths)})` else "")
	end
	RunService.RenderStepped:Connect(liveStats)

	local function refresh()
		local coins = number(player, "Coins", 0)
		local rebirths = number(player, "Rebirths", 0)
		liveStats()
		local isSlow = player:GetAttribute("SlowMode") == true
		slow.Text = if isSlow then "Slow Mode: ON" else "Slow Mode"
		slowKnob.Position = if isSlow then UDim2.fromOffset(25, 3) else UDim2.fromOffset(3, 3)
		slowKnob.BackgroundColor3 = if isSlow then Color3.fromRGB(60, 235, 60) else Color3.fromRGB(150, 140, 135)
		slowTrack.BackgroundColor3 = if isSlow then Color3.fromRGB(35, 110, 45) else Color3.fromRGB(70, 60, 58)
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
			zone = tostring(player:GetAttribute("Zone") or ""),
		})
		local def = if carrying ~= "" then Eggs.tier(carrying) else nil
		run.Visible = def ~= nil
		drop.Visible = def ~= nil
		runText.Text = "RUN!!"
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
				table.insert(lines, `{eventDef.name}\n{clock((tonumber(ends) :: number) - now)} left`)
			end
		end
		banner.Text = "" -- running events are shown by the clock in the corner (also kept in `lines` for it)
		-- the clock: the event running now, else the next one
		local nextId, nextAt =
			string.match(tostring(ReplicatedStorage:GetAttribute("NextEvent") or ""), "^(%w+):(%d+%.?%d*)$")
		local nextDef = nextId and Events.Defs[nextId]
		if #lines > 0 then
			local name, remaining = string.match(lines[1], "^(.-)\n(.*)$")
			clockName.Text = name or ""
			clockText.Text = remaining or lines[1]
		elseif nextDef and nextAt then
			clockName.Text = nextDef.name
			clockText.Text = `in {clock((tonumber(nextAt) :: number) - now)}`
		else
			clockName.Text = ""
			clockText.Text = ""
		end
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
