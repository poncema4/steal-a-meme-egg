--!strict
-- Gives each player a base plot and keeps its parts in step with their Base state: eggs that count down, characters that
-- glow by mutation and can be raided. Visuals are plain parts (no meshes) so Rojo carries everything.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Economy = require(ReplicatedStorage.Shared.Game.Economy)
local Eggs = require(ReplicatedStorage.Shared.Game.Eggs)
local Session = require(script.Parent.Session)
local World = require(script.Parent.World)

local Plots = {}

local TIER_COLORS: { [string]: Color3 } = {
	Soggy = Color3.fromRGB(235, 225, 190),
	Disco = Color3.fromRGB(255, 120, 220),
	Spicy = Color3.fromRGB(255, 90, 40),
	Golden = Color3.fromRGB(255, 205, 40),
	Cosmic = Color3.fromRGB(110, 90, 255),
	Divine = Color3.fromRGB(255, 255, 255),
}
local RARITY_COLORS: { [string]: Color3 } = {
	Common = Color3.fromRGB(200, 200, 200),
	Rare = Color3.fromRGB(80, 160, 255),
	Epic = Color3.fromRGB(190, 90, 255),
	Legendary = Color3.fromRGB(255, 170, 40),
	Mythic = Color3.fromRGB(255, 70, 90),
}

local plots: { World.Plot } = {}
local owned: { [Player]: World.Plot } = {}
local onSteal: (Player, Player, number) -> () = function(_thief: Player, _owner: Player, _slot: number) end
local onLock: (Player) -> () = function(_player: Player) end

function Plots.setHandlers(steal: (Player, Player, number) -> (), lock: (Player) -> ())
	onSteal = steal
	onLock = lock
end

function Plots.of(player: Player): World.Plot?
	return owned[player]
end

local function tag(parent: Instance, lines: { string }, offset: number): BillboardGui
	local gui = Instance.new("BillboardGui")
	gui.Name = "Tag"
	gui.Size = UDim2.fromOffset(180, 20 * #lines + 6)
	gui.StudsOffset = Vector3.new(0, offset, 0)
	gui.AlwaysOnTop = true
	gui.MaxDistance = 70
	gui.Parent = parent
	for i, text in lines do
		local label = Instance.new("TextLabel")
		label.Name = `L{i}`
		label.Size = UDim2.new(1, 0, 0, 20)
		label.Position = UDim2.fromOffset(0, (i - 1) * 20)
		label.BackgroundTransparency = 1
		label.Font = Enum.Font.FredokaOne
		label.TextScaled = true
		label.TextColor3 = Color3.new(1, 1, 1)
		label.TextStrokeTransparency = 0.3
		label.Text = text
		label.Parent = gui
	end
	return gui
end

local function clearSlot(pedestal: BasePart)
	local old = pedestal:FindFirstChild("Item")
	if old then
		old:Destroy()
	end
end

local function drawSlot(owner: Player, plot: World.Plot, n: number)
	local state = Session.get(owner)
	local pedestal = plot.slots[n]
	clearSlot(pedestal)
	if not state then
		return
	end
	pedestal.Transparency = if n > state.base.size then 0.8 else 0
	local item = state.base.slots[n]
	if not item then
		return
	end
	local model = Instance.new("Model")
	model.Name = "Item"
	local body = Instance.new("Part")
	body.Name = "Body"
	body.Anchored = true
	body.CanCollide = false
	if item.kind == "egg" and item.tier then
		body.Shape = Enum.PartType.Ball
		body.Size = Vector3.new(4, 5, 4)
		body.Color = TIER_COLORS[item.tier] or Color3.new(1, 1, 1)
		body.Material = Enum.Material.SmoothPlastic
		body.CFrame = pedestal.CFrame + Vector3.new(0, 3.2, 0)
		body.Parent = model
		local tier = Eggs.tier(item.tier)
		tag(body, { tier and tier.name or "Egg", `hatching {math.ceil(item.hatchLeft or 0)}s` }, 3.4)
	else
		local c = Eggs.character(item.id or "")
		body.Size = Vector3.new(3.5, 4.5, 2.5)
		body.Color = RARITY_COLORS[c and c.rarity or "Common"] or Color3.new(1, 1, 1)
		body.Material = if item.mutation == "Normal" then Enum.Material.SmoothPlastic else Enum.Material.Neon
		if item.mutation == "Gold" then
			body.Color = Color3.fromRGB(255, 210, 60)
		elseif item.mutation == "Rainbow" then
			body.Color = Color3.fromHSV((os.clock() * 0.2) % 1, 0.8, 1)
		end
		body.CFrame = pedestal.CFrame + Vector3.new(0, 3.2, 0)
		body.Parent = model
		local head = Instance.new("Part")
		head.Name = "Head"
		head.Shape = Enum.PartType.Ball
		head.Size = Vector3.new(3, 3, 3)
		head.Anchored = true
		head.CanCollide = false
		head.Color = body.Color
		head.Material = body.Material
		head.CFrame = body.CFrame + Vector3.new(0, 3.6, 0)
		head.Parent = model
		local name = if c then c.name else "?"
		local suffix = if item.mutation ~= "Normal" and item.mutation then `{item.mutation} ` else ""
		local per = if c then c.income * (Eggs.Mutations[item.mutation or "Normal"] or 1) else 0
		tag(head, { suffix .. name, `+{Economy.format(per)}/s` }, 3)
		local prompt = Instance.new("ProximityPrompt")
		prompt.ActionText = "Steal"
		prompt.ObjectText = name
		prompt.HoldDuration = Config.Steal.HoldSeconds
		prompt.MaxActivationDistance = Config.Steal.Reach
		prompt.RequiresLineOfSight = false
		prompt.Parent = body
		prompt.Triggered:Connect(function(who)
			onSteal(who, owner, n)
		end)
	end
	model.Parent = pedestal
end

function Plots.refresh(player: Player)
	local plot = owned[player]
	if not plot then
		return
	end
	for n = 1, 12 do
		drawSlot(player, plot, n)
	end
end

-- Counts down the hatching timers on screen without rebuilding every part.
function Plots.updateTimers(player: Player)
	local plot = owned[player]
	local state = Session.get(player)
	if not plot or not state then
		return
	end
	for n = 1, state.base.size do
		local item = state.base.slots[n]
		if item and item.kind == "egg" then
			local pedestal = plot.slots[n]
			local itemModel = pedestal:FindFirstChild("Item")
			local body = itemModel and itemModel:FindFirstChild("Body")
			local tagGui = body and body:FindFirstChild("Tag")
			local label = tagGui and tagGui:FindFirstChild("L2")
			if label and label:IsA("TextLabel") then
				label.Text = `hatching {math.ceil(item.hatchLeft or 0)}s`
			end
		end
	end
end

function Plots.assign(player: Player): World.Plot?
	for _, plot in plots do
		if plot.model:GetAttribute("OwnerUserId") == 0 then
			plot.model:SetAttribute("OwnerUserId", player.UserId)
			plot.sign.Text = string.upper(player.DisplayName) .. "'S BASE"
			owned[player] = plot
			player.RespawnLocation = plot.spawn :: SpawnLocation
			if not plot.lockPad:FindFirstChildOfClass("ProximityPrompt") then
				local prompt = Instance.new("ProximityPrompt")
				prompt.ActionText = "Lock base"
				prompt.ObjectText = "keep raiders out"
				prompt.HoldDuration = 0.3
				prompt.MaxActivationDistance = 10
				prompt.Parent = plot.lockPad
				prompt.Triggered:Connect(function(who)
					if plot.model:GetAttribute("OwnerUserId") == who.UserId then
						onLock(who)
					end
				end)
			end
			return plot
		end
	end
	return nil
end

function Plots.release(player: Player)
	local plot = owned[player]
	if not plot then
		return
	end
	owned[player] = nil
	plot.model:SetAttribute("OwnerUserId", 0)
	plot.sign.Text = "FREE BASE"
	for n = 1, 12 do
		clearSlot(plot.slots[n])
	end
end

function Plots.start(world: { plots: { World.Plot } })
	plots = world.plots
	Session.onChanged(Plots.refresh)
	task.spawn(function()
		while true do
			task.wait(1)
			for _, player in Players:GetPlayers() do
				Plots.updateTimers(player)
			end
		end
	end)
end

return Plots
