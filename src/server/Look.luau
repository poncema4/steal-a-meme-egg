--!strict
-- How eggs are coloured, in one place (the nests, the pens and the egg you carry all use it).
local Look = {}

Look.TierColors = {
	Soggy = Color3.fromRGB(235, 225, 190),
	Disco = Color3.fromRGB(255, 120, 220),
	Spicy = Color3.fromRGB(255, 90, 40),
	Golden = Color3.fromRGB(255, 205, 40),
	Cosmic = Color3.fromRGB(110, 90, 255),
	Divine = Color3.fromRGB(255, 255, 255),
} :: { [string]: Color3 }

Look.MutationColors = {
	Gold = Color3.fromRGB(255, 205, 40),
	Rainbow = Color3.fromRGB(255, 120, 200),
} :: { [string]: Color3 }

-- The colour of an egg of this tier with this mutation (a mutation overrides the tier colour).
function Look.eggColor(tier: string, mutation: string?): Color3
	local tint = if mutation then Look.MutationColors[mutation] else nil
	return tint or Look.TierColors[tier] or Color3.new(1, 1, 1)
end

function Look.isMutated(mutation: string?): boolean
	if mutation == nil then
		return false
	end
	local tint: Color3? = Look.MutationColors[mutation]
	return tint ~= nil
end

return Look
