--!strict
-- Runs day and night (Shared/Game/DayNight) on the server: when night falls everyone out in the Wilds is sent back to their base
-- and the egg they carry (or dropped) goes back to its nest; a wall with a moon and a countdown closes the Wilds for the night
-- and dawn, then drops. The phase is published (ReplicatedStorage "Phase", "PhaseEnds") for the sky and the HUD clock.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local DayNight = require(ReplicatedStorage.Shared.Game.DayNight)
local Zones = require(ReplicatedStorage.Shared.Game.Zones)
local Session = require(script.Parent.Session)
local Wilds = require(script.Parent.Wilds)
local World = require(script.Parent.World)

local NightCycle = {}

local wall: Part? = nil
local countdowns: { TextLabel } = {}
local notify: (Player, string) -> () = function(_player: Player, _text: string) end

local function buildWall(map: Instance)
	local x = World.SAFE_FRONT + 1
	local part = Instance.new("Part")
	part.Name = "NightWall"
	part.Anchored = true
	part.Size = Vector3.new(2, 40, Zones.WIDTH)
	part.CFrame = CFrame.new(x, 20, 0)
	part.Color = Color3.fromRGB(30, 26, 70)
	part.Material = Enum.Material.ForceField
	part.Transparency = 1
	part.CanCollide = false
	part.CanQuery = false
	part.Parent = map
	for _, face in { Enum.NormalId.Left, Enum.NormalId.Right } do
		local gui = Instance.new("SurfaceGui")
		gui.Face = face
		gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		gui.PixelsPerStud = 12
		gui.Enabled = false
		gui.Parent = part
		local label = Instance.new("TextLabel")
		label.Name = "Countdown"
		label.Size = UDim2.fromScale(0.5, 0.4)
		label.Position = UDim2.fromScale(0.25, 0.3)
		label.BackgroundTransparency = 1
		label.Font = Enum.Font.FredokaOne
		label.TextScaled = true
		label.TextColor3 = Color3.new(1, 1, 1)
		label.TextStrokeTransparency = 0
		label.Parent = gui
		table.insert(countdowns, label)
	end
	wall = part
end

local function setWall(closed: boolean, seconds: number)
	local part = wall
	if not part then
		return
	end
	part.CanCollide = closed
	part.Transparency = if closed then 0.35 else 1
	for _, label in countdowns do
		label.Text = `🌙 {math.ceil(seconds)}`
		local gui = label.Parent :: SurfaceGui
		gui.Enabled = closed
	end
end

-- Night falls: every player out in the Wilds goes home, and every carried or dropped egg goes back to its nest.
function NightCycle.nightfall()
	Wilds.nightfall()
	for _, player in Players:GetPlayers() do
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		-- at night everyone out in the Wilds goes to the middle of the Safe Zone (the general spawn)
		local lobby = workspace:FindFirstChild("LobbySpawn", true) :: BasePart?
		if root and lobby and root.Position.X > World.SAFE_FRONT then
			character:PivotTo(lobby.CFrame + Vector3.new(0, 4, 0))
			notify(player, "🌙 Night fell! You were sent home and the egg went back to its nest.")
		end
	end
end

function NightCycle.start(map: Instance, notifyFn: (Player, string) -> ())
	notify = notifyFn
	buildWall(map)
	Session.setHatchBoost(function()
		return DayNight.hatchBoost(Session.now())
	end)
	local last: string? = nil
	local acc = 0
	RunService.Heartbeat:Connect(function(dt)
		acc += dt
		if acc < 0.2 then
			return
		end
		acc = 0
		local now = Session.now()
		local s = DayNight.at(now)
		if s.phase == "Night" and last == "Day" then
			NightCycle.nightfall()
		end
		last = s.phase
		setWall(s.phase ~= "Day", s.wallLeft)
		ReplicatedStorage:SetAttribute("Phase", s.phase)
		ReplicatedStorage:SetAttribute("PhaseEnds", now + s.left)
	end)
end

return NightCycle
