--!strict
-- What you see while you carry a stolen egg: the egg floats above your head (Gold and Rainbow ones shine), a blue speed trail
-- streams behind you, and a light glows. It follows the "Carrying" attribute the server publishes, so it appears when you
-- steal, disappears when you deliver, drop or are caught, and comes back if your character respawns mid-run.
local Players = game:GetService("Players")

local Look = require(script.Parent.Look)
local World = require(script.Parent.World)

local Carry = {}

local function clear(character: Model)
	for _, name in { "CarryEgg", "TrailTop", "TrailBottom", "CarryTrail" } do
		local old = character:FindFirstChild(name, true)
		if old then
			old:Destroy()
		end
	end
end

-- Builds, updates or removes the carried egg on this player's character to match their attributes.
function Carry.sync(player: Player)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not character or not root then
		return
	end
	local tier = player:GetAttribute("Carrying")
	if typeof(tier) ~= "string" or tier == "" then
		clear(character)
		return
	end
	local mutation = player:GetAttribute("CarryingMutation")
	local mutationName = if typeof(mutation) == "string" then mutation else "Normal"
	local egg = character:FindFirstChild("CarryEgg") :: Part?
	if not egg then
		local part = Instance.new("Part")
		part.Name = "CarryEgg"
		World.roundify(part)
		part.Size = Vector3.new(3.4, 4.4, 3.4)
		part.CanCollide = false
		part.Massless = true
		part.Anchored = false
		part.TopSurface = Enum.SurfaceType.Smooth
		part.BottomSurface = Enum.SurfaceType.Smooth
		part.CFrame = root.CFrame * CFrame.new(0, 4.8, 0)
		part.Parent = character
		local weld = Instance.new("Weld")
		weld.Part0 = root
		weld.Part1 = part
		weld.C0 = CFrame.new(0, 4.8, 0)
		weld.Parent = part
		local light = Instance.new("PointLight")
		light.Range = 14
		light.Brightness = 1.4
		light.Parent = part
		-- the speed trail needs two points on the body to stretch a ribbon between
		local top = Instance.new("Attachment")
		top.Name = "TrailTop"
		top.Position = Vector3.new(0, 1.2, 0)
		top.Parent = root
		local bottom = Instance.new("Attachment")
		bottom.Name = "TrailBottom"
		bottom.Position = Vector3.new(0, -1.4, 0)
		bottom.Parent = root
		local trail = Instance.new("Trail")
		trail.Name = "CarryTrail"
		trail.Attachment0 = top
		trail.Attachment1 = bottom
		trail.Lifetime = 0.55
		trail.Color = ColorSequence.new(Color3.fromRGB(110, 220, 255), Color3.fromRGB(40, 120, 255))
		trail.Transparency = NumberSequence.new(0.1, 1)
		trail.LightEmission = 0.6
		trail.Parent = root
		egg = part
	end
	local shape = egg :: Part
	shape.Color = Look.eggColor(tier, mutationName)
	shape.Material = if Look.isMutated(mutationName) then Enum.Material.Neon else Enum.Material.SmoothPlastic
	local light = shape:FindFirstChildOfClass("PointLight")
	if light then
		light.Color = shape.Color
	end
end

function Carry.start()
	local function watch(player: Player)
		player:GetAttributeChangedSignal("Carrying"):Connect(function()
			Carry.sync(player)
		end)
		player:GetAttributeChangedSignal("CarryingMutation"):Connect(function()
			Carry.sync(player)
		end)
		player.CharacterAdded:Connect(function()
			task.defer(Carry.sync, player) -- a fresh character: carry on if the run was still going
		end)
	end
	Players.PlayerAdded:Connect(watch)
	for _, player in Players:GetPlayers() do
		watch(player)
	end
end

return Carry
