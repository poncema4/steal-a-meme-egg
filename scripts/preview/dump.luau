--!strict
-- Builds the real server world inside the fake Roblox and writes every visible part (position, size, colour) to a JSON file,
-- so scripts/preview/render.py can draw the map without Studio. Usage: lune run scripts/preview/dump [out.json]
local fs = require("@lune/fs")
local process = require("@lune/process")
local serde = require("@lune/serde")
local Fake = require("../../tests/fake/Roblox")

local world = Fake.world()
world.workspace:SetAttribute("ShowAllPlots", true) -- the preview shows every base, not just the occupied ones
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
			-- the turn about the vertical axis, in radians (so rotated pens and walls draw correctly)
			yaw = math.atan2(-right.Z, right.X),
			-- turned a quarter turn about the front axis (a cylinder lying down is a disc): width and height swap
			rolled = math.abs(right.Y) > 0.9,
		})
	end
end
-- where the brick models stand (the fake world has none), for scripts/preview/compose.py to stamp into the picture
local Layout = require("../../src/shared/Game/Layout")
local Zones = require("../../src/shared/Game/Zones")
local SCENERY = Layout.SceneryModel
local models = {}
for _, zone in Zones.List do
	local nests = Layout.nests(zone)
	for _, prop in Layout.scenery(zone, nests) do
		table.insert(models, {
			kind = "Props",
			id = SCENERY[zone.id],
			x = prop.x,
			y = 0,
			z = prop.z,
			yaw = prop.extra * math.pi * 2,
			scale = prop.size / 5.5,
		})
	end
	for _, nest in nests do
		table.insert(models, { kind = "Props", id = "Nest", x = nest.x, y = 0, z = nest.z, yaw = 0, scale = 1 })
		table.insert(models, { kind = "Eggs", id = nest.tier, x = nest.x, y = 0.6, z = nest.z, yaw = 0, scale = 1 })
	end
	local boss = Layout.bossSpot(zone)
	table.insert(models, { kind = "Bosses", id = `Boss{zone.id}`, x = boss.x, y = 0, z = boss.z, yaw = 0, scale = 1 })
end
fs.writeFile((process.args[1] or "/tmp/map.json"):gsub("%.json$", "") .. ".models.json", serde.encode("json", models))
local out = process.args[1] or "/tmp/map.json"
fs.writeFile(out, serde.encode("json", parts))
print(`wrote {#parts} parts to {out}`)
