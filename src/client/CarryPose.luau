--!strict
-- Anyone carrying a stolen egg holds it up over their head with both arms raised (Marco: "their avatar is holding it and their
-- arms are raised"). Every client poses every carrier, so everyone sees it. The pose turns each shoulder joint's C0, which no
-- animation touches (setting Motor6D.Transform was overwritten by the walk animation in Studio), and puts C0 back afterwards;
-- the walk animation still swings the arms a little on top of the raised pose, and the legs run as usual.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local CarryPose = {}

-- R15 shoulders turn the arm straight up with a half turn about X; a small tilt outward keeps the hands on the egg's sides.
-- R6 shoulders turn about their own Z axis.
local R15_RIGHT = CFrame.Angles(math.rad(170), 0, math.rad(-12))
local R15_LEFT = CFrame.Angles(math.rad(170), 0, math.rad(12))
local R6_UP = CFrame.Angles(0, 0, math.pi)

-- The shoulder joints of a character and the pose each one takes, or nothing for an unknown rig.
function CarryPose.joints(character: Model): { { motor: Motor6D, pose: CFrame } }
	local out = {}
	local function add(parent: Instance?, name: string, pose: CFrame)
		local motor = parent and parent:FindFirstChild(name)
		if motor and motor:IsA("Motor6D") then
			table.insert(out, { motor = motor, pose = pose })
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

-- the joint's own resting C0 is kept on the joint (an attribute) while the arms are up, so it is put back exactly
local REST = "CarryRestC0"

local function pose(character: Model, on: boolean)
	for _, joint in CarryPose.joints(character) do
		local motor = joint.motor
		local saved = motor:GetAttribute(REST)
		if on and saved == nil then
			motor:SetAttribute(REST, motor.C0)
			motor.C0 = motor.C0 * joint.pose
		elseif not on and typeof(saved) == "CFrame" then
			motor.C0 = saved
			motor:SetAttribute(REST, nil)
		end
	end
end

-- Raises the arms of every player who carries an egg, and lowers them again when they stop.
function CarryPose.update()
	for _, player in Players:GetPlayers() do
		local character = player.Character
		if character then
			pose(character, carrying(player))
		end
	end
end

function CarryPose.start()
	RunService.Stepped:Connect(CarryPose.update)
end

return CarryPose
