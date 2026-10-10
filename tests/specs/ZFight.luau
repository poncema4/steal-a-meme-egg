--!strict
-- Two surfaces at the same height that overlap flicker against each other on screen ("z-fighting"): the jitter Marco saw on
-- the terrain. This builds the real world and checks that no two visible, axis-aligned parts share a top face.
local Fake = require("../fake/Roblox")

type Box = { name: string, corners: { { number } }, top: number }

-- do two convex quads (lists of {x, z}) overlap by more than a sliver? (separating axis test with a margin)
local function overlap(a: { { number } }, b: { { number } }, margin: number): boolean
	for _, poly in { a, b } do
		for i = 1, #poly do
			local p, q = poly[i], poly[i % #poly + 1]
			local nx, nz = -(q[2] - p[2]), q[1] - p[1]
			local len = math.sqrt(nx * nx + nz * nz)
			nx, nz = nx / len, nz / len
			local aMin, aMax, bMin, bMax = math.huge, -math.huge, math.huge, -math.huge
			for _, c in a do
				local d = c[1] * nx + c[2] * nz
				aMin, aMax = math.min(aMin, d), math.max(aMax, d)
			end
			for _, c in b do
				local d = c[1] * nx + c[2] * nz
				bMin, bMax = math.min(bMin, d), math.max(bMax, d)
			end
			if aMax - bMin <= margin or bMax - aMin <= margin then
				return false -- a gap (or only a touching edge) on this axis
			end
		end
	end
	return true
end

return function(t)
	local world = Fake.world()
	world.workspace:SetAttribute("ShowAllPlots", true) -- these checks look at every base, not just the occupied ones
	local ok, err = pcall(world.load, "src/server/main.server")
	t.check("the world builds", ok, tostring(err))
	if not ok then
		return
	end
	local boxes: { Box } = {}
	for _, inst in world.workspace:GetDescendants() do
		if inst:IsA("BasePart") and inst.Transparency < 0.95 and not inst:IsA("Terrain") then
			local right, up = inst.CFrame.RightVector, inst.CFrame.UpVector
			-- any turn about the vertical axis is fine; tilted parts (the plaza disc, turned cylinders) are skipped
			if math.abs(up.Y) > 0.999 and inst.Size.Y > 0 and inst.Size.X > 0 and inst.Size.Z > 0 then
				local p, s = inst.Position, inst.Size
				local look = inst.CFrame.LookVector
				local corners = {}
				for _, sx in { -1, 1 } do
					for _, sz in { -1, 1 } do
						-- corner = centre + right * (sx * w/2) + back * (sz * d/2), flattened to the ground plane
						local x = p.X + right.X * sx * s.X / 2 - look.X * sz * s.Z / 2
						local z = p.Z + right.Z * sx * s.X / 2 - look.Z * sz * s.Z / 2
						table.insert(corners, { x, z })
					end
				end
				-- order the corners around the quad (the loops above give a Z shape)
				corners = { corners[1], corners[2], corners[4], corners[3] }
				table.insert(boxes, {
					name = `{if inst.Parent then inst.Parent.Name else "?"}.{inst.Name}`,
					corners = corners,
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
			if math.abs(a.top - b.top) < 0.05 and overlap(a.corners, b.corners, 0.1) then
				table.insert(clashes, `{a.name} / {b.name} (top {a.top})`)
			end
		end
	end
	for k = 1, #clashes do
		print("  z-fight: " .. clashes[k])
	end
	t.equal("no two surfaces share a top face (no flicker)", #clashes, 0)
end
