--!strict
-- The signs in your base (UPGRADE, REBIRTH, BUY SLOT) carry a real button with the next cost above it: click it on a PC.
-- A phone or gamepad uses the hold prompt instead (Marco), so on a PC those prompts are hidden. The buttons live in PlayerGui
-- (adorned to the sign) because only there do SurfaceGui buttons take clicks; the server acts on your own base only.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Economy = require(ReplicatedStorage.Shared.Game.Economy)
local Rebirth = require(ReplicatedStorage.Shared.Game.Rebirth)

local SignButtons = {}

type Sign = { part: string, kind: string, title: string, color: Color3, cost: (Player) -> string }
local SIGNS: { Sign } = {
	{
		part = "UpgradeSign",
		kind = "upgrade",
		title = "UPGRADE",
		color = Color3.fromRGB(250, 170, 40),
		cost = function(p)
			local c = p:GetAttribute("UpgradeCost") :: number?
			return if c == nil then "" elseif c < 0 then "MAX" else `${Economy.format(c)}`
		end,
	},
	{
		part = "RebirthPad",
		kind = "rebirth",
		title = "REBIRTH",
		color = Color3.fromRGB(150, 70, 230),
		cost = function(p)
			local done = (p:GetAttribute("Rebirths") :: number?) or 0
			if done >= Rebirth.MAX then
				return "MAX"
			end
			local bonus = p:GetAttribute("NextRebirthBonus") :: number?
			return `${Economy.format(Rebirth.cost(done))}{if bonus then ` (x{bonus})` else ""}`
		end,
	},
	{
		part = "SlotPad",
		kind = "slot",
		title = "BUY SLOT",
		color = Color3.fromRGB(60, 190, 90),
		cost = function(p)
			local c = p:GetAttribute("SlotCost") :: number?
			return if c == nil then "" elseif c < 0 then "MAX" else `${Economy.format(c)}`
		end,
	},
}

-- A PC: a mouse and no touch screen or gamepad. Only then are the signs clicked instead of held.
function SignButtons.clicks(): boolean
	return UserInputService.MouseEnabled and not UserInputService.TouchEnabled and not UserInputService.GamepadEnabled
end

local function ownPlot(player: Player): Instance?
	for _, model in workspace:GetDescendants() do
		if
			model:IsA("Model")
			and model:GetAttribute("OwnerUserId") == player.UserId
			and model:FindFirstChild("UpgradeSign")
		then
			return model
		end
	end
	return nil
end

function SignButtons.start(player: Player)
	local remote = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("SignAction") :: RemoteEvent
	local guis: { { cost: TextLabel, sign: Sign } } = {}
	local built: Instance? = nil
	local function build(plot: Instance)
		for _, old in player.PlayerGui:GetChildren() do
			if old.Name == "SignButtons" then
				old:Destroy()
			end
		end
		table.clear(guis)
		for _, sign in SIGNS do
			local board = plot:FindFirstChild(sign.part)
			if not (board and board:IsA("BasePart")) then
				continue
			end
			for _, face in { Enum.NormalId.Front, Enum.NormalId.Back } do
				local gui = Instance.new("SurfaceGui")
				gui.Name = "SignButtons"
				gui.Adornee = board
				gui.Face = face
				gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
				gui.PixelsPerStud = 40
				gui.AlwaysOnTop = false
				gui.ResetOnSpawn = false -- a PlayerGui child is wiped on respawn unless told otherwise; the signs must stay
				gui.Parent = player.PlayerGui
				local back = Instance.new("Frame")
				back.Size = UDim2.fromScale(1, 1)
				back.BackgroundColor3 = sign.color
				back.BorderSizePixel = 0
				back.Parent = gui
				local cost = Instance.new("TextLabel")
				cost.Name = "Cost"
				cost.Size = UDim2.fromScale(0.92, 0.36)
				cost.Position = UDim2.fromScale(0.04, 0.06)
				cost.BackgroundTransparency = 1
				cost.Font = Enum.Font.FredokaOne
				cost.TextScaled = true
				cost.TextColor3 = Color3.fromRGB(255, 245, 150)
				cost.TextStrokeTransparency = 0
				cost.Parent = back
				local button = Instance.new("TextButton")
				button.Name = "Press"
				button.Size = UDim2.fromScale(0.84, 0.44)
				button.Position = UDim2.fromScale(0.08, 0.48)
				button.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
				button.Font = Enum.Font.FredokaOne
				button.TextScaled = true
				button.Text = sign.title
				button.TextColor3 = Color3.fromRGB(30, 30, 40)
				button.AutoButtonColor = true
				button.Parent = back
				local round = Instance.new("UICorner")
				round.CornerRadius = UDim.new(0.25, 0)
				round.Parent = button
				local kind = sign.kind
				button.Activated:Connect(function()
					remote:FireServer(kind)
				end)
				table.insert(guis, { cost = cost, sign = sign })
			end
		end
	end
	task.spawn(function()
		while true do
			local plot = ownPlot(player)
			if plot and plot ~= built then
				built = plot
				build(plot)
			end
			for _, g in guis do
				g.cost.Text = g.sign.cost(player)
			end
			-- on a PC the hold prompts give way to the buttons; a phone or gamepad keeps them
			if plot then
				local hide = SignButtons.clicks()
				-- the sign's own painted words are replaced by the button version here, so the two never overlap
				for _, sign in SIGNS do
					local board = plot:FindFirstChild(sign.part)
					if board then
						for _, painted in board:GetChildren() do
							if painted:IsA("SurfaceGui") then
								painted.Enabled = not hide
							end
						end
					end
				end
				for _, d in plot:GetDescendants() do
					if
						d:IsA("ProximityPrompt")
						and (
							d.ActionText == "Upgrade treadmill"
							or d.ActionText == "Rebirth"
							or d.ActionText == "Buy slot"
						)
					then
						d.Enabled = not hide
					end
				end
			end
			task.wait(0.5)
		end
	end)
end

SignButtons.SIGNS = SIGNS

return SignButtons
