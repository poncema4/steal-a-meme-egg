--!strict
-- The whole screen: coins, income per second, the live-event banner with a countdown, the next-event timer, and
-- toasts for notices and announcements. Everything it shows is an attribute the server publishes.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Economy = require(ReplicatedStorage.Shared.Game.Economy)
local Events = require(ReplicatedStorage.Shared.Game.Events)

local Hud = {}

local function label(parent: Instance, name: string, size: UDim2, position: UDim2, textSize: number): TextLabel
	local l = Instance.new("TextLabel")
	l.Name = name
	l.Size = size
	l.Position = position
	l.AnchorPoint = Vector2.new(0.5, 0)
	l.BackgroundTransparency = 1
	l.Font = Enum.Font.FredokaOne
	l.TextColor3 = Color3.new(1, 1, 1)
	l.TextStrokeTransparency = 0.2
	l.TextXAlignment = Enum.TextXAlignment.Center
	l.TextSize = textSize
	l.Text = ""
	l.Parent = parent
	return l
end

local function clock(seconds: number): string
	seconds = math.max(0, math.floor(seconds))
	return string.format("%d:%02d", seconds // 60, seconds % 60)
end

function Hud.start(player: Player)
	local gui = Instance.new("ScreenGui")
	gui.Name = "RaidHud"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = false
	gui.Parent = player:WaitForChild("PlayerGui")

	local coins = label(gui, "Coins", UDim2.fromOffset(320, 44), UDim2.new(0.5, 0, 0, 8), 36)
	coins.TextColor3 = Color3.fromRGB(255, 221, 68)
	local income = label(gui, "Income", UDim2.fromOffset(320, 24), UDim2.new(0.5, 0, 0, 52), 20)
	local banner = label(gui, "Banner", UDim2.fromOffset(480, 34), UDim2.new(0.5, 0, 0, 82), 26)
	banner.TextColor3 = Color3.fromRGB(120, 255, 160)
	local nextUp = label(gui, "NextEvent", UDim2.fromOffset(480, 22), UDim2.new(0.5, 0, 0, 118), 18)
	local toast = label(gui, "Toast", UDim2.fromOffset(640, 40), UDim2.fromScale(0.5, 0.78), 26)

	local toastToken = 0
	local function show(text: string)
		toastToken += 1
		local mine = toastToken
		toast.Text = text
		task.delay(4, function()
			if toastToken == mine then
				toast.Text = ""
			end
		end)
	end
	local remotes = ReplicatedStorage:WaitForChild("Remotes")
	local notice = remotes:WaitForChild("Notice") :: RemoteEvent
	local announce = remotes:WaitForChild("Announce") :: RemoteEvent
	notice.OnClientEvent:Connect(show)
	announce.OnClientEvent:Connect(show)

	RunService.RenderStepped:Connect(function()
		coins.Text = "$" .. Economy.format((player:GetAttribute("Coins") :: number?) or 0)
		income.Text = "+" .. Economy.format((player:GetAttribute("Income") :: number?) or 0) .. " / sec"
		local now = workspace:GetServerTimeNow()
		local active = tostring(ReplicatedStorage:GetAttribute("ActiveEvents") or "")
		local lines = {}
		for entry in string.gmatch(active, "[^,]+") do
			local id, ends = string.match(entry, "^(%w+):(%d+%.?%d*)$")
			local def = id and Events.Defs[id]
			if def and ends and tonumber(ends) :: number > now then
				table.insert(lines, `{def.name}  {clock((tonumber(ends) :: number) - now)}`)
			end
		end
		banner.Text = table.concat(lines, "   ")
		local nextId, startsAt =
			string.match(tostring(ReplicatedStorage:GetAttribute("NextEvent") or ""), "^(%w+):(%d+%.?%d*)$")
		local nextDef = nextId and Events.Defs[nextId]
		nextUp.Text = if nextDef and startsAt
			then `Next: {nextDef.name} in {clock((tonumber(startsAt) :: number) - now)}`
			else ""
	end)
end

return Hud
