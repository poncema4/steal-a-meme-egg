--!strict
-- Money floating up over the pets, like the reference: every second or so a green "+$1.8B" rises from one of the characters in
-- every occupied base (yours and everyone else's), sized to what that base earns. Purely visual and made on the client, so it costs
-- the server nothing.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Economy = require(ReplicatedStorage.Shared.Game.Economy)

local Floaters = {}

local PERIOD = 1.2 -- seconds between floaters in one base
local RISE = 5 -- studs they climb
local LIFE = 1.4 -- seconds they last

-- Which pedestals of this base hold a character right now.
local function petSpots(plot: Instance): { BasePart }
	local out = {}
	for _, child in plot:GetChildren() do
		if string.match(child.Name, "^Slot_") and child:IsA("BasePart") and child:FindFirstChild("Item") then
			table.insert(out, child)
		end
	end
	return out
end

function Floaters.spawn(spot: BasePart, text: string)
	local gui = Instance.new("BillboardGui")
	gui.Name = "MoneyFloater"
	gui.Size = UDim2.fromOffset(150, 40)
	gui.StudsOffset = Vector3.new(0, 5, 0)
	gui.AlwaysOnTop = true
	gui.MaxDistance = 140
	gui.Parent = spot
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.TextColor3 = Color3.fromRGB(70, 255, 90)
	label.TextStrokeTransparency = 0
	label.Text = text
	label.Parent = gui
	local info = TweenInfo.new(LIFE, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	TweenService:Create(gui, info, { StudsOffset = Vector3.new(0, 5 + RISE, 0) }):Play()
	TweenService:Create(label, info, { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
	task.delay(LIFE + 0.1, function()
		gui:Destroy()
	end)
end

function Floaters.start()
	task.spawn(function()
		while true do
			task.wait(PERIOD)
			local map = workspace:FindFirstChild("Map")
			if map then
				for _, plot in map:GetChildren() do
					local ownerId = plot:GetAttribute("OwnerUserId")
					local owner = if typeof(ownerId) == "number" and ownerId ~= 0
						then Players:GetPlayerByUserId(ownerId)
						else nil
					local income = if owner then owner:GetAttribute("Income") else nil
					if owner and typeof(income) == "number" and income > 0 then
						local spots = petSpots(plot)
						if #spots > 0 then
							-- one floater per second-and-a-bit, showing what the whole base earned in that time
							Floaters.spawn(spots[math.random(1, #spots)], `+${Economy.format(income * PERIOD)}`)
						end
					end
				end
			end
		end
	end)
end

return Floaters
