--!strict
-- The shop screen, driven like a player would: open it, read the limited egg, buy it with coins. Also: a character that
-- spawned somewhere else while the save was still loading is brought to the player's own base.
local Eggs = require("../../src/shared/Game/Eggs")
local Fake = require("../fake/Roblox")
local Limited = require("../../src/shared/Game/Limited")

local function find(root: Instance, name: string): Instance?
	for _, d in root:GetDescendants() do
		if d.Name == name then
			return d
		end
	end
	return nil
end

return function(t)
	local world = Fake.world()
	local ok, err = pcall(world.load, "src/server/main.server")
	t.check("the server starts", ok, tostring(err))
	if not ok then
		return
	end
	local session = world.load("src/server/Session")
	local ana = world.addPlayer("Ana", 51)
	world.advance(1)
	world.setLocal(ana)
	local shop = world.load("src/client/Shop")
	local started, why = pcall(shop.start, ana)
	t.check("the shop screen starts", started, tostring(why))
	if not started then
		return
	end
	world.advance(6)

	local gui = ana.PlayerGui:FindFirstChild("Shop") :: Instance
	t.check("the shop screen exists", gui ~= nil)
	local panel = find(gui, "Panel") :: Frame
	t.check("it starts closed", not panel.Visible)
	shop.toggle()
	t.check("toggling opens it", panel.Visible);
	(find(gui, "Close") :: TextButton).Activated:Fire()
	t.check("the X closes it", not panel.Visible)
	shop.toggle()

	-- the limited egg card
	local current = Limited.current(world.workspace:GetServerTimeNow())
	local tier = Eggs.tier(current.tier) :: Eggs.Tier
	t.check(
		"it names the limited egg on sale",
		string.find((find(gui, "LimitedTitle") :: TextLabel).Text, tier.name, 1, true) ~= nil
	)
	t.check(
		"it shows the stock",
		string.find((find(gui, "LimitedInfo") :: TextLabel).Text, tostring(Limited.STOCK), 1, true) ~= nil
	)
	t.check(
		"the coin button shows the price",
		string.find((find(gui, "LimitedCoins") :: TextButton).Text, "10Qi", 1, true) ~= nil
	)
	t.check(
		"the Robux button shows now that the item exists in Creator Hub",
		(find(gui, "LimitedRobux") :: TextButton).Visible
	)

	-- every pass and Robux hatch pack is listed
	local rows = 0
	for _, d in gui:GetDescendants() do
		if string.match(d.Name, "^Row_") then
			rows += 1
		end
	end
	t.equal("the seven passes and two hatch packs are listed", rows, 9)
	-- each is a card with a picture, a name, what it does and its price on the buy button
	for _, key in { "coins2x", "luck2x", "train2x", "hatch1", "hatch5" } do
		local card = find(gui, `Card_{key}`)
		t.check(`{key}: has a card`, card ~= nil)
		if card then
			t.check(`{key}: with its own picture`, find(card, "Picture") ~= nil)
			t.check(
				`{key}: with its price`,
				string.find((find(card, `Row_{key}`) :: TextButton).Text, "R$", 1, true) ~= nil
			)
		end
	end
	t.check("a pass says what it does", (find(find(gui, "Card_luck2x") :: Instance, "Blurb") :: TextLabel).Text ~= "")
	t.check("the limited egg has its own banner", find(gui, "LimitedCard") ~= nil)

	-- buying with coins from the screen
	local coinsButton = find(gui, "LimitedCoins") :: TextButton
	coinsButton.Activated:Fire()
	t.check("a poor player buys nothing", session.get(ana).base.slots[1] == nil)
	session.add(ana, tier.price + 1000)
	world.advance(1.1)
	coinsButton.Activated:Fire()
	local item = session.get(ana).base.slots[1]
	t.check("a rich player gets the egg", item ~= nil and item.kind == "egg" and item.tier == tier.id)

	-- sound on the client: the tune starts, and effects are played by name from Config.Sounds
	local Config = require("../../src/shared/Config")
	local audio = world.load("src/client/Audio")
	local audioOk, audioErr = pcall(audio.start)
	t.check("the client audio starts", audioOk, tostring(audioErr))
	t.check("the background tune plays", table.find(world.played, Config.Sounds.music) ~= nil)
	local remotes = world.service("ReplicatedStorage"):FindFirstChild("Remotes") :: Instance
	local sfxRemote = remotes:FindFirstChild("Sfx") :: RemoteEvent
	sfxRemote:FireClient(ana, "hatch")
	t.check("an effect sent by name plays its own asset", table.find(world.played, Config.Sounds.hatch) ~= nil)
	local before = #world.played
	sfxRemote:FireClient(ana, "no_such_sound")
	sfxRemote:FireClient(ana, 12345)
	t.equal("an unknown name or a number plays nothing", #world.played, before)

	-- a character that spawned elsewhere while the save loaded is brought home
	local late = Fake.world()
	local V3 = late.Vector3
	late.service("DataStoreService").GetDataStore = function()
		return {
			GetAsync = function(_, key)
				local userId = tonumber(string.sub(key, 2))
				for _, p in late.players do
					if p.UserId == userId then
						late.spawnCharacter(p)
						late.root(p).Position = V3.new(500, 3, 0) -- far from any base
					end
				end
				return nil
			end,
			UpdateAsync = function(_, _, fn)
				return fn(nil)
			end,
		}
	end
	pcall(late.load, "src/server/main.server")
	local plots = late.load("src/server/Plots")
	local straggler = late.addPlayer("Late", 71)
	late.advance(0.6)
	local plot = plots.of(straggler)
	t.check("the late player has a plot", plot ~= nil)
	local root = late.root(straggler)
	t.check(
		"and their character stands at it, not where it first spawned",
		math.abs(root.Position.X - plot.spawn.Position.X) < 30,
		tostring(root.Position.X)
	)
end
