--!strict
-- Rebirth: spend a lot of coins to start over with a permanent income bonus. Meme Points, speed and passes are kept, so
-- every terrain you unlocked stays open; only coins and the base reset. Pure: the server applies the reset.
local Rebirth = {}

Rebirth.MAX = 20
Rebirth.BASE_COST = 2000000
Rebirth.COST_GROWTH = 5
Rebirth.BONUS_PER = 0.5 -- +50% income per rebirth

-- Coins needed for the next rebirth when you have done `done` already.
function Rebirth.cost(done: number): number
	return Rebirth.BASE_COST * Rebirth.COST_GROWTH ^ math.max(done, 0)
end

-- Permanent income multiplier after `done` rebirths.
function Rebirth.multiplier(done: number): number
	return 1 + Rebirth.BONUS_PER * math.clamp(done, 0, Rebirth.MAX)
end

function Rebirth.can(done: number, coins: number): boolean
	return done < Rebirth.MAX and coins >= Rebirth.cost(done)
end

return Rebirth
