--!strict
-- Speed and Meme Points. Speed is trained on the treadmill (free, slow) or bought with coins (fast) and sets WalkSpeed, so
-- a faster player can outrun deeper guardians. Meme Points come from bringing eggs home and decide how far out you may go.
local Progression = {}

Progression.BASE_SPEED = 16
Progression.MAX_LEVEL = 30
Progression.SPEED_PER_LEVEL = 0.9 -- level 30 = 43 studs/s, just above the last terrain's guardians (27)

-- Training XP needed to go from `level` to `level + 1`.
function Progression.xpForNext(level: number): number
	return math.floor(30 * (level + 1) ^ 1.5)
end

-- The level reached with this much total training XP (and the XP left over inside it).
function Progression.levelFor(xp: number): (number, number)
	local level = 0
	local left = math.max(xp, 0)
	while level < Progression.MAX_LEVEL do
		local need = Progression.xpForNext(level)
		if left < need then
			break
		end
		left -= need
		level += 1
	end
	return level, left
end

function Progression.walkSpeed(level: number): number
	return Progression.BASE_SPEED + math.clamp(level, 0, Progression.MAX_LEVEL) * Progression.SPEED_PER_LEVEL
end

-- Coins to buy the next speed level outright.
function Progression.speedCost(level: number): number
	return math.floor(250 * 1.55 ^ level)
end

-- Training XP earned per second on the treadmill (a multiplier comes from passes).
function Progression.trainRate(multiplier: number): number
	return 2 * multiplier
end

-- Meme Points for bringing home one egg of this tier. Rarer eggs are worth far more.
Progression.EggPoints =
	{ Soggy = 1, Disco = 5, Spicy = 25, Golden = 150, Cosmic = 1000, Divine = 10000 } :: { [string]: number }

function Progression.pointsForEgg(tier: string): number
	return Progression.EggPoints[tier] or 0
end

return Progression
