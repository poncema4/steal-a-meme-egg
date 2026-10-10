--!strict
-- Builds the real server world inside the fake Roblox and writes every visible part (position, size, colour) to a JSON file,
-- so scripts/preview/render.py can draw the map without Studio. Usage: lune run scripts/preview/dump [out.json]
local fs = require("@lune/fs")
local process = require("@lune/process")
local serde = require("@lune/serde")
local Fake = require("../../tests/fake/Roblox")

local world = Fake.world()
world.load("src/server/main.server")
local parts = {}
for _, inst in world.workspace:GetDescendants() do
	if inst:IsA("BasePart") and inst.Transparency < 0.95 then
		local p, s, c = inst.Position, inst.Size, inst.Color
		local right, look = inst.CFrame.RightVector, inst.CFrame.LookVector
		table.insert(parts, {
			name = inst.Name,
			x = p.X,
			y = p.Y,
			z = p.Z,
			sx = s.X,
			sy = s.Y,
			sz = s.Z,
			r = math.floor(c.R * 255 + 0.5),
			g = math.floor(c.G * 255 + 0.5),
			b = math.floor(c.B * 255 + 0.5),
			-- 90 degree turns swap the footprint
			turned = math.abs(right.X) < 0.5 and math.abs(look.X) < 0.5 and math.abs(right.Z) > 0.5,
		})
	end
end
local out = process.args[1] or "/tmp/map.json"
fs.writeFile(out, serde.encode("json", parts))
print(`wrote {#parts} parts to {out}`)
