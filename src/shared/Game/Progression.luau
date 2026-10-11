--!strict
-- Speed and Meme Points. Speed is trained by running on your treadmill (upgrade it with coins to train faster) and sets WalkSpeed, so
-- a faster player can outrun deeper guardians. Meme Points come from bringing eggs home and decide how far out you may go.
local Progression = {}

Progression.BASE_SPEED = 16
-- Speed has no ceiling in the game: the number on the HUD just keeps growing (thousands, millions, then B, T, Qa and beyond). This is only
-- a safety stop for the loop that turns XP into a level; at this level the number is past anything a player will ever see.
Progression.MAX_LEVEL = 400

-- Training XP needed to go from `level` to `level + 1`. It grows faster and faster, so every new level is a real effort.
function Progression.xpForNext(level: number): number
	return math.floor(30 * (level + 1) ^ 2 * 1.12 ^ level)
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

-- The level as a smooth number: 4.5 is halfway through level 4. Speed follows this, so it rises every moment you train,
-- not in jumps at each whole level.
function Progression.levelFloat(xp: number): number
	local level, left = Progression.levelFor(xp)
	if level >= Progression.MAX_LEVEL then
		return Progression.MAX_LEVEL
	end
	return level + left / Progression.xpForNext(level)
end

-- How fast your character really runs, in studs a second. A body cannot run a billion studs a second, so this climbs quickly at first
-- and then settles toward the fastest the game's physics allow (88). The big number on the HUD is `speedStat`, below.
Progression.TOP_SPEED = 88
Progression.SPEED_SETTLE = 20 -- levels it takes to get about two thirds of the way from 16 to 88

function Progression.walkSpeed(level: number): number
	local l = math.max(level, 0)
	return Progression.BASE_SPEED
		+ (Progression.TOP_SPEED - Progression.BASE_SPEED) * (1 - math.exp(-l / Progression.SPEED_SETTLE))
end

-- The "Speed" number shown on the HUD and the leaderboard. It has no limit: every level multiplies it by 1.22, so players climb
-- from 1,600 through thousands and millions to B (billions), T (trillions) and Qa (quadrillions).
Progression.SPEED_STAT_BASE = 1600
Progression.SPEED_STAT_GROWTH = 1.22

function Progression.speedStat(level: number): number
	return math.floor(Progression.SPEED_STAT_BASE * Progression.SPEED_STAT_GROWTH ^ math.max(level, 0))
end

-- Slow Mode caps your walking speed at the Roblox default, for placing things carefully on your base.
Progression.SLOW_SPEED = 16

function Progression.slowed(speed: number, slow: boolean): number
	return if slow then math.min(speed, Progression.SLOW_SPEED) else speed
end

-- Carrying an egg slows you down a little, so a guardian can still catch a careless runner.
Progression.CARRY_FACTOR = 0.9

function Progression.carrySpeed(speed: number, carrying: boolean): number
	return if carrying then speed * Progression.CARRY_FACTOR else speed
end

-- The treadmill is upgraded with coins; each level multiplies the speed XP it gives per second. Speed itself cannot be bought:
-- you earn it by running.
Progression.MAX_TREADMILL = 12
Progression.TREADMILL_GROWTH = 3 -- every upgrade triples the training rate (12 upgrades: x531,441)

function Progression.treadmillCost(level: number): number
	return math.floor(100 * 3.2 ^ math.clamp(level, 0, Progression.MAX_TREADMILL))
end

-- Training XP earned per second of running on a treadmill of this level (a multiplier comes from passes).
function Progression.trainRate(treadmillLevel: number, multiplier: number): number
	return 2 * Progression.TREADMILL_GROWTH ^ math.clamp(treadmillLevel, 0, Progression.MAX_TREADMILL) * multiplier
end

-- Meme Points for bringing home one egg of this tier. Rarer eggs are worth far more.
Progression.EggPoints = {
	Soggy = 1,
	Disco = 5,
	Spicy = 25,
	Golden = 150,
	Cosmic = 1000,
	Divine = 10000,
	Slime = 100000,
	Candy = 1000000,
	Neon = 10000000,
	Cursed = 100000000,
	Cloud = 1000000000,
} :: { [string]: number }

function Progression.pointsForEgg(tier: string): number
	return Progression.EggPoints[tier] or 0
end

return Progression
