--!nocheck
-- A player carrying an egg holds it over their head with both arms raised; the arms come down when they stop carrying.
local Fake = require("../fake/Roblox")

local function rig(world, kind: string)
	local Instance = world.instance
	local character = Instance.new("Model")
	character.Name = "Rig"
	local function motor(parentName: string, name: string)
		local parent = character:FindFirstChild(parentName) or Instance.new("Part")
		parent.Name = parentName
		parent.Parent = character
		local m = Instance.new("Motor6D")
		m.Name = name
		m.Transform = world.CFrame.new(0, 0, 0)
		m.C0 = world.CFrame.new(0, 0, 0)
		m.Parent = parent
		return m
	end
	-- Roblox's avatar joint upgrade: the joint is an AnimationConstraint between two attachments
	local function constraint(parentName: string, name: string)
		local parent = Instance.new("Part")
		parent.Name = parentName
		parent.Parent = character
		local a0 = Instance.new("Attachment")
		a0.Name = `{name}RigAttachment`
		a0.CFrame = world.CFrame.new(0, 0, 0)
		a0.Parent = character
		local c = Instance.new("AnimationConstraint")
		c.Name = name
		c.Attachment0 = a0
		c.Parent = parent
		return a0
	end
	if kind == "R15" then
		return character, motor("RightUpperArm", "RightShoulder"), motor("LeftUpperArm", "LeftShoulder")
	elseif kind == "Upgraded" then
		return character, constraint("RightUpperArm", "RightShoulder"), constraint("LeftUpperArm", "LeftShoulder")
	end
	return character, motor("Torso", "Right Shoulder"), motor("Torso", "Left Shoulder")
end

return function(t)
	local world = Fake.world()
	local CarryPose = world.load("src/client/CarryPose")
	local function frame(m: any): any
		return if m:IsA("Motor6D") then m.C0 else m.CFrame
	end
	local function raised(m: any): boolean
		return frame(m).LookVector.Z > -0.5 or frame(m).UpVector.Y < 0
	end
	for _, kind in { "R15", "R6", "Upgraded" } do
		local character, right, left = rig(world, kind)
		t.equal(`{kind}: both shoulders are found`, #CarryPose.joints(character), 2)
		local ana = world.addPlayer(`Ana{kind}`, if kind == "R15" then 81 elseif kind == "R6" then 82 else 83)
		ana.Character = character
		CarryPose.start()
		world.advance(0.1)
		local restC0 = frame(right)
		t.check(`{kind}: arms hang normally with empty hands`, not raised(right))
		ana:SetAttribute("Carrying", "Soggy")
		world.advance(0.1)
		t.check(`{kind}: carrying an egg raises the right arm`, raised(right))
		t.check(`{kind}: and the left arm`, raised(left))
		world.advance(1)
		t.check(`{kind}: it stays raised (the pose is not stacked every frame)`, raised(right))
		ana:SetAttribute("Carrying", "")
		world.advance(0.1)
		t.check(`{kind}: the arms come down after the egg is delivered`, frame(right) == restC0 and not raised(right))
	end
end
