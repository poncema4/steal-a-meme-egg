--!nocheck
-- Steal an Egg rules for your pen (Marco): a carried egg is NOT put down by walking in; you click or tap a spot of your own
-- pen and it goes there, eggs never overlap, and a finished egg waits until its owner presses Hatch (E, a tap, or X).
local Fake = require("../fake/Roblox")

return function(t)
	local world = Fake.world()
	local V3 = world.Vector3
	local ok, err = pcall(world.load, "src/server/main.server")
	t.check("the server starts", ok, tostring(err))
	if not ok then
		return
	end
	local session = world.load("src/server/Session")
	local plots = world.load("src/server/Plots")
	local remotes = world.service("ReplicatedStorage"):FindFirstChild("Remotes")
	local place = remotes:FindFirstChild("PlaceEgg")
	local ana = world.addPlayer("Ana", 91)
	local ben = world.addPlayer("Ben", 92)
	world.spawnCharacter(ana)
	world.spawnCharacter(ben)
	world.advance(0.6)
	local plot, benPlot = plots.of(ana), plots.of(ben)
	local root = world.root(ana)
	world.setLocal(ana)

	-- carrying an egg into the pen
	session.setCarry(ana, "Soggy", 1, "Normal")
	root.Position = V3.new(plot.center.X, 3, plot.center.Z)
	world.advance(0.6)
	t.equal("walking in does not put it down", ana:GetAttribute("Carrying"), "Soggy")
	place:FireServer(V3.new(benPlot.center.X, 0.5, benPlot.center.Z))
	world.advance(0.2)
	t.equal("a click in someone else's pen does nothing", ana:GetAttribute("Carrying"), "Soggy")
	place:FireServer(V3.new(plot.center.X + 300, 0.5, plot.center.Z))
	world.advance(0.2)
	t.equal("nor a click outside the pen", ana:GetAttribute("Carrying"), "Soggy")
	place:FireServer("junk")
	world.advance(0.2)
	t.equal("junk is ignored", ana:GetAttribute("Carrying"), "Soggy")
	local spot = V3.new(plot.center.X + 5, 0.5, plot.center.Z + 5)
	place:FireServer(spot)
	world.advance(0.2)
	t.equal("a click on your pen's ground puts it there", ana:GetAttribute("Carrying"), "")
	local first = session.get(ana).base.slots[1]
	t.check("the egg is in the base", first ~= nil and first.kind == "egg")

	-- a second egg on the very same spot moves aside: eggs never overlap
	session.setCarry(ana, "Soggy", 1, "Normal")
	place:FireServer(spot)
	world.advance(0.2)
	local second = session.get(ana).base.slots[2]
	local Base = require("../../src/shared/Game/Base")
	t.check(
		"the second egg does not overlap the first",
		second ~= nil
			and second.at ~= nil
			and first.at ~= nil
			and (second.at.x - first.at.x) ^ 2 + (second.at.z - first.at.z) ^ 2 >= Base.EGG_GAP ^ 2 - 0.01
	)

	-- it finishes, then waits for Hatch
	world.advance(12)
	t.equal("a finished egg does not hatch by itself", ana:GetAttribute("Characters"), 0)
	local prompt = nil
	for _, d in plot.model:GetDescendants() do
		if d:IsA("ProximityPrompt") and d.Name == "HatchPrompt" then
			prompt = d
		end
	end
	t.check("it shows a Hatch prompt (E, a tap, or X)", prompt ~= nil)
	if prompt then
		prompt.Triggered:Fire(ben)
		world.advance(0.2)
		t.equal("someone else cannot hatch your egg", ana:GetAttribute("Characters"), 0)
		prompt.Triggered:Fire(ana)
		world.advance(0.2)
		t.check("pressing Hatch hatches it", (ana:GetAttribute("Characters") :: number) >= 1)
	end
end
