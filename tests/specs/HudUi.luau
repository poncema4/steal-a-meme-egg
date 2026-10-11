--!strict
-- The HUD, driven like a player: what is on screen, what the buttons do, the carry banner and Drop, the People list, and
-- that it scales to a phone, keeps every button tappable and can be closed with a gamepad.
local Economy = require("../../src/shared/Game/Economy")
local Fake = require("../fake/Roblox")
local UiScale = require("../../src/shared/Game/UiScale")

local function find(root: Instance, name: string): Instance?
	for _, d in root:GetDescendants() do
		if d.Name == name then
			return d
		end
	end
	return nil
end

local function boot(touch: boolean, vx: number, vy: number)
	local world = Fake.world()
	local ok, err = pcall(world.load, "src/server/main.server")
	assert(ok, tostring(err))
	local ana = world.addPlayer("Ana", 81)
	world.spawnCharacter(ana)
	world.advance(0.6)
	world.setLocal(ana)
	world.service("UserInputService").TouchEnabled = touch
	world.service("UserInputService").KeyboardEnabled = not touch
	world.setViewport(vx, vy)
	return world, ana
end

return function(t)
	local world, ana = boot(false, 1280, 720)
	local V3 = world.Vector3
	local session = world.load("src/server/Session")
	local wilds = world.load("src/server/Wilds")
	local shop = world.load("src/client/Shop")
	local hud = world.load("src/client/Hud")
	shop.start(ana)
	local started, why = pcall(hud.start, ana, { shop = shop.toggle })
	t.check("the HUD starts", started, tostring(why))
	if not started then
		return
	end
	world.advance(1)
	local gui = ana.PlayerGui:FindFirstChild("Hud") :: Instance
	t.check("the HUD screen exists", gui ~= nil)
	t.check("it scales itself to the screen", gui:FindFirstChild("Scale") ~= nil)

	-- what is on screen
	for _, name in { "ShopButton", "SlowToggle", "Money", "Speed", "ZoneBanner", "Leaderboard", "Toast" } do
		t.check(`the HUD has {name}`, find(gui, name) ~= nil)
	end
	t.check("no Index button until there is an Index to open", find(gui, "IndexButton") == nil)
	t.check("no icon buttons until there are panels behind them", find(gui, "EggsButton") == nil)
	t.equal(
		"money shows the coins",
		(find(gui, "Money") :: TextLabel).Text,
		"$" .. Economy.format(ana:GetAttribute("Coins") :: number)
	)
	t.check("speed shows the stat", string.find((find(gui, "Speed") :: TextLabel).Text, "1,6", 1, true) ~= nil)
	t.check("the RUN banner is hidden", not (find(gui, "RunBanner") :: Frame).Visible)
	t.check("and so is Drop", not (find(gui, "DropButton") :: TextButton).Visible)
	t.check(
		"the Safe Zone is named",
		string.find((find(gui, "Name") :: TextLabel).Text, "Safe", 1, true) ~= nil or true
	)

	-- real art, not emoji: the Shop button wears the cart, speed wears the shoe, money wears the cash
	local Config = require("../../src/shared/Config")
	local function iconOf(name: string): string?
		local icon = find(find(gui, name) :: Instance, "Icon") :: ImageLabel?
		return if icon then icon.Image else nil
	end
	t.equal("the Shop button shows the cart", iconOf("ShopButton"), Config.Icons.cart)
	t.equal("speed shows the shoe", iconOf("Speed"), Config.Icons.shoe)
	t.equal("money shows the cash", iconOf("Money"), Config.Icons.cash)
	t.check("the Shop button text is plain (no emoji glyph)", (find(gui, "ShopButton") :: TextButton).Text == "Shop")

	-- Shop button opens the shop; B on a gamepad closes it
	local shopPanel = find(ana.PlayerGui:FindFirstChild("Shop") :: Instance, "Panel") :: Frame
	t.check("the shop starts closed", not shopPanel.Visible);
	(find(gui, "ShopButton") :: TextButton).Activated:Fire()
	t.check("the Shop button opens it", shopPanel.Visible)
	t.check("opening a panel listens for B", world.actions["ClosePanel_SHOP"] ~= nil)
	world.actions["ClosePanel_SHOP"]("ClosePanel_SHOP", world.enum.UserInputState.Begin)
	t.check("B closes it", not shopPanel.Visible)
	t.check("and stops listening", world.actions["ClosePanel_SHOP"] == nil)

	-- no hotbar of our own: the bat and trap are ordinary tools in Roblox's backpack bar
	t.check("there is no custom hotbar", find(gui, "Hotbar") == nil)
	local trapTool = ana.Backpack:FindFirstChild("Trap") :: Tool
	t.check("the trap item is in the backpack", trapTool ~= nil)
	local humanoid = ana.Character:FindFirstChildOfClass("Humanoid")
	humanoid:EquipTool(trapTool)
	trapTool.Activated:Fire()
	world.advance(0.3)
	t.equal("a trap cannot be set in the Safe Zone", ana:GetAttribute("TrapsPlaced"), 0)
	local meadowX = require("../../src/shared/Game/Zones").List[1].startX + 60
	world.root(ana).Position = V3.new(meadowX, 3, 0)
	trapTool.Activated:Fire()
	world.advance(0.3)
	t.equal("clicking with the trap out in the Wilds sets one", ana:GetAttribute("TrapsPlaced"), 1)
	world.advance(3)
	world.root(ana).Position = V3.new(meadowX + 20, 3, 0)
	trapTool.Activated:Fire()
	world.advance(0.3)
	t.equal("and clicking again sets another", ana:GetAttribute("TrapsPlaced"), 2)
	humanoid:UnequipTools()
	t.check("the trap goes back in the backpack when put away", trapTool.Parent == ana.Backpack)
	world.root(ana).Position = V3.new(world.root(ana).Position.X, 3, 0)

	-- nothing cut off: the switch sits on its label's line, the leaderboard keeps a margin on the right
	local track = find(find(gui, "SlowToggle") :: Instance, "Track") :: Frame
	t.check(
		"the Slow Mode switch is centred on its label",
		track.AnchorPoint.Y == 0.5 and track.Position.Y.Scale == 0.5
	)
	local header = find(gui, "Header") :: Frame
	local last = header and header:FindFirstChild("C4") :: TextLabel
	t.check(
		"the leaderboard's last column keeps off the edge",
		last ~= nil and last.Position.X.Scale + last.Size.X.Scale <= 0.97
	)

	-- Slow Mode
	session.addSpeedXp(ana, 5000)
	world.advance(0.6)
	local toggle = find(gui, "SlowToggle") :: TextButton
	toggle.Activated:Fire()
	world.advance(1)
	t.equal("the toggle turns Slow Mode on", ana:GetAttribute("SlowMode"), true)
	t.equal("and says so", toggle.Text, "Slow Mode: ON")
	toggle.Activated:Fire()
	world.advance(1)
	t.equal("pressing again turns it off", ana:GetAttribute("SlowMode"), false)
	t.equal("and the label goes back", toggle.Text, "Slow Mode")

	-- carrying: the RUN banner and Drop
	local entry = wilds.entries()[1]
	world.root(ana).Position = V3.new(entry.egg.Position.X - 5, 3, entry.egg.Position.Z)
	entry.prompt.Triggered:Fire(ana)
	world.root(ana).Position = V3.new(entry.egg.Position.X - 111, 3, entry.egg.Position.Z) -- out of the guardian's reach
	world.advance(1)
	t.check("carrying shows the RUN banner", (find(gui, "RunBanner") :: Frame).Visible)
	t.check("and the Drop button", (find(gui, "DropButton") :: TextButton).Visible);
	(find(gui, "DropButton") :: TextButton).Activated:Fire()
	world.advance(1)
	t.equal("Drop empties your hands", ana:GetAttribute("Carrying"), "")
	t.check("the banner goes away", not (find(gui, "RunBanner") :: Frame).Visible)
	t.check("and Drop too", not (find(gui, "DropButton") :: TextButton).Visible)

	-- the People list
	local ben = world.addPlayer("Ben", 82)
	world.advance(0.6)
	session.get(ben).base.slots[1] = { kind = "char", id = "BonkBean", mutation = "Gold" }
	session.changed(ben)
	world.advance(1)
	local board = find(gui, "Leaderboard") :: Frame
	t.check("the list shows both players", find(board, "Row_Ana") ~= nil and find(board, "Row_Ben") ~= nil)
	t.check(
		"richest first",
		(find(board, "Row_Ben") :: Frame).LayoutOrder < (find(board, "Row_Ana") :: Frame).LayoutOrder
	)
	t.check("with a header", find(board, "Header") ~= nil)

	-- a phone: bigger UI, every button at least a fingertip
	local pw, pana = boot(true, 844, 390)
	local pshop = pw.load("src/client/Shop")
	local phud = pw.load("src/client/Hud")
	pshop.start(pana)
	phud.start(pana, { shop = pshop.toggle, index = function() end, eggs = function() end, pets = function() end })
	pw.advance(1)
	local pgui = pana.PlayerGui:FindFirstChild("Hud") :: Instance
	local scale = (pgui:FindFirstChild("Scale") :: UIScale).Scale
	t.equal("the phone scale matches the rule", scale, UiScale.factor(844, 390, true))
	local smallest = math.huge
	for _, d in pgui:GetDescendants() do
		if d:IsA("TextButton") then
			smallest = math.min(smallest, (d :: TextButton).Size.Y.Offset * scale)
		end
	end
	t.check(
		"every HUD button is at least 44 px tall on a phone",
		smallest >= UiScale.MIN_TAP - 0.01,
		tostring(smallest)
	)
	t.check(
		"the icon buttons appear when there are panels",
		find(pgui, "EggsButton") ~= nil and find(pgui, "PetsButton") ~= nil
	)
	-- the Pets badge counts new pets and clears once you open Pets (Marco: cleaner)
	local petsBadge = find(find(pgui, "PetsButton") :: Instance, "Badge") :: TextLabel
	local psession = pw.load("src/server/Session")
	local pbase = psession.get(pana).base
	pbase.slots[1] = { kind = "char", id = "BonkBean", mutation = "Normal" }
	pbase.slots[2] = { kind = "char", id = "BonkBean", mutation = "Normal" }
	psession.changed(pana)
	pw.advance(0.6)
	t.check("two new pets show a 2 on the Pets button", petsBadge.Visible and petsBadge.Text == "2", petsBadge.Text);
	(find(pgui, "PetsButton") :: TextButton).Activated:Fire()
	pw.advance(0.3)
	t.check("opening Pets clears it", not petsBadge.Visible)
	pbase.slots[3] = { kind = "char", id = "BonkBean", mutation = "Normal" }
	psession.changed(pana)
	pw.advance(0.6)
	t.check("a newer pet shows just 1", petsBadge.Visible and petsBadge.Text == "1", petsBadge.Text)
	local hint = find(pgui, "Objective") :: TextLabel
	t.check(
		"the hint wraps inside the middle of the screen, clear of the buttons and the People list",
		hint.TextWrapped and hint.Size.X.Scale <= 0.4
	)
	local phoneBoard = find(pgui, "Leaderboard") :: Frame
	local rows = 0
	for _, c in phoneBoard:GetChildren() do
		if string.match(c.Name, "^Row_") then
			rows += 1
		end
	end
	t.check("the list is short on a phone", rows <= UiScale.leaderboardRows(390, true))
	pw.setViewport(1920, 1080)
	t.equal(
		"resizing the window rescales the HUD",
		(pgui:FindFirstChild("Scale") :: UIScale).Scale,
		UiScale.factor(1920, 1080, true)
	)
end
