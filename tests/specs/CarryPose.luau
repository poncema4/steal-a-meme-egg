--!nocheck
-- A player carrying an egg holds it over their head with both arms raised; when the egg is gone the pose stops and the walk
-- animation takes the arms back. Works for classic Motor6D shoulders (R15, R6) and Roblox's upgraded joints (AnimationConstraint).
local Fake = require("../fake/Roblox")

local function rig(world, kind: string)
	local Instance = world.instance
	local character = Instance.new("Model")
	character.Name = "Rig"
	local function joint(parentName: string, name: string)
		local parent = character:FindFirstChild(parentName) or Instance.new("Part")
		parent.Name = parentName
		parent.Parent = character
		local j = Instance.new(if kind == "Upgraded" then "AnimationConstraint" else "Motor6D")
		j.Name = name
		j.Transform = world.CFrame.new(0, 0, 0)
		j.Parent = parent
		return j
	end
	if kind == "R6" then
		return character, joint("Torso", "Right Shoulder"), joint("Torso", "Left Shoulder")
	end
	return character, joint("RightUpperArm", "RightShoulder"), joint("LeftUpperArm", "LeftShoulder")
end

return function(t)
	local world = Fake.world()
	local CarryPose = world.load("src/client/CarryPose")
	CarryPose.start()
	local function raised(j: any): boolean
		return j.Transform.LookVector.Z > -0.5 or j.Transform.UpVector.Y < 0
	end
	for i, kind in { "R15", "R6", "Upgraded" } do
		local character, right, left = rig(world, kind)
		t.equal(`{kind}: both shoulders are found`, #CarryPose.joints(character), 2)
		local ana = world.addPlayer(`Ana{kind}`, 80 + i)
		ana.Character = character
		world.advance(0.1)
		t.check(`{kind}: arms hang normally with empty hands`, not raised(right))
		ana:SetAttribute("Carrying", "Soggy")
		world.advance(0.1)
		t.check(`{kind}: carrying an egg raises the right arm`, raised(right))
		t.check(`{kind}: and the left arm`, raised(left))
		right.Transform = world.CFrame.new(0, 0, 0) -- the walk animation writes the joint again on the next frame...
		world.advance(0.1)
		t.check(`{kind}: ...and the pose wins again, every frame`, raised(right))
		ana:SetAttribute("Carrying", "")
		right.Transform = world.CFrame.new(0, 0, 0)
		world.advance(0.1)
		t.check(`{kind}: after the egg is gone the animation keeps the arms`, not raised(right))
	end
end
