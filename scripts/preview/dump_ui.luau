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
local panels = world.load("src/client/Panels").start(ana)
world
	.load("src/client/Hud")
	.start(ana, { shop = shop.toggle, index = panels.index, eggs = panels.eggs, pets = panels.pets, trophy = panels.trophy })
-- something to look at in every panel
session.get(ana).base.slots[1] = { kind = "char", id = "BonkBean", mutation = "Gold" }
session.get(ana).base.slots[2] = { kind = "char", id = "DiscoPickle", mutation = "Normal" }
session.get(ana).coins = 5e6
session.grantEgg(ana, "Disco")
session.grantEgg(ana, "Spicy")
session.changed(ana)
world.advance(1)
local which = process.args[5]
if which == "shop" then
	shop.toggle()
elseif which == "index" or which == "eggs" or which == "pets" or which == "trophy" then
	(panels :: any)[which]()
end
world.advance(1)

local rects = {}
local ZERO = { X = { Scale = 0, Offset = 0 }, Y = { Scale = 0, Offset = 0 } }
local function sizeOf(g: any, parentW: number, parentH: number): (number, number)
	local s = g.Size or ZERO
	return s.X.Scale * parentW + s.X.Offset, s.Y.Scale * parentH + s.Y.Offset
end

local function walk(node: any, x: number, y: number, w: number, h: number, scale: number, depth: number)
	local list, grid = nil, nil
	for _, c in node:GetChildren() do
		if c:IsA("UIListLayout") then
			list = c
		elseif c:IsA("UIGridLayout") then
			grid = c
		end
	end
	local gridIndex = 0
	local children = node:GetChildren()
	table.sort(children, function(a: any, b: any)
		return (a.LayoutOrder or 0) < (b.LayoutOrder or 0)
	end)
	local cursor = 0
	local used = 0
	for _, c in children do
		if
			(
				c:IsA("Frame")
				or c:IsA("TextLabel")
				or c:IsA("TextButton")
				or c:IsA("ScrollingFrame")
				or c:IsA("ImageLabel")
			) and c.Visible ~= false
		then
			local cw, ch = sizeOf(c, w, h)
			if grid then
				cw, ch = (grid :: any).CellSize.X.Offset, (grid :: any).CellSize.Y.Offset
			end
			if c.AutomaticSize == world.enum.AutomaticSize.Y then
				ch = 0
			end
			-- an aspect-ratio constraint (ratio 1) shrinks the longer side to the shorter, like FitWithinMaxSize
			-- an aspect-ratio constraint keeps the shape: with Height dominant the width follows the height, otherwise the height
			-- follows the width (Roblox's default)
			local ratioConstraint = c:FindFirstChildOfClass("UIAspectRatioConstraint")
			if ratioConstraint then
				local ratio = (ratioConstraint :: any).AspectRatio or 1
				if (ratioConstraint :: any).DominantAxis and (ratioConstraint :: any).DominantAxis.Name == "Height" then
					cw = ch * ratio
				else
					ch = cw / ratio
				end
			end
			-- a size constraint (the panels' maximum size) caps the size, like Roblox does
			local limit = c:FindFirstChildOfClass("UISizeConstraint")
			if limit and (limit :: any).MaxSize then
				cw = math.min(cw, (limit :: any).MaxSize.X)
				ch = math.min(ch, (limit :: any).MaxSize.Y)
			end
			local padLeft = 0
			local pad = c:FindFirstChildOfClass("UIPadding")
			if pad then
				padLeft = (pad :: any).PaddingLeft.Offset or 0
			end
			local cx, cy
			if grid then
				local padX, padY = (grid :: any).CellPadding.X.Offset, (grid :: any).CellPadding.Y.Offset
				local columns = math.max(1, math.floor((w + padX) / (cw + padX)))
				cx = x + (gridIndex % columns) * (cw + padX)
				cy = y + (gridIndex // columns) * (ch + padY)
				gridIndex += 1
			elseif list then
				local gap = ((list :: any).Padding or { Offset = 0 }).Offset or 0
				if (list :: any).FillDirection and (list :: any).FillDirection.Name == "Horizontal" then
					cx = x + cursor
					cy = y
					cursor += cw + gap
				else
					cx = x
					cy = y + cursor
					cursor += ch + gap
				end
			else
				local p = c.Position or ZERO
				local a = c.AnchorPoint or { X = 0, Y = 0 }
				cx = x + p.X.Scale * w + p.X.Offset - a.X * cw
				cy = y + p.Y.Scale * h + p.Y.Offset - a.Y * ch
			end
			-- an automatic-height frame is as tall as its children stacked
			if c.AutomaticSize == world.enum.AutomaticSize.Y then
				local innerGrid = c:FindFirstChildOfClass("UIGridLayout")
				if innerGrid then
					local count = 0
					for _, g in c:GetChildren() do
						if g:IsA("Frame") then
							count += 1
						end
					end
					local cell = (innerGrid :: any).CellSize
					local gap = (innerGrid :: any).CellPadding
					local columns = math.max(1, math.floor((cw + gap.X.Offset) / (cell.X.Offset + gap.X.Offset)))
					local rowsNeeded = math.ceil(count / columns)
					ch += rowsNeeded * (cell.Y.Offset + gap.Y.Offset)
				else
					for _, g in c:GetChildren() do
						if g:IsA("Frame") then
							ch += (g.Size or ZERO).Y.Offset
						end
					end
				end
			end
			local radius, stroke, strokeColor, textStroke, g1, g2 = 0, 0, { 0, 0, 0 }, 0, nil, nil
			for _, deco in c:GetChildren() do
				if deco:IsA("UICorner") then
					radius = deco.CornerRadius.Offset
				elseif deco:IsA("UIStroke") then
					local col = deco.Color or { R = 0, G = 0, B = 0 }
					if deco.ApplyStrokeMode == world.enum.ApplyStrokeMode.Contextual then
						textStroke = deco.Thickness
					else
						stroke = deco.Thickness
						strokeColor = { math.floor(col.R * 255), math.floor(col.G * 255), math.floor(col.B * 255) }
					end
				elseif deco:IsA("UIGradient") and deco.Color then
					g1, g2 = deco.Color[1], deco.Color[2]
				end
			end
			local bg = c.BackgroundColor3 or { R = 1, G = 1, B = 1 }
			local tc = (c :: any).TextColor3 or { R = 1, G = 1, B = 1 }
			table.insert(rects, {
				name = c.Name,
				padLeft = padLeft,
				x = cx * scale,
				y = cy * scale,
				w = cw * scale,
				h = ch * scale,
				text = if c:IsA("Frame") or c:IsA("ImageLabel") or c:IsA("ScrollingFrame") then "" else c.Text,
				kind = if c:IsA("TextLabel")
					then "TextLabel"
					elseif c:IsA("TextButton") then "TextButton"
					elseif c:IsA("ImageLabel") then "Image"
					else "Frame",
				transparent = c.BackgroundTransparency or 0,
				r = math.floor(bg.R * 255),
				g = math.floor(bg.G * 255),
				b = math.floor(bg.B * 255),
				depth = depth,
				gradient = g1 ~= nil,
				g1 = if g1 then { math.floor(g1.R * 255), math.floor(g1.G * 255), math.floor(g1.B * 255) } else nil,
				g2 = if g2 then { math.floor(g2.R * 255), math.floor(g2.G * 255), math.floor(g2.B * 255) } else nil,
				radius = radius,
				stroke = stroke,
				strokeColor = strokeColor,
				textStroke = textStroke,
				textSize = (c :: any).TextSize or 18,
				textColor = { math.floor(tc.R * 255), math.floor(tc.G * 255), math.floor(tc.B * 255) },
				align = tostring((c :: any).TextXAlignment and (c :: any).TextXAlignment.Name or "Center"),
				image = if c:IsA("ImageLabel") then c.Image else nil,
				imageColor = if c:IsA("ImageLabel") and (c :: any).ImageColor3
					then {
						math.floor((c :: any).ImageColor3.R * 255),
						math.floor((c :: any).ImageColor3.G * 255),
						math.floor((c :: any).ImageColor3.B * 255),
					}
					else nil,
			})
			-- UIPadding insets the container's whole content area: children are laid out inside it
			local innerLeft, innerTop, innerRight, innerBottom = 0, 0, 0, 0
			local inset = c:FindFirstChildOfClass("UIPadding")
			if inset then
				local function off(u: any): number
					return if u then (u.Offset or 0) else 0
				end
				innerLeft, innerRight = off((inset :: any).PaddingLeft), off((inset :: any).PaddingRight)
				innerTop, innerBottom = off((inset :: any).PaddingTop), off((inset :: any).PaddingBottom)
			end
			walk(
				c,
				cx + innerLeft,
				cy + innerTop,
				cw - innerLeft - innerRight,
				ch - innerTop - innerBottom,
				scale,
				depth + 1
			)
		end
	end
	used = cursor
end

-- screens are drawn in DisplayOrder (the panels sit above the HUD)
local screens = ana.PlayerGui:GetChildren()
table.sort(screens, function(a: any, b: any)
	return (a.DisplayOrder or 1) < (b.DisplayOrder or 1)
end)
for _, gui in screens do
	if gui:IsA("ScreenGui") then
		local scaleObj = gui:FindFirstChild("Scale")
		local scale = if scaleObj then (scaleObj :: any).Scale else 1
		-- the design screen: the real one divided by the scale
		walk(gui, 0, 0, width / scale, height / scale, scale, 0)
	end
end
fs.writeFile(out, serde.encode("json", { width = width, height = height, rects = rects }))
print(`wrote {#rects} elements to {out}`)
