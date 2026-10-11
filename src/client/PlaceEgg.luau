--!strict
-- Putting a stolen egg down in your pen, like Steal an Egg: while you carry one and stand in your pen, click (PC), tap (phone)
-- or press R1 (gamepad, where the camera looks) on the ground and the egg goes there. A see-through marker follows the mouse
-- so you see the spot first. The server checks it is your pen and keeps eggs from overlapping.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local PlaceEgg = {}

local function active(player: Player): boolean
	local carrying = player:GetAttribute("Carrying")
	return typeof(carrying) == "string" and carrying ~= "" and player:GetAttribute("InPen") == true
end

-- Where a screen point lands on the ground (the player's own character is ignored), or nil.
function PlaceEgg.groundAt(player: Player, screen: Vector2): Vector3?
	local camera = workspace.CurrentCamera
	if not camera then
		return nil
	end
	local ray = camera:ViewportPointToRay(screen.X, screen.Y)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = if player.Character then { player.Character } else {}
	local hit = workspace:Raycast(ray.Origin, ray.Direction * 300, params)
	return if hit then hit.Position else nil
end

function PlaceEgg.start(player: Player)
	local remote = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("PlaceEgg") :: RemoteEvent
	local marker = Instance.new("Part")
	marker.Name = "EggSpotMarker"
	marker.Shape = Enum.PartType.Cylinder
	marker.Size = Vector3.new(0.2, 5, 5)
	marker.Anchored = true
	marker.CanCollide = false
	marker.CanQuery = false
	marker.Transparency = 1
	marker.Color = Color3.fromRGB(90, 255, 120)
	marker.Material = Enum.Material.Neon
	marker.Parent = workspace

	local function place(screen: Vector2)
		local at = PlaceEgg.groundAt(player, screen)
		if at then
			remote:FireServer(at)
		end
	end
	UserInputService.InputBegan:Connect(function(input, processed)
		if processed or not active(player) then
			return
		end
		local kind = input.UserInputType
		if kind == Enum.UserInputType.MouseButton1 or kind == Enum.UserInputType.Touch then
			place(Vector2.new(input.Position.X, input.Position.Y))
		elseif input.KeyCode == Enum.KeyCode.ButtonR1 then
			local camera = workspace.CurrentCamera
			if camera then
				place(camera.ViewportSize / 2)
			end
		end
	end)
	-- the marker: where a click would put the egg (mouse only; a phone has no hover)
	RunService.RenderStepped:Connect(function()
		local show = active(player) and UserInputService.MouseEnabled
		local at = if show then PlaceEgg.groundAt(player, UserInputService:GetMouseLocation()) else nil
		if at then
			marker.CFrame = CFrame.new(at + Vector3.new(0, 0.12, 0)) * CFrame.Angles(0, 0, math.pi / 2)
			marker.Transparency = 0.45
		else
			marker.Transparency = 1
		end
	end)
end

PlaceEgg.active = active

return PlaceEgg
