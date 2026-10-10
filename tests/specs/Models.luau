--!strict
-- The brick models in src/models (made by art/brick/build.py): every character and egg has one, each file is a well-formed Roblox
-- model of anchored parts with a root to pivot on, nothing is empty, flipped or absurdly big, and the part count stays small.
local fs = require("@lune/fs")
local Eggs = require("../../src/shared/Game/Eggs")

local MAX_PARTS = 450

local function readModel(path: string): string
	return fs.readFile(path)
end

local function check(t, folder: string, name: string, minTall: number, maxTall: number)
	local path = `src/models/{folder}/{name}.rbxmx`
	if not fs.isFile(path) then
		t.check(`{folder}/{name} exists`, false)
		return
	end
	local text = readModel(path)
	t.check(
		`{name}: a Roblox model file`,
		string.find(text, "<roblox ", 1, true) == 1 and string.find(text, "</roblox>", 1, true) ~= nil
	)
	t.check(
		`{name}: a Model named {name}`,
		string.find(
			text,
			`<Item class="Model" referent="RBX1"><Properties><string name="Name">{name}</string>`,
			1,
			true
		) ~= nil
	)
	local parts = 0
	for _ in string.gmatch(text, '<Item class="Part"') do
		parts += 1
	end
	t.check(`{name}: {parts} parts (between 8 and {MAX_PARTS})`, parts >= 8 and parts <= MAX_PARTS)
	t.check(
		`{name}: the root is the primary part`,
		string.find(text, '<Ref name="PrimaryPart">RBX2</Ref>', 1, true) ~= nil
			and string.find(text, '<Item class="Part" referent="RBX2">', 1, true) ~= nil
	)
	local anchored = select(2, string.gsub(text, '<bool name="Anchored">true</bool>', ""))
	t.equal(`{name}: every part is anchored`, anchored, parts)
	local top, bottom, width, bad = 0, math.huge, 0, false
	for cy, sx, sy, sz in
		string.gmatch(
			text,
			'<CoordinateFrame name="CFrame"><X>[%-%d%.]+</X><Y>([%-%d%.]+)</Y><Z>[%-%d%.]+</Z>.-<Vector3 name="size"><X>([%d%.]+)</X><Y>([%d%.]+)</Y><Z>([%d%.]+)</Z>'
		)
	do
		local y, w, h, d =
			tonumber(cy) :: number, tonumber(sx) :: number, tonumber(sy) :: number, tonumber(sz) :: number
		if not (w > 0 and h > 0 and d > 0) or w ~= w or h ~= h or d ~= d then
			bad = true
		end
		top = math.max(top, y + h / 2)
		bottom = math.min(bottom, y - h / 2)
		width = math.max(width, w)
	end
	t.check(`{name}: every part has a real size`, not bad)
	t.check(`{name}: stands on the ground (lowest point {bottom})`, bottom >= -0.15 or bottom == math.huge)
	t.check(`{name}: {top} studs tall (between {minTall} and {maxTall})`, top >= minTall and top <= maxTall)
	t.check(`{name}: no single brick is a whole wall`, width <= 20)
	t.check(`{name}: colours are opaque`, string.find(text, 'Color3uint8">%d+<') ~= nil)
end

return function(t)
	for _, tier in Eggs.Tiers do
		check(t, "Eggs", tier.id, 4.5, 7.5)
	end
	for id in Eggs.Characters do
		check(t, "Pets", id, 3.0, 8.0)
	end
	-- nothing is left over from a character or tier that no longer exists
	for _, entry in fs.readDir("src/models/Pets") do
		local id = string.gsub(entry, "%.rbxmx$", "")
		t.check(`Pets/{id} is a real character`, Eggs.Characters[id] ~= nil)
	end
	for _, entry in fs.readDir("src/models/Eggs") do
		local id = string.gsub(entry, "%.rbxmx$", "")
		t.check(`Eggs/{id} is a real egg`, Eggs.tier(id) ~= nil)
	end
end
