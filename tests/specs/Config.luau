--!strict
local Config = require("../../src/shared/Config")

return function(t)
	-- every sound the game asks for exists and is a real asset id
	local required = { "hatch", "steal", "roar", "caught", "deliver", "coin", "horn", "limited", "click", "music" }
	local sounds = Config.Sounds :: { [string]: string }
	for _, name in required do
		local id = sounds[name]
		t.check(
			`sound "{name}" has an asset id`,
			id ~= nil and string.match(id, "^rbxassetid://%d+$") ~= nil,
			tostring(id)
		)
	end
	local seen: { [string]: string } = {}
	local unique = true
	for name, id in sounds do
		if seen[id] then
			unique = false
		end
		seen[id] = name
	end
	t.check("no two sounds share an asset id", unique)

	-- every HUD icon is a real asset id, and no icon reuses a sound's id or another icon's
	local icons = Config.Icons :: { [string]: string }
	local iconKeys = { "egg", "paw", "trophy", "shoe", "cash", "cart", "book", "potion", "trap" }
	local used: { [string]: string } = {}
	for _, id in sounds do
		used[id] = "a sound"
	end
	local iconsOk = true
	for _, name in iconKeys do
		local id = icons[name]
		if id == nil or string.match(id, "^rbxassetid://%d+$") == nil or used[id] then
			iconsOk = false
			print(`  bad icon {name}: {tostring(id)} ({tostring(used[id])})`)
		else
			used[id] = name
		end
	end
	t.check("every HUD icon has its own asset id", iconsOk)

	-- the studio group and save settings are what Creator Hub shows
	t.equal("the studio group id", Config.GroupId, 749648777)
	t.check("the save store has a name", #Config.Save.StoreName > 0)
	t.check("a nest regrows in under a minute", Config.Wilds.NestRespawnSeconds < 60)
	t.check("a guardian gives up before its leash would carry it across the map", Config.Wilds.Leash < 400)
end
