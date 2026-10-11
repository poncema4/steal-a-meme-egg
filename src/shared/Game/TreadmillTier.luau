--!strict
-- What each treadmill level is called and what it looks like: the belt's ridges take the tier's colour (and glow from Neon up), so
-- an upgrade is something you can see from across the plaza. Pure data; the server paints the parts.
local TreadmillTier = {}

export type Tier = {
	name: string,
	color: { number }, -- the accent: the ridges and the light strips
	body: { number }, -- the frame: rails, legs, handrails, rollers
	material: string, -- the frame's Enum.Material name
	glow: boolean, -- the ridges glow
	light: number, -- 0 to 1: how much the light strips and the lamp shine
	sparkles: boolean,
}

-- Rusty at the start, more splendid with every upgrade, Divine at the top.
TreadmillTier.List = {
	{
		name = "Rusty",
		color = { 170, 105, 70 },
		body = { 128, 80, 52 },
		material = "CorrodedMetal",
		glow = false,
		light = 0,
		sparkles = false,
	},
	{
		name = "Basic",
		color = { 120, 128, 150 },
		body = { 118, 124, 138 },
		material = "Metal",
		glow = false,
		light = 0,
		sparkles = false,
	},
	{
		name = "Bronze",
		color = { 205, 130, 66 },
		body = { 160, 104, 60 },
		material = "Metal",
		glow = false,
		light = 0,
		sparkles = false,
	},
	{
		name = "Silver",
		color = { 215, 222, 236 },
		body = { 190, 198, 212 },
		material = "Metal",
		glow = false,
		light = 0.15,
		sparkles = false,
	},
	{
		name = "Gold",
		color = { 250, 200, 50 },
		body = { 225, 175, 40 },
		material = "Metal",
		glow = false,
		light = 0.3,
		sparkles = false,
	},
	{
		name = "Platinum",
		color = { 200, 238, 250 },
		body = { 214, 232, 244 },
		material = "Metal",
		glow = false,
		light = 0.4,
		sparkles = false,
	},
	{
		name = "Ruby",
		color = { 235, 50, 80 },
		body = { 160, 28, 52 },
		material = "SmoothPlastic",
		glow = false,
		light = 0.5,
		sparkles = false,
	},
	{
		name = "Emerald",
		color = { 50, 215, 125 },
		body = { 28, 140, 86 },
		material = "SmoothPlastic",
		glow = false,
		light = 0.6,
		sparkles = false,
	},
	{
		name = "Sapphire",
		color = { 70, 130, 255 },
		body = { 36, 80, 186 },
		material = "SmoothPlastic",
		glow = false,
		light = 0.7,
		sparkles = false,
	},
	{
		name = "Neon",
		color = { 60, 255, 175 },
		body = { 22, 36, 48 },
		material = "Metal",
		glow = true,
		light = 0.8,
		sparkles = false,
	},
	{
		name = "Cosmic",
		color = { 150, 105, 255 },
		body = { 32, 22, 78 },
		material = "Metal",
		glow = true,
		light = 0.9,
		sparkles = true,
	},
	{
		name = "Galaxy",
		color = { 255, 95, 220 },
		body = { 58, 24, 72 },
		material = "Metal",
		glow = true,
		light = 1,
		sparkles = true,
	},
	{
		name = "Divine",
		color = { 255, 240, 170 },
		body = { 255, 248, 222 },
		material = "Neon",
		glow = true,
		light = 1,
		sparkles = true,
	},
} :: { Tier }

-- The tier of a treadmill at this upgrade level (0 to MAX).
function TreadmillTier.of(level: number): Tier
	local index = math.clamp(math.floor(level), 0, #TreadmillTier.List - 1) + 1
	return TreadmillTier.List[index]
end

return TreadmillTier
