--!strict
-- The one line that tells a player what to do next. A new player who does not know what to do leaves in the first minute, so
-- this walks them through the loop (steal an egg, run it home, hatch it, get stronger, go further) and never goes blank.
-- Pure: the HUD passes in what it knows, so every step is tested.
local Progression = require("./Progression")
local Zones = require("./Zones")

local Objective = {}

export type Facts = {
	carrying: boolean,
	eggs: number, -- eggs hatching in the base
	characters: number, -- finished characters in the base
	freeSlots: number,
	coins: number,
	mp: number, -- Meme Points
	speedLevel: number,
}

-- The speed level you need to outrun the guardians of the furthest terrain you have unlocked, while carrying an egg.
function Objective.speedNeeded(mp: number): number
	local zone = Zones.furthest(mp)
	for level = 0, Progression.MAX_LEVEL do
		if Progression.carrySpeed(Progression.walkSpeed(level), true) > zone.guardianSpeed then
			return level
		end
	end
	return Progression.MAX_LEVEL
end

function Objective.hint(f: Facts): string
	if f.carrying then
		return "RUN HOME with the egg before the guardian catches you!"
	end
	if f.eggs == 0 and f.characters == 0 then
		if f.coins >= 100 then
			return "Buy an egg off the belt (E), or walk east and steal one from a guardian!"
		end
		return "Walk east to the Meadow and hold E on a guardian's egg to steal it!"
	end
	if f.freeSlots == 0 then
		return "Your base is full! Stand on the green pad to buy another slot."
	end
	local nextZone = Zones.nextLocked(f.mp)
	local needed = Objective.speedNeeded(f.mp)
	if f.speedLevel < needed then
		return `Train on the treadmill: you need speed level {needed} to outrun the guardians out here.`
	end
	if nextZone then
		return `Bring eggs home for Meme Points: {f.mp} of {nextZone.mp} to unlock {nextZone.name}.`
	end
	if f.eggs > 0 and f.characters == 0 then
		return "Your egg is hatching. Hold E on it to skip the wait with coins."
	end
	return "Keep stealing the best eggs and grow your meme collection!"
end

return Objective
