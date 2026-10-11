--!strict
local Objective = require("../../src/shared/Game/Objective")
local Progression = require("../../src/shared/Game/Progression")
local Zones = require("../../src/shared/Game/Zones")

local function facts(over: { [string]: any }): Objective.Facts
	local base = { carrying = false, eggs = 0, characters = 0, freeSlots = 6, coins = 0, mp = 0, speedLevel = 0 }
	for k, v in over do
		base[k] = v
	end
	return base :: any
end

return function(t)
	t.check(
		"a brand new player is told to steal an egg",
		string.find(Objective.hint(facts({})), "steal", 1, true) ~= nil
	)
	t.check(
		"having coins does not change that: eggs come from guardians",
		string.find(Objective.hint(facts({ coins = 150 })), "steal", 1, true) ~= nil
	)
	t.check(
		"carrying an egg always means RUN HOME",
		string.find(Objective.hint(facts({ carrying = true, eggs = 3, freeSlots = 0 })), "RUN HOME", 1, true) ~= nil
	)
	t.check(
		"when you can afford a rebirth you are told",
		string.find(Objective.hint(facts({ characters = 3, canRebirth = true })), "REBIRTH", 1, true) ~= nil
	)
	t.check(
		"but carrying an egg still comes first",
		string.find(Objective.hint(facts({ carrying = true, canRebirth = true })), "RUN HOME", 1, true) ~= nil
	)
	t.check(
		"a full base says to buy a slot",
		string.find(Objective.hint(facts({ eggs = 2, characters = 4, freeSlots = 0 })), "slot", 1, true) ~= nil
	)
	local dune = Zones.List[2]
	local next = Objective.hint(facts({ characters = 2, speedLevel = 0 }))
	t.check(
		"a locked terrain says to train on the treadmill for it",
		string.find(next, "treadmill", 1, true) ~= nil and string.find(next, dune.name, 1, true) ~= nil,
		next
	)
	t.check(
		"the hint shows the Speed number the terrain opens at",
		string.find(next, Zones.speedLabel(dune), 1, true) ~= nil,
		next
	)
	t.check("Meme Points never gate a terrain", string.find(next, "Meme Points", 1, true) == nil, next)
	t.check(
		"a waiting egg with everything unlocked says hatching",
		string.find(Objective.hint(facts({ eggs = 1, mp = 1e9, speedLevel = 30 })), "hatching", 1, true) ~= nil
	)
	t.check("a veteran still gets a hint", Objective.hint(facts({ characters = 6, mp = 1e9, speedLevel = 30 })) ~= "")

	-- speed needed matches the terrain balance
	t.equal("a new player needs no training for the Meadow", Objective.speedNeeded(0), 0)
	local rising = true
	local last = 0
	for _, zone in Zones.List do
		local n = Objective.speedNeeded(zone.level)
		if n < last or Progression.carrySpeed(Progression.walkSpeed(n), true) <= zone.guardianSpeed then
			rising = false
		end
		last = n
	end
	t.check("the speed each terrain needs only goes up and really outruns its guardians", rising)

	-- every combination of facts yields a hint (never blank)
	local blank = false
	for _, carrying in { true, false } do
		for _, eggs in { 0, 1, 5 } do
			for _, chars in { 0, 1, 5 } do
				for _, free in { 0, 3 } do
					for _, mp in { 0, 40, 1e9 } do
						for _, level in { 0, 8, 30 } do
							local h = Objective.hint(facts({
								carrying = carrying,
								eggs = eggs,
								characters = chars,
								freeSlots = free,
								coins = 0,
								mp = mp,
								speedLevel = level,
							}))
							if h == "" then
								blank = true
							end
						end
					end
				end
			end
		end
	end
	t.check("no combination of facts leaves the player without a hint", not blank)
end
