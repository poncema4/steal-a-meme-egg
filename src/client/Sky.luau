--!strict
-- The sky follows day and night: when night falls it fades to a dark, starry night, and at the end of the dawn back to day.
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Sky = {}

Sky.DAY = { ClockTime = 14, Brightness = 3, Ambient = Color3.fromRGB(120, 120, 130) }
Sky.NIGHT = { ClockTime = 0.5, Brightness = 1, Ambient = Color3.fromRGB(60, 60, 110) }
Sky.DAWN = { ClockTime = 6.3, Brightness = 2, Ambient = Color3.fromRGB(150, 120, 120) }

function Sky.start()
	local function apply()
		local phase = ReplicatedStorage:GetAttribute("Phase")
		local goal = if phase == "Night" then Sky.NIGHT elseif phase == "Dawn" then Sky.DAWN else Sky.DAY
		pcall(function()
			TweenService:Create(Lighting, TweenInfo.new(2.5), goal :: any):Play()
		end)
	end
	ReplicatedStorage:GetAttributeChangedSignal("Phase"):Connect(apply)
	apply()
end

return Sky
