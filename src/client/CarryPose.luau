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

-- The shoulder joints of a character and the pose each one takes, or nothing for an unknown rig. A joint is a classic Motor6D
-- (turned through its C0) or, with Roblox's avatar joint upgrade, an AnimationConstraint (turned through its torso-side
-- attachment); animations touch neither, so the pose holds while the walk animation plays.
export type Joint = { target: Instance, pose: CFrame }
function CarryPose.joints(character: Model): { Joint }
	local out: { Joint } = {}
	local function add(parent: Instance?, name: string, pose: CFrame)
		local joint = parent and parent:FindFirstChild(name)
		if joint and joint:IsA("Motor6D") then
			table.insert(out, { target = joint :: Instance, pose = pose })
		elseif joint and joint:IsA("AnimationConstraint") then
			local attachment = (joint :: AnimationConstraint).Attachment0
			if attachment then
				table.insert(out, { target = attachment :: Instance, pose = pose })
			end
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

-- the joint's own resting frame is kept on it (an attribute) while the arms are up, so it is put back exactly
local REST = "CarryRest"

local function frameOf(target: Instance): CFrame
	return if target:IsA("Motor6D") then (target :: Motor6D).C0 else (target :: Attachment).CFrame
end

local function setFrame(target: Instance, cf: CFrame)
	if target:IsA("Motor6D") then
		(target :: Motor6D).C0 = cf
	else
		(target :: Attachment).CFrame = cf
	end
end

local function pose(character: Model, on: boolean)
	for _, joint in CarryPose.joints(character) do
		local target = joint.target
		local saved = target:GetAttribute(REST)
		if on and saved == nil then
			local rest = frameOf(target)
			target:SetAttribute(REST, rest)
			setFrame(target, rest * joint.pose)
		elseif not on and typeof(saved) == "CFrame" then
			setFrame(target, saved)
			target:SetAttribute(REST, nil)
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
