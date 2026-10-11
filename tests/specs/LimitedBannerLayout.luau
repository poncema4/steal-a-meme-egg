--!nocheck
-- Nothing on the limited-egg banner overlaps (Marco: the pets it can hatch ran into the price button), on a monitor and on a phone
-- where the buttons are taller: any two pieces that share columns are stacked one under the other, and all fit inside the banner.
local Fake = require("../fake/Roblox")

local function span(o: any): (number, number, number, number)
	local x = o.Position.X.Offset
	local w = if o.Size.X.Scale > 0 then 1e6 else o.Size.X.Offset -- stretches to the right edge
	return x, x + w, o.Position.Y.Offset, o.Position.Y.Offset + o.Size.Y.Offset
end

return function(t)
	for _, screen in { { false, 1280, 720, "monitor" }, { true, 844, 390, "phone" }, { true, 740, 360, "small phone" } } do
		local world = Fake.world()
		assert(pcall(world.load, "src/server/main.server"))
		local ana = world.addPlayer("Ana", 71)
		world.advance(0.6)
		world.setLocal(ana)
		world.service("UserInputService").TouchEnabled = screen[1]
		world.service("UserInputService").KeyboardEnabled = not screen[1]
		world.setViewport(screen[2], screen[3])
		local shop = world.load("src/client/Shop")
		shop.start(ana)
		world.advance(2)
		local banner = ana.PlayerGui:FindFirstChild("LimitedCard", true)
		t.check(`{screen[4]}: the banner exists`, banner ~= nil)
		local parts = {}
		for _, c in banner:GetChildren() do
			if c:IsA("GuiObject") then
				table.insert(parts, c)
			end
		end
		local clashes = {}
		for i = 1, #parts do
			local a0, a1, ay0, ay1 = span(parts[i])
			t.check(
				`{screen[4]}: {parts[i].Name} fits inside the banner`,
				ay1 <= banner.Size.Y.Offset,
				`{ay1} > {banner.Size.Y.Offset}`
			)
			for j = i + 1, #parts do
				local b0, b1, by0, by1 = span(parts[j])
				if a0 < b1 and b0 < a1 and ay0 < by1 and by0 < ay1 then
					table.insert(clashes, `{parts[i].Name}/{parts[j].Name}`)
				end
			end
		end
		t.equal(`{screen[4]}: nothing on the banner overlaps`, table.concat(clashes, ", "), "")
	end
end
