--!strict
-- Paints a treadmill to match its upgrade level: rusty corroded metal at the start, then metals, gems, neon, and finally a glowing
-- divine machine with light strips, a lamp and sparkles. The look of each tier is data in Shared/Game/TreadmillTier.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local TreadmillTier = require(ReplicatedStorage.Shared.Game.TreadmillTier)
local World = require(script.Parent.World)

local TreadmillPaint = {}

local FRAME_PARTS = { TreadRail = true, ConsoleLeg = true, Handrail = true, ConsoleBar = true, Roller = true }

local function rgb(c: { number }): Color3
	return Color3.fromRGB(c[1], c[2], c[3])
end

function TreadmillPaint.apply(plot: World.Plot, level: number)
	local tier = TreadmillTier.of(level)
	local accent, body = rgb(tier.color), rgb(tier.body)
	local material = (Enum.Material :: any)[tier.material] :: Enum.Material
	plot.display.title.Text = `{string.upper(tier.name)} TREADMILL`
	plot.treadmill.Color = Color3.new(accent.R * 0.28, accent.G * 0.28, accent.B * 0.28)
	for _, part in plot.model:GetChildren() do
		if not part:IsA("BasePart") then
			continue
		end
		if FRAME_PARTS[part.Name] then
			part.Color = body
			part.Material = material
		elseif part.Name == "Ridge" then
			part.Color = accent
			part.Material = if tier.glow then Enum.Material.Neon else Enum.Material.SmoothPlastic
		elseif part.Name == "TierGlow" then
			-- the light strips fade in from the Silver tier
			part.Color = accent
			part.Material = Enum.Material.Neon
			part.Transparency = if tier.light <= 0 then 1 else 0.55 - 0.5 * tier.light
		end
	end
	local lamp = plot.treadmill:FindFirstChild("TierLight")
	if lamp and lamp:IsA("PointLight") then
		lamp.Color = accent
		lamp.Brightness = tier.light * 2.2
	end
	local sparkles = plot.treadmill:FindFirstChild("TierSparkles")
	if sparkles and sparkles:IsA("ParticleEmitter") then
		sparkles.Color = ColorSequence.new(accent, Color3.new(1, 1, 1))
		sparkles.Enabled = tier.sparkles
	end
end

return TreadmillPaint
