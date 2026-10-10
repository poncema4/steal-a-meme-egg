--!strict
-- The treadmill is a real-looking machine (belt, tread ridges, rollers, rails, console), its console shows the level and the
-- speed it gives, and the belt visibly moves while its owner runs on it.
local Fake = require("../fake/Roblox")
local Progression = require("../../src/shared/Game/Progression")

local function count(root: Instance, name: string): number
	local n = 0
	for _, d in root:GetChildren() do
		if d.Name == name then
			n += 1
		end
	end
	return n
end

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
	local V3 = world.Vector3
	local ok, err = pcall(world.load, "src/server/main.server")
	t.check("the server starts", ok, tostring(err))
	if not ok then
		return
	end
	local plots = world.load("src/server/Plots")
	local session = world.load("src/server/Session")
	local ana = world.addPlayer("Ana", 51)
	world.spawnCharacter(ana)
	world.advance(0.6)
	world.setLocal(ana)
	local plot = plots.of(ana)
	local model = plot.model

	-- the machine
	t.equal("a belt to stand on", count(model, "Treadmill"), 1)
	t.equal("with ten tread ridges on it", count(model, "Ridge"), 10)
	t.equal("a roller at each end", count(model, "Roller"), 2)
	t.equal("a rail down each side", count(model, "TreadRail"), 2)
	t.equal("two console legs", count(model, "ConsoleLeg"), 2)
	t.equal("a handrail each side", count(model, "Handrail"), 2)
	t.check("a console with a display", count(model, "Console") == 1 and find(model, "ConsoleGui") ~= nil)
	t.check("the belt is long enough to run on", plot.treadmill.Size.Z >= 18)
	t.check("and low enough to step onto", plot.treadmill.Position.Y + plot.treadmill.Size.Y / 2 <= 1.0)
	-- the console faces the runner (back toward the pen)
	local console = find(model, "Console") :: Part
	local look = console.CFrame.LookVector
	t.check("the console faces the runner, not the plaza", look.X * plot.front.X + look.Z * plot.front.Z < -0.99)

	-- the display
	t.equal("the console shows the level", plot.display.level.Text, "LEVEL 0")
	t.equal("and what it gives", plot.display.rate.Text, `+{Progression.trainRate(0, 1)} speed/s`)
	session.add(ana, 100000)
	world.prompts(model, "Upgrade treadmill")[1].Triggered:Fire(ana)
	world.advance(0.5)
	t.equal("upgrading changes the display", plot.display.level.Text, "LEVEL 1")
	t.check("and the rate", string.find(plot.display.rate.Text, "3", 1, true) ~= nil, plot.display.rate.Text)
	session.get(ana).treadmill = Progression.MAX_TREADMILL
	session.changed(ana)
	world.advance(0.5)
	t.equal("the top level says so", plot.display.level.Text, "MAX LEVEL")

	-- the belt moves when its owner runs on it, not when they stand still
	local animation = world.load("src/client/Treadmills")
	animation.start()
	local ridges = {}
	for _, d in model:GetChildren() do
		if d.Name == "Ridge" then
			table.insert(ridges, d)
		end
	end
	local function positions(): { number }
		local out = {}
		for _, r in ridges do
			table.insert(out, r.Position.X * plot.front.X + r.Position.Z * plot.front.Z)
		end
		return out
	end
	local before = positions()
	world.root(ana).Position = V3.new(plot.treadmill.Position.X, 3, plot.treadmill.Position.Z)
	world.advance(0.6)
	t.equal("standing on the belt does not move it", plot.treadmill:GetAttribute("BeltSpeed"), 0)
	for _ = 1, 30 do
		world.render(1 / 30)
	end
	local still = positions()
	local same = true
	for i = 1, #before do
		if math.abs(before[i] - still[i]) > 1e-6 then
			same = false
		end
	end
	t.check("so the ridges stay where they were", same)
	world.humanoid(ana).MoveDirection = V3.new(1, 0, 0)
	world.advance(0.6)
	t.check("running publishes the belt speed", (plot.treadmill:GetAttribute("BeltSpeed") :: number) > 5)
	for _ = 1, 15 do
		world.render(1 / 30)
	end
	local moved = positions()
	local changed, inside = false, true
	local lo = plot.treadmill.Position.X * plot.front.X
		+ plot.treadmill.Position.Z * plot.front.Z
		- plot.treadmill.Size.Z / 2
	local hi = lo + plot.treadmill.Size.Z
	for i = 1, #before do
		if math.abs(before[i] - moved[i]) > 0.05 then
			changed = true
		end
		if moved[i] < lo - 0.01 or moved[i] > hi + 0.01 then
			inside = false
		end
	end
	t.check("while running the ridges slide", changed)
	t.check("and always stay on the belt (they wrap round)", inside)
	t.check(
		"they slide backward, toward the pen",
		(function()
			-- a ridge that did not wrap moved toward the back
			for i = 1, #before do
				local d = moved[i] - before[i]
				if d < -0.05 and d > -plot.treadmill.Size.Z / 2 then
					return true
				end
			end
			return false
		end)()
	)
	-- the pure placement rule
	t.equal("ridge placement: slot 0 starts near the back end", animation.ridgeOffset(0, 10, 20, 0), -9)
	t.equal("a full lap puts it back", animation.ridgeOffset(3, 10, 20, 20), animation.ridgeOffset(3, 10, 20, 0))
	t.check("any phase stays on the belt", math.abs(animation.ridgeOffset(7, 10, 20, 13.7)) <= 10)
	world.humanoid(ana).MoveDirection = V3.new(0, 0, 0)
end
