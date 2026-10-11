--!nocheck
-- DEVELOPMENT ONLY. Lets the tour camera pull the world in around itself (streaming follows ReplicationFocus, which only the server can set).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local remote = Instance.new("RemoteEvent")
remote.Name = "DevTourFocus"
remote.Parent = ReplicatedStorage

local focus = Instance.new("Part")
focus.Name = "DevTourFocus"
focus.Anchored = true
focus.CanCollide = false
focus.CanQuery = false
focus.Transparency = 1
focus.Size = Vector3.one
focus.Parent = workspace

remote.OnServerEvent:Connect(function(player: Player, position: any)
	if typeof(position) == "Vector3" and Players:FindFirstChild(player.Name) then
		focus.Position = position
		player.ReplicationFocus = focus
	end
end)
