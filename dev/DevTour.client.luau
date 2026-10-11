--!nocheck
-- DEVELOPMENT ONLY (never in the game build: it is added by scripts/dev_tour.py). When you press Play in Studio this glides the
-- camera through preset viewpoints and prints "TOUR <name>" for each one, so a screenshot tool can photograph the world with no input.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera
local focusRemote = ReplicatedStorage:WaitForChild("DevTourFocus")

local PLAZA = Vector3.new(-20, 0, 0)

-- the player's own base (the server assigns it a moment after joining)
local function myPlot()
	local map = workspace:WaitForChild("Map")
	for _ = 1, 60 do
		for _, plot in map:GetChildren() do
			if plot:GetAttribute("OwnerUserId") == player.UserId then
				return plot
			end
		end
		task.wait(0.5)
	end
	return nil
end

local plot = myPlot()
local center = if plot then plot:GetPivot().Position else Vector3.new(-100, 0, 0)
local front = Vector3.new(PLAZA.X - center.X, 0, PLAZA.Z - center.Z).Unit
local right = front:Cross(Vector3.yAxis)

-- {name, camera position, look at}
local views = {
	{ "plaza", Vector3.new(8, 55, 0), Vector3.new(-110, 0, 0) },
	{ "base", center + front * 34 + Vector3.new(0, 20, 0), center },
	{ "treadmill", center + front * 25 + right * 14 + Vector3.new(0, 8, 0), center + front * 22 },
	{ "pets", center - front * 4 + right * 3 + Vector3.new(0, 7, 0), center + front * 8 - right * 4 },
	{ "meadow", Vector3.new(60, 34, -70), Vector3.new(130, 4, 0) },
	{ "meadow_boss", Vector3.new(130, 12, -34), Vector3.new(130, 6, 0) },
	{ "dune", Vector3.new(300, 36, -70), Vector3.new(370, 4, 0) },
	{ "dune_boss", Vector3.new(370, 12, -34), Vector3.new(370, 6, 0) },
	{ "volcano", Vector3.new(540, 36, -70), Vector3.new(610, 4, 0) },
	{ "volcano_boss", Vector3.new(610, 12, -34), Vector3.new(610, 6, 0) },
	{ "frost", Vector3.new(780, 36, -70), Vector3.new(850, 4, 0) },
	{ "frost_boss", Vector3.new(850, 12, -34), Vector3.new(850, 6, 0) },
	{ "cosmic", Vector3.new(1020, 36, -70), Vector3.new(1090, 4, 0) },
	{ "cosmic_boss", Vector3.new(1090, 12, -34), Vector3.new(1090, 6, 0) },
}

camera.CameraType = Enum.CameraType.Scriptable
task.wait(2)
for _, view in views do
	focusRemote:FireServer(view[2]) -- the world around the camera has to be streamed in
	camera.CFrame = CFrame.lookAt(view[2], view[3])
	task.wait(5) -- time for the terrain to arrive
	print("TOUR " .. view[1])
	task.wait(5)
end
print("TOUR done")
