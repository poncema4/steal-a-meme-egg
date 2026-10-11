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
	canRebirth: boolean?, -- coins have reached the cost of the next rebirth
	inPen: boolean?, -- you stand in your own pen
	touch: boolean?, -- a phone or tablet: say "hold the button" instead of naming a key
	zone: string?, -- the terrain you stand in ("Safe Zone" or nil when you are not out in the Wilds)
}

-- The speed level you need to outrun the guardians of the furthest terrain you have unlocked, while carrying an egg.
function Objective.speedNeeded(reached: number): number
	local zone = Zones.furthest(reached)
	for level = 0, Progression.MAX_LEVEL do
		if Progression.carrySpeed(Progression.walkSpeed(level), true) > zone.guardianSpeed then
			return level
		end
	end
	return Progression.MAX_LEVEL
end

function Objective.hint(f: Facts): string
	local hold = if f.touch then "Hold the button" else "Hold E"
	if f.carrying and f.inPen then
		return if f.touch
			then "Tap a spot in your pen to put the egg down!"
			else "Click a spot in your pen to put the egg down!"
	end
	if f.carrying then
		return "RUN HOME with the egg before the guardian catches you!"
	end
	if f.canRebirth then
		return `You can REBIRTH! {hold} on the purple pad at the left of your base for a permanent coin boost.`
	end
	local outside = f.zone ~= nil and f.zone ~= "" and f.zone ~= "Safe Zone"
	if f.eggs == 0 and f.characters == 0 then
		if outside then
			return `{hold} on a guardian's egg to steal it, then run it home!`
		end
		return `Walk east to the Meadow and {string.lower(hold)} on a guardian's egg to steal it!`
	end
	if f.freeSlots == 0 then
		return "Your base is full! Stand on the green pad to buy another slot."
	end
	local nextZone = Zones.nextTarget(f.speedLevel)
	local needed = Objective.speedNeeded(f.speedLevel)
	if f.speedLevel < needed then
		return `Train on the treadmill: you need speed level {needed} to outrun the guardians out here.`
	end
	if nextZone then
		return `Train on the treadmill: recommended speed {Zones.speedLabel(nextZone)} for {nextZone.name}.`
	end
	if f.eggs > 0 and f.characters == 0 then
		return "Your egg is hatching in your base. Steal another one while you wait!"
	end
	return "Keep stealing the best eggs and grow your meme collection!"
end

return Objective
