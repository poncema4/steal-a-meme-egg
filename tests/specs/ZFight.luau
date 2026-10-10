--!strict
-- Two surfaces at the same height that overlap flicker against each other on screen ("z-fighting"): the jitter Marco saw on
-- the terrain. This builds the real world and checks that no two visible, axis-aligned parts share a top face.
local Fake = require("../fake/Roblox")

type Box = { name: string, x0: number, x1: number, z0: number, z1: number, top: number }

return function(t)
	local world = Fake.world()
	local ok, err = pcall(world.load, "src/server/main.server")
	t.check("the world builds", ok, tostring(err))
	if not ok then
		return
	end
	local boxes: { Box } = {}
	for _, inst in world.workspace:GetDescendants() do
		if inst:IsA("BasePart") and inst.Transparency < 0.95 and not inst:IsA("Terrain") then
			local right, up = inst.CFrame.RightVector, inst.CFrame.UpVector
			local straight = math.abs(right.X) > 0.999 and math.abs(up.Y) > 0.999
			if straight and inst.Size.Y > 0 and inst.Size.X > 0 and inst.Size.Z > 0 then
				local p, s = inst.Position, inst.Size
				table.insert(boxes, {
					name = `{if inst.Parent then inst.Parent.Name else "?"}.{inst.Name}`,
					x0 = p.X - s.X / 2,
					x1 = p.X + s.X / 2,
					z0 = p.Z - s.Z / 2,
					z1 = p.Z + s.Z / 2,
					top = p.Y + s.Y / 2,
				})
			end
		end
	end
	t.check("there are parts to check", #boxes > 100, tostring(#boxes))
	local clashes: { string } = {}
	for i = 1, #boxes do
		for j = i + 1, #boxes do
			local a, b = boxes[i], boxes[j]
			if math.abs(a.top - b.top) < 0.05 then
				local ox = math.min(a.x1, b.x1) - math.max(a.x0, b.x0)
				local oz = math.min(a.z1, b.z1) - math.max(a.z0, b.z0)
				if ox > 0.1 and oz > 0.1 then
					table.insert(clashes, `{a.name} / {b.name} (top {a.top})`)
				end
			end
		end
	end
	for k = 1, #clashes do
		print("  z-fight: " .. clashes[k])
	end
	t.equal("no two surfaces share a top face (no flicker)", #clashes, 0)
end
