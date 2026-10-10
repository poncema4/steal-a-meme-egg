--!strict
-- The client half of the treadmill lock. While the server says you are locked on your belt (TreadmillLocked) this module runs
-- for you: it stops the normal movement controls and calls Humanoid:Move toward the belt's front every frame, so the run
-- animation plays with no key held. Jump (Space, gamepad A) or the Jump off button on screen tells the server you want off.
local ContextActionService = game:GetService("ContextActionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local TreadmillRun = {}

local ACTION_LEAVE = "TreadmillLeave"
local ACTION_SINK = "TreadmillSink"

-- the default controls (keyboard, thumbstick, touch pad); nil if the PlayerModule is not there (a test, or an odd setup)
local function controls(player: Player): any
	local scripts = player:FindFirstChild("PlayerScripts")
	local module = scripts and scripts:FindFirstChild("PlayerModule")
	if not module then
		return nil
	end
	local ok, result = pcall(function()
		return (require(module :: ModuleScript) :: any):GetControls()
	end)
	return if ok then result else nil
end

function TreadmillRun.start(player: Player)
	local remote = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("LeaveTreadmill") :: RemoteEvent
	local active = false

	local function engage()
		if active then
			return
		end
		active = true
		local c = controls(player)
		if c then
			c:Disable()
		end
		-- belt and braces: keys and sticks do nothing while you are on it
		ContextActionService:BindActionAtPriority(
			ACTION_SINK,
			function()
				return Enum.ContextActionResult.Sink
			end,
			false,
			Enum.ContextActionPriority.High.Value,
			Enum.KeyCode.W,
			Enum.KeyCode.A,
			Enum.KeyCode.S,
			Enum.KeyCode.D,
			Enum.KeyCode.Up,
			Enum.KeyCode.Down,
			Enum.KeyCode.Left,
			Enum.KeyCode.Right,
			Enum.KeyCode.Thumbstick1
		)
		ContextActionService:BindActionAtPriority(ACTION_LEAVE, function(_, state)
			if state == Enum.UserInputState.Begin then
				remote:FireServer()
			end
			return Enum.ContextActionResult.Sink
		end, false, Enum.ContextActionPriority.High.Value, Enum.KeyCode.Space, Enum.KeyCode.ButtonA)
	end

	local function release()
		if not active then
			return
		end
		active = false
		ContextActionService:UnbindAction(ACTION_SINK)
		ContextActionService:UnbindAction(ACTION_LEAVE)
		local c = controls(player)
		if c then
			c:Enable()
		end
	end

	RunService.RenderStepped:Connect(function()
		local locked = player:GetAttribute("TreadmillLocked") == true
		if locked then
			engage()
			local character = player.Character
			local humanoid = character and character:FindFirstChildOfClass("Humanoid")
			local front = player:GetAttribute("TreadmillFront")
			if humanoid and typeof(front) == "Vector3" then
				humanoid:Move(front, false)
			end
		else
			release()
		end
	end)
	-- if the character respawns while locked, give the controls back
	player.CharacterRemoving:Connect(release)
end

return TreadmillRun
