--!strict
-- Three details from the reference screenshot: the avatar name tag over each base, the money floating over the pets, and the event
-- countdown in the corner.
local Fake = require("../fake/Roblox")

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
	local plots = world.load("src/server/Plots")
	local session = world.load("src/server/Session")
	local ana = world.addPlayer("Ana", 701)
	world.spawnCharacter(ana)
	world.advance(0.6)
	world.setLocal(ana)

	-- the name tag
	local plot = plots.of(ana)
	local post = plot.model:FindFirstChild("SignPost") :: Instance
	local tag = post:FindFirstChild("OwnerTag") :: Instance
	t.check("a base has a floating tag over it", tag ~= nil and tag:IsA("BillboardGui"))
	local face = find(tag, "Headshot") :: ImageLabel
	t.check(
		"with the owner's round headshot",
		face ~= nil and string.find(face.Image, "AvatarHeadShot&id=701", 1, true) ~= nil
	)
	t.check("and a corner radius that makes it a circle", (find(face, "UICorner") :: UICorner).CornerRadius.Scale == 1)
	t.equal("and their name", (find(tag, "Name") :: TextLabel).Text, "Ana")
	world.removePlayer(ana)
	world.advance(0.6)
	t.check("the tag goes when the owner leaves", post:FindFirstChild("OwnerTag") == nil)

	-- money floating over the pets
	local ben = world.addPlayer("Ben", 702)
	world.spawnCharacter(ben)
	world.advance(0.6)
	world.setLocal(ben)
	local benPlot = plots.of(ben)
	session.get(ben).base.slots[1] = { kind = "char", id = "BonkBean", mutation = "Normal" }
	session.changed(ben)
	world.advance(0.6)
	t.check("Ben earns something each second", (ben:GetAttribute("Income") :: number) > 0)
	local floaters = world.load("src/client/Floaters")
	floaters.start()
	world.advance(1.5)
	local spot = benPlot.slots[1]
	local floater = spot:FindFirstChild("MoneyFloater")
	t.check("money rises over a character", floater ~= nil)
	t.check(
		"in green, with a dollar sign",
		floater ~= nil
			and string.find((floater:FindFirstChildOfClass("TextLabel") :: TextLabel).Text, "+$", 1, true) == 1
	)
	world.advance(2)
	t.check("and does not pile up (each one is gone after a moment)", #(function()
		local n = {}
		for _, c in spot:GetChildren() do
			if c.Name == "MoneyFloater" then
				table.insert(n, c)
			end
		end
		return n
	end)() <= 3)

	-- the event clock in the corner
	local hud = world.load("src/client/Hud")
	hud.start(ben, {})
	local gui = ben.PlayerGui:FindFirstChild("Hud") :: Instance
	local clock = find(gui, "EventClock") :: Frame
	t.check(
		"the HUD has the event clock bottom right",
		clock ~= nil and clock.AnchorPoint.X == 1 and clock.AnchorPoint.Y == 1
	)
	local rs = world.service("ReplicatedStorage")
	world.advance(1)
	-- the server publishes what is next ("Id:time"); the clock names it and counts down
	local clockText = find(clock, "ClockText") :: TextLabel
	local text = clockText.Text
	-- Marco saw "4m / 12s / left" stacked on three lines: the countdown box is one line tall and never wraps
	t.check(
		"the countdown is one line (no wrapping)",
		clockText.Size.Y.Scale == 0 and clockText.Size.Y.Offset <= 40 and not clockText.TextWrapped
	)
	-- the clock counts down to night (the game's one event)
	t.check("the server publishes the phase", rs:GetAttribute("Phase") ~= nil, tostring(rs:GetAttribute("Phase")))
	t.check(
		"the clock counts down to the next phase",
		string.match(text, "^in %d+m %d+s$") ~= nil
			or string.match(text, "^in %d+s$") ~= nil
			or string.find(text, "left", 1, true) ~= nil,
		text
	)
	t.check(
		"the event's name sits above the countdown",
		(find(clock, "ClockName") :: TextLabel).Text ~= "",
		(find(clock, "ClockName") :: TextLabel).Text
	)
end
