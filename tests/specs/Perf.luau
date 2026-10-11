--!strict
-- A phone budget for the Wilds: how many parts the brick models add, per terrain and in total, and that streaming is on so a
-- phone only holds the terrain around the player. Counts come from the real model files and the real layout.
local fs = require("@lune/fs")
local serde = require("@lune/serde")
local Layout = require("../../src/shared/Game/Layout")
local Zones = require("../../src/shared/Game/Zones")

local SCENERY = { Meadow = "Tree", Dune = "Cactus", Volcano = "LavaRock", Frost = "IcePine", Cosmic = "Crystal" }
local MAX_PER_TERRAIN = 3500
local MAX_TOTAL = 13500

local function parts(folder: string, name: string): number
	local text = fs.readFile(`src/models/{folder}/{name}.rbxmx`)
	local n = 0
	for _ in string.gmatch(text, '<Item class="Part"') do
		n += 1
	end
	return n
end

return function(t)
	local total = 0
	for _, zone in Zones.List do
		local nests = Layout.nests(zone)
		local sum = #Layout.scenery(zone, nests) * parts("Props", SCENERY[zone.id]) + parts("Bosses", `Boss{zone.id}`)
		for _, nest in nests do
			sum += parts("Props", "Nest") + parts("Eggs", nest.tier)
		end
		total += sum
		t.check(`{zone.id}: {sum} model parts (at most {MAX_PER_TERRAIN})`, sum <= MAX_PER_TERRAIN)
	end
	t.check(`the Wilds add {total} model parts (at most {MAX_TOTAL})`, total <= MAX_TOTAL)

	local project = serde.decode("json", fs.readFile("default.project.json")) :: any
	local workspaceProps = project.tree.Workspace["$properties"]
	t.check("streaming is on, so phones only hold the terrain near them", workspaceProps.StreamingEnabled == true)
	t.check("with a radius that covers the next terrain gate", workspaceProps.StreamingTargetRadius >= 400)
	t.check(
		"and it only pauses if the 128-stud radius around you is missing",
		workspaceProps.StreamingIntegrityMode == "MinimumRadiusPause"
	)
	-- scenery and eggs cast no shadows; every model streams in whole
	for _, name in { "Props/Tree", "Props/Nest", "Eggs/Soggy", "Props/LavaRock" } do
		local text = fs.readFile(`src/models/{name}.rbxmx`)
		t.check(`{name}: no shadows`, string.find(text, '<bool name="CastShadow">true</bool>', 1, true) == nil)
		t.check(
			`{name}: streams in whole`,
			string.find(text, '<token name="ModelStreamingMode">1</token>', 1, true) ~= nil
		)
	end

	-- the lighting is set in the project (not left at Studio's washed-out default), so every build looks the same
	local lighting = project.tree.Lighting["$properties"]
	t.check("the sun is not overexposed", lighting.Brightness <= 2.5 and lighting.ExposureCompensation <= 0)
	t.check("and shadows are on", lighting.GlobalShadows == true)
end
