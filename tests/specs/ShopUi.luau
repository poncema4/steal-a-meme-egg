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

	local gui = ana.PlayerGui:FindFirstChild("RaidShop") :: Instance
	t.check("the shop screen exists", gui ~= nil)
	local panel = find(gui, "Panel") :: Frame
	local openButton = find(gui, "ShopButton") :: TextButton
	t.check("it starts closed", not panel.Visible)
	openButton.Activated:Fire()
	t.check("the SHOP button opens it", panel.Visible);
	(find(gui, "Close") :: TextButton).Activated:Fire()
	t.check("the X closes it", not panel.Visible)
	openButton.Activated:Fire()

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
		string.find((find(gui, "LimitedCoins") :: TextButton).Text, "1B", 1, true) ~= nil
	)
	t.check(
		"the Robux button is hidden while that item has no Creator Hub id",
		not (find(gui, "LimitedRobux") :: TextButton).Visible
	)

	-- nothing with id 0 is listed
	local rows = 0
	for _, d in gui:GetDescendants() do
		if string.match(d.Name, "^Row_") then
			rows += 1
		end
	end
	t.equal("items that are not for sale yet are not listed", rows, 0)

	-- buying with coins from the screen
	local coinsButton = find(gui, "LimitedCoins") :: TextButton
	coinsButton.Activated:Fire()
	t.check("a poor player buys nothing", session.get(ana).base.slots[1] == nil)
	session.add(ana, tier.price + 1000)
	world.advance(1.1)
	coinsButton.Activated:Fire()
	local item = session.get(ana).base.slots[1]
	t.check("a rich player gets the egg", item ~= nil and item.kind == "egg" and item.tier == tier.id)

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
