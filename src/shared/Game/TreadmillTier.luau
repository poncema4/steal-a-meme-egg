--!strict
-- What each treadmill level is called and what it looks like: the belt's ridges take the tier's colour (and glow from Neon up), so
-- an upgrade is something you can see from across the plaza. Pure data; the server paints the parts.
local TreadmillTier = {}

export type Tier = { name: string, color: { number }, glow: boolean }

TreadmillTier.List = {
	{ name = "Rusty", color = { 150, 110, 90 }, glow = false },
	{ name = "Basic", color = { 110, 118, 140 }, glow = false },
	{ name = "Bronze", color = { 190, 120, 62 }, glow = false },
	{ name = "Silver", color = { 205, 212, 226 }, glow = false },
	{ name = "Gold", color = { 245, 195, 45 }, glow = false },
	{ name = "Platinum", color = { 190, 232, 245 }, glow = false },
	{ name = "Ruby", color = { 225, 45, 75 }, glow = false },
	{ name = "Emerald", color = { 45, 205, 115 }, glow = false },
	{ name = "Sapphire", color = { 55, 115, 245 }, glow = false },
	{ name = "Neon", color = { 60, 255, 175 }, glow = true },
	{ name = "Cosmic", color = { 140, 95, 255 }, glow = true },
	{ name = "Galaxy", color = { 255, 90, 215 }, glow = true },
	{ name = "Divine", color = { 255, 252, 235 }, glow = true },
} :: { Tier }

-- The tier of a treadmill at this upgrade level (0 to MAX).
function TreadmillTier.of(level: number): Tier
	local index = math.clamp(math.floor(level), 0, #TreadmillTier.List - 1) + 1
	return TreadmillTier.List[index]
end

return TreadmillTier
