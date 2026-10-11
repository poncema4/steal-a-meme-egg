--!strict
-- The Index, Eggs and Pets panels, used like a player would: open them from the HUD, read what they show, press Skip.
local Eggs = require("../../src/shared/Game/Eggs")
local Fake = require("../fake/Roblox")

local function find(root: Instance, name: string): Instance?
	for _, d in root:GetDescendants() do
		if d.Name == name then
			return d
		end
	end
	return nil
end

local function count(root: Instance, prefix: string): number
	local n = 0
	for _, d in root:GetDescendants() do
		if string.sub(d.Name, 1, #prefix) == prefix then
			n += 1
		end
	end
	return n
end

return function(t)
	local world = Fake.world()
	local ok, err = pcall(world.load, "src/server/main.server")
	t.check("the server starts", ok, tostring(err))
	if not ok then
		return
	end
	local session = world.load("src/server/Session")
	local ana = world.addPlayer("Ana", 91)
	world.spawnCharacter(ana)
	world.advance(0.6)
	world.setLocal(ana)
	local shop = world.load("src/client/Shop")
	local panels = world.load("src/client/Panels")
	local hud = world.load("src/client/Hud")
	shop.start(ana)
	local started, why = pcall(panels.start, ana)
	t.check("the panels start", started, tostring(why))
	if not started then
		return
	end
	local api = why :: any
	hud.start(ana, { shop = shop.toggle, index = api.index, eggs = api.eggs, pets = api.pets, trophy = api.trophy })
	world.advance(1)
	local screen = ana.PlayerGui:FindFirstChild("Panels") :: Instance
	local hudGui = ana.PlayerGui:FindFirstChild("Hud") :: Instance
	local trophyButton = find(hudGui, "TrophyButton") :: TextButton
	t.check("and the trophy button, like the reference", trophyButton ~= nil)
	trophyButton.Activated:Fire()
	world.advance(1)
	local trophyRows = find(screen, "Row_Ana")
	t.check("the trophy button opens the top players, with Ana in it", trophyRows ~= nil)
	t.check(
		"showing four columns: player, speed, money and rebirths",
		trophyRows ~= nil and find(trophyRows, "C4") ~= nil
	)
	trophyButton.Activated:Fire()
	world.advance(0.5)
	t.check(
		"the HUD now has the Index, eggs and pets buttons",
		find(hudGui, "IndexButton") ~= nil and find(hudGui, "EggsButton") ~= nil and find(hudGui, "PetsButton") ~= nil
	)

	local function panelNamed(title: string): Frame
		for _, d in screen:GetChildren() do
			if d.Name == "Panel" and ((find(d, "Title") :: TextLabel).Text == title) then
				return d :: Frame
			end
		end
		error("no panel " .. title)
	end
	local index, eggs, pets = panelNamed("INDEX"), panelNamed("EGGS"), panelNamed("PETS")
	for name, frame in { INDEX = index, EGGS = eggs, PETS = pets } do
		local limit = find(frame, "UISizeConstraint") :: UISizeConstraint?
		t.check(`{name} never takes more than 90% of the screen height (so it fits a phone)`, frame.Size.Y.Scale <= 0.9)
		t.check(`{name} also has a maximum size for big screens`, limit ~= nil and limit.MaxSize.X <= 720)
	end
	t.check("all three start closed", not index.Visible and not eggs.Visible and not pets.Visible); -- the Index: everything hidden at first, then a hatched character is revealed
	(find(hudGui, "IndexButton") :: TextButton).Activated:Fire()
	t.check("the Index button opens the Index", index.Visible)
	local total = 0
	for _ in Eggs.Characters do
		total += 1
	end
	t.equal("it has a card for every character", count(find(index, "Cards") :: Instance, "Card_"), total)
	t.equal("it counts nothing discovered", (find(index, "Progress") :: TextLabel).Text, `Discovered 0 / {total}`)
	-- one list you scroll down (no tabs): a section per world plus the limited eggs, every one showing, each on its own colours
	local cardsList = find(index, "Cards") :: ScrollingFrame
	t.check(
		"the Index scrolls down",
		cardsList:IsA("ScrollingFrame") and cardsList.ScrollingDirection ~= world.enum.ScrollingDirection.X
	)
	t.check("there are no tabs any more", find(index, "Tabs") == nil)
	local one, two = find(index, "Section_1") :: Frame, find(index, "Section_2") :: Frame
	t.check("every world's section shows at once", one.Visible and two.Visible and find(index, "Section_16") ~= nil)
	t.check("each world has its own background colour", one.BackgroundColor3 ~= two.BackgroundColor3)
	t.check("in its world's theme (a gradient)", one:FindFirstChildOfClass("UIGradient") ~= nil)
	local header = find(one, "Header") :: TextLabel
	t.check(
		"a section names its world and counts",
		string.find(header.Text, "MEME MEADOW", 1, true) ~= nil and string.find(header.Text, "/", 1, true) ~= nil,
		header.Text
	)
	t.check(
		"and says what finishing it wins",
		string.find((find(two, "Reward") :: TextLabel).Text, "Bat", 1, true) ~= nil,
		(find(two, "Reward") :: TextLabel).Text
	)
	t.equal(
		"an unknown character is hidden",
		(find(find(index, "Card_BonkBean") :: Instance, "Name") :: TextLabel).Text,
		"???"
	)
	session.get(ana).base.slots[1] = { kind = "char", id = "BonkBean", mutation = "Gold" }
	session.changed(ana)
	world.advance(1)
	t.equal("a new character is counted", (find(index, "Progress") :: TextLabel).Text, `Discovered 1 / {total}`)
	t.equal("and named", (find(find(index, "Card_BonkBean") :: Instance, "Name") :: TextLabel).Text, "Bonk Bean")
	t.check(
		"with its mutation ticked",
		string.find((find(find(index, "Card_BonkBean") :: Instance, "Chip_Gold") :: TextLabel).Text, "✓", 1, true)
			~= nil
	)
	t.check(
		"and the other mutation not",
		string.find((find(find(index, "Card_BonkBean") :: Instance, "Chip_Rainbow") :: TextLabel).Text, "✓", 1, true)
			== nil
	)
	local bonk = find(index, "Card_BonkBean") :: Instance
	local silhouette = find(find(index, "Card_SleepySock") :: Instance, "Picture") :: ImageLabel
	t.check(
		"a discovered character shows its portrait in full colour",
		(find(bonk, "Picture") :: ImageLabel).ImageColor3 == world.Color3.new(1, 1, 1)
	)
	t.check("an undiscovered one is a black silhouette", silhouette.ImageColor3 == world.Color3.new(0, 0, 0))
	t.check(
		"the portraits are real images",
		string.find((find(bonk, "Picture") :: ImageLabel).Image, "rbxassetid://", 1, true) == 1
	)
	t.equal("others stay hidden", (find(find(index, "Card_SleepySock") :: Instance, "Name") :: TextLabel).Text, "???"); -- opening another panel closes the Index (one at a time)
	(find(hudGui, "PetsButton") :: TextButton).Activated:Fire()
	t.check("opening Pets closes the Index", pets.Visible and not index.Visible)
	t.check("the Pets panel lists the character", find(pets, "PetRow_1") ~= nil)
	t.check(
		"with its portrait",
		string.find((find(find(pets, "PetRow_1") :: Instance, "Picture") :: ImageLabel).Image, "rbxassetid://", 1, true)
			== 1
	)
	t.check(
		"with its mutation and income",
		string.find((find(find(pets, "PetRow_1") :: Instance, "Title") :: TextLabel).Text, "Gold", 1, true) ~= nil
	)
	t.equal("income is doubled by Gold", (find(find(pets, "PetRow_1") :: Instance, "Income") :: TextLabel).Text, "+4/s")
	session.get(ana).base.slots[1] = nil
	session.changed(ana)
	world.advance(1)
	t.check("a pet that leaves the base leaves the list", find(pets, "PetRow_1") == nil)
	t.check("and the panel says so", string.find((find(pets, "Note") :: TextLabel).Text, "No pets", 1, true) ~= nil); -- Eggs: Skip hatches the egg through the server
	(find(hudGui, "EggsButton") :: TextButton).Activated:Fire()
	t.check("the eggs button opens Eggs", eggs.Visible and not pets.Visible)
	t.check(
		"with nothing hatching it says so",
		string.find((find(eggs, "Note") :: TextLabel).Text, "No eggs", 1, true) ~= nil
	)
	session.grantEgg(ana, "Soggy")
	session.get(ana).coins = 1e6
	session.changed(ana)
	world.advance(1)
	local row = find(eggs, "EggRow_1") :: Frame?
	t.check("a hatching egg gets a row", row ~= nil)
	if row then
		t.check("the row names the egg", string.find((find(row, "Title") :: TextLabel).Text, "Soggy", 1, true) ~= nil)
		t.check(
			"shows the time left",
			string.find((find(row, "Timer") :: TextLabel).Text, "hatching in", 1, true) ~= nil
		)
		t.check("there is no coin Skip button: only Robux speeds a hatch", find(row, "Skip") == nil)
		t.check("an Instant button is there for tokens or Robux", find(row, "Instant") ~= nil)
	end

	-- B closes the open panel; the HUD keeps working
	local name = "ClosePanel_EGGS"
	t.check("an open panel listens for B", world.actions[name] ~= nil)
	world.actions[name](name, world.enum.UserInputState.Begin)
	t.check("B closes it", not eggs.Visible)
end
