--!strict
-- Starts the real client UI inside the fake Roblox and writes where every GUI element lands on a screen of the given size
-- (applying UDim2 scale/offset, anchors, UIScale and vertical UIListLayout), for scripts/preview/render_ui.py.
-- Usage: lune run scripts/preview/dump_ui out.json [width] [height] [touch]
local fs = require("@lune/fs")
local process = require("@lune/process")
local serde = require("@lune/serde")
local Fake = require("../../tests/fake/Roblox")

local out = process.args[1] or "/tmp/ui.json"
local width = tonumber(process.args[2]) or 1280
local height = tonumber(process.args[3]) or 720
local touch = process.args[4] == "touch"

local world = Fake.world()
world.load("src/server/main.server")
local ana = world.addPlayer("Ana", 1)
local ben = world.addPlayer("Ben", 2)
world.spawnCharacter(ana)
world.advance(0.6)
world.setLocal(ana)
world.service("UserInputService").TouchEnabled = touch
world.service("UserInputService").KeyboardEnabled = not touch
world.setViewport(width, height)
local session = world.load("src/server/Session")
session.get(ben).base.slots[1] = { kind = "char", id = "BonkBean", mutation = "Gold" }
session.changed(ben)
session.add(ana, 123456789)
session.addSpeedXp(ana, 800)
local shop = world.load("src/client/Shop")
shop.start(ana)
world.load("src/client/Hud").start(ana, { shop = shop.toggle, index = function() end, eggs = function() end, pets = function() end, trophy = function() end })
world.advance(1)
if process.args[5] == "shop" then
	shop.toggle()
end

local rects = {}
local ZERO = { X = { Scale = 0, Offset = 0 }, Y = { Scale = 0, Offset = 0 } }
local function sizeOf(g: any, parentW: number, parentH: number): (number, number)
	local s = g.Size or ZERO
	return s.X.Scale * parentW + s.X.Offset, s.Y.Scale * parentH + s.Y.Offset
end

local function walk(node: any, x: number, y: number, w: number, h: number, scale: number, depth: number)
	local list = nil
	for _, c in node:GetChildren() do
		if c:IsA("UIListLayout") then
			list = c
		end
	end
	local children = node:GetChildren()
	table.sort(children, function(a: any, b: any)
		return (a.LayoutOrder or 0) < (b.LayoutOrder or 0)
	end)
	local cursor = 0
	local used = 0
	for _, c in children do
		if (c:IsA("Frame") or c:IsA("TextLabel") or c:IsA("TextButton")) and c.Visible ~= false then
			local cw, ch = sizeOf(c, w, h)
			if c.AutomaticSize == world.enum.AutomaticSize.Y then
				ch = 0
			end
			local cx, cy
			if list then
				cx = x
				cy = y + cursor
				cursor += ch + (((list :: any).Padding or { Offset = 0 }).Offset or 0)
			else
				local p = c.Position or ZERO
				local a = c.AnchorPoint or { X = 0, Y = 0 }
				cx = x + p.X.Scale * w + p.X.Offset - a.X * cw
				cy = y + p.Y.Scale * h + p.Y.Offset - a.Y * ch
			end
			-- an automatic-height frame is as tall as its children stacked
			if c.AutomaticSize == world.enum.AutomaticSize.Y then
				for _, g in c:GetChildren() do
					if g:IsA("Frame") then
						ch += (g.Size or ZERO).Y.Offset
					end
				end
			end
			local bg = c.BackgroundColor3 or { R = 1, G = 1, B = 1 }
			table.insert(rects, {
				name = c.Name,
				x = cx * scale,
				y = cy * scale,
				w = cw * scale,
				h = ch * scale,
				text = if c:IsA("Frame") then "" else c.Text,
				kind = if c:IsA("TextLabel") then "TextLabel" elseif c:IsA("TextButton") then "TextButton" else "Frame",
				transparent = c.BackgroundTransparency or 0,
				r = math.floor(bg.R * 255),
				g = math.floor(bg.G * 255),
				b = math.floor(bg.B * 255),
				depth = depth,
				gradient = c:FindFirstChildOfClass("UIGradient") ~= nil,
			})
			walk(c, cx, cy, cw, ch, scale, depth + 1)
		end
	end
	used = cursor
end

for _, gui in ana.PlayerGui:GetChildren() do
	if gui:IsA("ScreenGui") then
		local scaleObj = gui:FindFirstChild("Scale")
		local scale = if scaleObj then (scaleObj :: any).Scale else 1
		-- the design screen: the real one divided by the scale
		walk(gui, 0, 0, width / scale, height / scale, scale, 0)
	end
end
fs.writeFile(out, serde.encode("json", { width = width, height = height, rects = rects }))
print(`wrote {#rects} elements to {out}`)
