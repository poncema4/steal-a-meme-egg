--!strict
-- Pets walk around their pen instead of standing on a pedestal. The server tags each pet "RoamPet" with its seed, the centre of the
-- patch it roams (RoamCentre) and how far it may go; every client works out the same walk from the shared clock
-- (Shared/Game/Wander), so nothing is sent and nothing jitters. A pet's own height comes from where the server stood it, read
-- only once it is really in the world (a model read too early sits at the map's origin, which threw pets across the map).
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Wander = require(ReplicatedStorage.Shared.Game.Wander)

local Roam = {}

local NEAR = 160 -- studs from the camera: pets further away stay put
local TURN = 8 -- how quickly a pet turns to face where it walks (per second)
local BOB = 0.22 -- studs the body rises on each step
local IDLE_BOB = 0.05 -- studs of the slow breathing bob when it stands still

type Pet = { height: number?, yaw: number, radius: number, seed: number, centre: Vector3 }
local pets: { [Model]: Pet } = {}

local function add(model: Instance)
	if not model:IsA("Model") then
		return
	end
	local centre = model:GetAttribute("RoamCentre")
	pets[model] = {
		height = nil,
		yaw = 0,
		radius = (model:GetAttribute("RoamRadius") :: number?) or 3,
		seed = (model:GetAttribute("RoamSeed") :: number?) or 1,
		centre = if typeof(centre) == "Vector3" then centre else Vector3.zero,
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
			-- one pet that cannot be moved must never stop the others (or the rest of the client): a failure is shown once and skipped
			local ok, problem = pcall(function()
				if not model.Parent then
					pets[model] = nil
				elseif model:IsDescendantOf(workspace) then
					local pivot = model:GetPivot()
					if not pet.height then
						-- the first time we see it in the world: its height and the way it faces are where the server put it
						pet.height = pivot.Position.Y
						local _, yaw, _ = pivot.Rotation:ToEulerAnglesYXZ()
						pet.yaw = yaw
					end
					if (pet.centre - eye).Magnitude < NEAR then
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
						local at =
							Vector3.new(pet.centre.X + pose.x, (pet.height :: number) + lift, pet.centre.Z + pose.z)
						model:PivotTo(CFrame.new(at) * CFrame.Angles(0, pet.yaw, 0))
					end
				end
			end)
			if not ok then
				pets[model] = nil
				warn(`pet could not roam: {problem}`)
			end
		end
	end)
end

return Roam
