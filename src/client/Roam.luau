--!strict
-- Pets walk around their patch of the pen instead of standing on the pedestal. The server tags each pet "RoamPet" with its
-- seed; every client works out the same walk from the shared clock (Shared/Game/Wander), so nothing is sent and nothing jitters.
-- Only pets near the camera are moved, and the walk is one PivotTo per pet per frame.
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Wander = require(ReplicatedStorage.Shared.Game.Wander)

local Roam = {}

local NEAR = 140 -- studs from the camera: pets further away stay put
local TURN = 8 -- how quickly a pet turns to face where it walks (per second)
local BOB = 0.22 -- studs the body rises on each step
local IDLE_BOB = 0.05 -- studs of the slow breathing bob when it stands still

type Pet = { home: CFrame, yaw: number, radius: number, seed: number }
local pets: { [Model]: Pet } = {}

local function add(model: Instance)
	if not model:IsA("Model") then
		return
	end
	local home = model:GetPivot()
	local _, yaw, _ = home:ToEulerAnglesYXZ()
	pets[model] = {
		home = home,
		yaw = yaw,
		radius = (model:GetAttribute("RoamRadius") :: number?) or 3,
		seed = (model:GetAttribute("RoamSeed") :: number?) or 1,
	}
end

function Roam.start()
	for _, model in CollectionService:GetTagged("RoamPet") do
		add(model)
	end
	CollectionService:GetInstanceAddedSignal("RoamPet"):Connect(add)
	CollectionService:GetInstanceRemovedSignal("RoamPet"):Connect(function(model)
		pets[model :: Model] = nil
	end)
	RunService.RenderStepped:Connect(function(dt)
		local camera = workspace.CurrentCamera
		if not camera then
			return
		end
		local eye = camera.CFrame.Position
		local now = workspace:GetServerTimeNow()
		for model, pet in pets do
			if not model.Parent then
				pets[model] = nil
			elseif (pet.home.Position - eye).Magnitude < NEAR then
				local pose = Wander.pose(pet.seed, now, pet.radius)
				if pose.walking then
					local want = math.atan2(-pose.dirX, -pose.dirZ)
					local diff = (want - pet.yaw + math.pi) % (2 * math.pi) - math.pi
					pet.yaw += diff * math.min(1, TURN * dt)
				end
				-- a hop on each step; a slow breathing bob while it rests
				local lift = if pose.walking
					then math.abs(math.sin(pose.stride * math.pi)) * BOB
					else (1 + math.sin(now * 2.2 + pet.seed)) * IDLE_BOB
				local at = pet.home.Position + Vector3.new(pose.x, lift, pose.z)
				model:PivotTo(CFrame.new(at) * CFrame.Angles(0, pet.yaw, 0))
			end
		end
	end)
end

return Roam
