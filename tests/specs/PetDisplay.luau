--!strict
-- How a pet looks in its pen: its portrait standing over the pedestal, a glow if it is Gold or Rainbow, and a name and income tag.
local Config = require("../../src/shared/Config")
local Fake = require("../fake/Roblox")

local function find(root: Instance, name: string): Instance?
	return root:FindFirstChild(name, true)
end

local function texts(root: Instance): string
	local out = ""
	for _, d in root:GetDescendants() do
		if d:IsA("TextLabel") then
			out ..= (d :: TextLabel).Text .. "|"
		end
	end
	return out
end

return function(t)
	local world = Fake.world()
	local ok, err = pcall(world.load, "src/server/main.server")
	t.check("the server starts", ok, tostring(err))
	if not ok then
		return
	end
	local session = world.load("src/server/Session")
	local plots = world.load("src/server/Plots")
	local ana = world.addPlayer("Ana", 61)
	world.advance(0.6)
	local plot = plots.of(ana)
	local base = session.get(ana).base
	base.slots[1] = { kind = "char", id = "BonkBean", mutation = "Normal" }
	base.slots[2] = { kind = "char", id = "BonkBean", mutation = "Gold" }
	base.slots[3] = { kind = "char", id = "GoldenGoose", mutation = "Rainbow" }
	session.changed(ana)
	world.advance(0.2)

	local one = find(plot.slots[1], "Item") :: Instance
	local picture = find(one, "Picture") :: ImageLabel
	t.check("a pet shows its portrait", picture ~= nil and picture.Image == (Config.PetIcons :: any).BonkBean)
	t.check(
		"as a picture that always faces the camera",
		find(one, "Portrait") ~= nil and (find(one, "Portrait") :: Instance):IsA("BillboardGui")
	)
	t.check("a normal pet has no glow", find(one, "Glow") == nil)
	t.check(
		"its tag names it and shows what it earns",
		string.find(texts(one), "Bonk Bean", 1, true) ~= nil and string.find(texts(one), "+2/s", 1, true) ~= nil,
		texts(one)
	)

	local gold = find(plot.slots[2], "Item") :: Instance
	local glow = find(gold, "Glow") :: ImageLabel?
	t.check("a Gold pet glows gold", glow ~= nil and glow.ImageColor3 == world.Color3.fromRGB(255, 205, 40))
	t.check(
		"and the tag says Gold and doubles the income",
		string.find(texts(gold), "Gold Bonk Bean", 1, true) ~= nil and string.find(texts(gold), "+4/s", 1, true) ~= nil,
		texts(gold)
	)

	local rainbow = find(plot.slots[3], "Item") :: Instance
	local rglow = find(rainbow, "Glow") :: ImageLabel?
	t.check("a Rainbow pet glows pink", rglow ~= nil and rglow.ImageColor3 == world.Color3.fromRGB(255, 90, 220))
	t.check(
		"and shows its own portrait",
		(find(rainbow, "Picture") :: ImageLabel).Image == (Config.PetIcons :: any).GoldenGoose
	)

	-- a pet leaving the base takes its portrait with it
	base.slots[1] = nil
	session.changed(ana)
	world.advance(0.2)
	t.check("an emptied slot shows nothing", find(plot.slots[1], "Item") == nil)
end
