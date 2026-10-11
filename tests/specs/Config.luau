--!strict
local Config = require("../../src/shared/Config")
local Zones = require("../../src/shared/Game/Zones")
local Eggs = require("../../src/shared/Game/Eggs")

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
	local iconKeys = { "egg", "paw", "trophy", "shoe", "cash", "cart", "book", "potion", "trap", "clock" }
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

	-- every character has a portrait with its own asset id
	local portraits = Config.PetIcons :: { [string]: string }
	local portraitsOk = true
	for charId in Eggs.Characters do
		local id = portraits[charId]
		if id == nil or string.match(id, "^rbxassetid://%d+$") == nil or used[id] then
			portraitsOk = false
			print(`  bad portrait {charId}: {tostring(id)} ({tostring(id and used[id])})`)
		else
			used[id] = charId
		end
	end
	t.check("every character has a portrait with its own asset id", portraitsOk)
	-- every egg tier has a picture, and every pass and product a card picture, each its own asset
	local eggPictures = Config.EggIcons :: { [string]: string }
	local eggsOk = true
	for _, tier in Eggs.Tiers do
		local id = eggPictures[tier.id]
		if id == nil or string.match(id, "^rbxassetid://%d+$") == nil or used[id] then
			eggsOk = false
			print(`  bad egg picture {tier.id}: {tostring(id)}`)
		else
			used[id] = tier.id
		end
	end
	t.check("every egg has a picture with its own asset id", eggsOk)
	local art = Config.ShopArt :: { [string]: string }
	local artOk = true
	local catalog = Config.Monetization :: any
	for _, group in { catalog.Passes, catalog.Products } do
		for key in group do
			local id = art[key]
			if id == nil or string.match(id, "^rbxassetid://%d+$") == nil or used[id] then
				artOk = false
				print(`  bad shop art {key}: {tostring(id)}`)
			else
				used[id] = key
			end
		end
	end
	t.check("every pass and product has card art with its own asset id", artOk)
	local extra = false
	for charId in portraits do
		if Eggs.Characters[charId] == nil then
			extra = true
		end
	end
	t.check("and there are no portraits for characters that do not exist", not extra)

	-- the studio group and save settings are what Creator Hub shows
	t.equal("the studio group id", Config.GroupId, 749648777)
	t.check("the save store has a name", #Config.Save.StoreName > 0)
	t.check("a nest regrows in under a minute", Config.Wilds.NestRespawnSeconds < 60)
	t.check(
		"a boss can follow a thief from the deepest terrain all the way back to the Safe Zone",
		Config.Wilds.Leash >= Zones.endX(Zones.List[#Zones.List]) - Zones.List[1].startX
	)
end
