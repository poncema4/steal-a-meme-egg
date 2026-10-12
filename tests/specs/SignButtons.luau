--!nocheck
-- The base signs: on a PC a button on each sign (cost above it) does the job and the hold prompts are hidden; a phone keeps the
-- hold prompts. Rebirth is a fair 25% a time.
local Fake = require("../fake/Roblox")

local function boot(touch: boolean)
	local world = Fake.world()
	assert(pcall(world.load, "src/server/main.server"))
	local ana = world.addPlayer("Ana", 71)
	world.spawnCharacter(ana)
	world.advance(0.6)
	world.setLocal(ana)
	local uis = world.service("UserInputService")
	uis.TouchEnabled = touch
	uis.KeyboardEnabled = not touch
	uis.MouseEnabled = not touch
	uis.GamepadEnabled = false
	return world, ana
end

return function(t)
	local world, ana = boot(false)
	local session = world.load("src/server/Session")
	local plots = world.load("src/server/Plots")
	local signs = world.load("src/client/SignButtons")
	signs.start(ana)
	world.advance(1.2)
	local found = 0
	for _, g in ana.PlayerGui:GetChildren() do
		if g.Name == "SignButtons" then
			found += 1
		end
	end
	t.equal("each of the 3 signs has a button on both faces", found, 6)
	local upgrade
	for _, g in ana.PlayerGui:GetChildren() do
		if g.Name == "SignButtons" and g.Adornee and g.Adornee.Name == "UpgradeSign" then
			upgrade = g
		end
	end
	local cost = upgrade:FindFirstChild("Cost", true)
	t.check(
		"the UPGRADE sign shows the next cost above its button",
		cost and string.find(cost.Text, "$", 1, true) ~= nil,
		cost and cost.Text
	)
	local plot = plots.of(ana)
	local prompt = world.prompts(plot.model, "Upgrade treadmill")[1]
	t.check("on a PC the hold prompt is hidden", prompt and prompt.Enabled == false)
	session.add(ana, 1e12)
	local level = session.get(ana).treadmill
	upgrade:FindFirstChild("Press", true).Activated:Fire()
	world.advance(0.6)
	t.equal("clicking UPGRADE upgrades the treadmill", session.get(ana).treadmill, level + 1)
	local everyGui = true
	for _, g in ana.PlayerGui:GetChildren() do
		if g.Name == "SignButtons" and g.ResetOnSpawn ~= false then
			everyGui = false
		end
	end
	t.check("the sign buttons survive a respawn", everyGui)
	local painted = plot.model:FindFirstChild("UpgradeSign"):FindFirstChildOfClass("SurfaceGui")
	t.check("on a PC the plain sign words give way to the button", painted and painted.Enabled == false)

	local pw, pana = boot(true)
	pw.load("src/client/SignButtons").start(pana)
	pw.advance(1.2)
	local pplot = pw.load("src/server/Plots").of(pana)
	t.check("a phone keeps the hold prompt", pw.prompts(pplot.model, "Upgrade treadmill")[1].Enabled ~= false)
end
