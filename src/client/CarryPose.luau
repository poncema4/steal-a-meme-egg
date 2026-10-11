--!strict
-- Anyone carrying a stolen egg holds it up over their head with both arms raised (Marco: "their avatar is holding it and their
-- arms are raised"). Every client poses every carrier, so everyone sees it. Each frame, right after the walk animation has set the
-- joints, this sets the shoulder joint's Transform (PreSimulation). That works for a classic Motor6D and for Roblox's upgraded
-- avatar joints (an AnimationConstraint): seen working in Studio. Turning C0 or the joint's attachment did NOT move an upgraded arm.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local CarryPose = {}

-- R15 shoulders turn the arm straight up with a half turn about X; a small tilt outward keeps the hands on the egg's sides.
-- R6 shoulders turn about their own Z axis.
local R15_RIGHT = CFrame.Angles(math.rad(170), 0, math.rad(-12))
local R15_LEFT = CFrame.Angles(math.rad(170), 0, math.rad(12))
local R6_UP = CFrame.Angles(0, 0, math.pi)

export type Joint = { joint: Instance, pose: CFrame }

-- The shoulder joints of a character (Motor6D or AnimationConstraint) and the pose each one takes; nothing for an unknown rig.
function CarryPose.joints(character: Model): { Joint }
	local out: { Joint } = {}
	local function add(parent: Instance?, name: string, pose: CFrame)
		local joint = parent and parent:FindFirstChild(name)
		if joint and (joint:IsA("Motor6D") or joint:IsA("AnimationConstraint")) then
			table.insert(out, { joint = joint :: Instance, pose = pose })
		end
	end
	add(character:FindFirstChild("RightUpperArm"), "RightShoulder", R15_RIGHT)
	add(character:FindFirstChild("LeftUpperArm"), "LeftShoulder", R15_LEFT)
	local torso = character:FindFirstChild("Torso")
	add(torso, "Right Shoulder", R6_UP)
	add(torso, "Left Shoulder", R6_UP)
	return out
end

local function carrying(player: Player): boolean
	local tier = player:GetAttribute("Carrying")
	return typeof(tier) == "string" and tier ~= ""
end

-- Raises the arms of every player who carries an egg. Called every frame after the animations; when the egg is gone the
-- animation simply writes the joints again on the next frame, so the arms come down by themselves.
function CarryPose.update()
	for _, player in Players:GetPlayers() do
		local character = player.Character
		if character and carrying(player) then
			for _, j in CarryPose.joints(character) do
				(j.joint :: any).Transform = j.pose
			end
		end
	end
end

function CarryPose.start()
	RunService.PreSimulation:Connect(CarryPose.update)
end

return CarryPose
