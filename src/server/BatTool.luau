--!strict
-- The bat: every player holds one. Clicking (or tapping) swings it; a player in front of the swing is thrown back and stunned for a
-- moment, and if they were carrying an egg they drop it where they stand. Nothing happens in the Safe Zone (that is what it is for).
-- Better bats come from completing worlds' Indexes (see Shared/Game/Bats and Session's claims). The rules are in Bats; this builds
-- the tool, listens for the swing and applies the hit.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Bats = require(ReplicatedStorage.Shared.Game.Bats)
local Zones = require(ReplicatedStorage.Shared.Game.Zones)
local Config = require(ReplicatedStorage.Shared.Config)
local Session = require(script.Parent.Session)
local Traps = require(script.Parent.Traps)
local Wilds = require(script.Parent.Wilds)

local BatTool = {}

local lastSwing: { [Player]: number } = {}
local immuneUntil: { [Player]: number } = {}
local given: { [Player]: number } = {} -- the tier of the tool each player holds now
local notify: (Player, string) -> () = function(_player: Player, _text: string) end
local sfx: (Player, string) -> () = function(_player: Player, _name: string) end

local GRIP_READY = CFrame.new(0, -1.2, 0) * CFrame.Angles(math.rad(-25), 0, 0)
-- Roblox applies Grip inverted: a POSITIVE angle here tips the bat FORWARD (the old -115 swung it back over the shoulder)
local GRIP_SWUNG = CFrame.new(0, -1.2, 0) * CFrame.Angles(math.rad(80), 0, 0)

local function rootOf(player: Player): BasePart?
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not character or not humanoid or humanoid.Health <= 0 then
		return nil
	end
	return character:FindFirstChild("HumanoidRootPart") :: BasePart?
end

-- You cannot fight in the Safe Zone or in the bases (everything west of the first terrain).
local function safe(root: BasePart): boolean
	return root.Position.X < Zones.List[1].startX
end

function BatTool.setHooks(notifyFn: (Player, string) -> (), sfxFn: (Player, string) -> ())
	notify, sfx = notifyFn, sfxFn
end

local function hit(from: Player, to: Player, bat: Bats.Bat, fromRoot: BasePart, toRoot: BasePart)
	local push = Vector3.new(toRoot.Position.X - fromRoot.Position.X, 0, toRoot.Position.Z - fromRoot.Position.Z)
	local direction = if push.Magnitude > 1e-6 then push.Unit else fromRoot.CFrame.LookVector
	toRoot.AssemblyLinearVelocity = direction * bat.knock + Vector3.new(0, 24, 0)
	local humanoid = (toRoot.Parent :: Instance):FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.PlatformStand = true
		task.delay(bat.stun, function()
			if humanoid.Parent then
				humanoid.PlatformStand = false
			end
		end)
	end
	immuneUntil[to] = os.clock() + bat.stun + 0.5
	Wilds.drop(to) -- a runner who is hit lets go of the egg: it lies where they fall
	notify(to, `{from.DisplayName} hit you with a {bat.name}!`)
	notify(from, `You hit {to.DisplayName}!`)
	sfx(to, "caught")
	sfx(from, "click")
end

-- A swing from `player`. Returns how many players it hit (0 on cooldown, in the Safe Zone, or at nobody).
function BatTool.swing(player: Player): number
	local bat = Bats.get((player:GetAttribute("BatTier") :: number?) or 0)
	local now = os.clock()
	if now - (lastSwing[player] or -math.huge) < bat.cooldown then
		return 0
	end
	local root = rootOf(player)
	if not root or safe(root) then
		return 0
	end
	lastSwing[player] = now
	local look = root.CFrame.LookVector
	local hits = 0
	for _, other in Players:GetPlayers() do
		if other ~= player and now >= (immuneUntil[other] or 0) then
			local theirs = rootOf(other)
			if
				theirs
				and not safe(theirs)
				and math.abs(theirs.Position.Y - root.Position.Y) < 8
				and (
					Bats.reaches(
						bat,
						root.Position.X,
						root.Position.Z,
						look.X,
						look.Z,
						theirs.Position.X,
						theirs.Position.Z
					)
					-- where the swinger SAW them: a moment back along their run
					or Bats.reaches(
						bat,
						root.Position.X,
						root.Position.Z,
						look.X,
						look.Z,
						theirs.Position.X - theirs.AssemblyLinearVelocity.X * Bats.LAG,
						theirs.Position.Z - theirs.AssemblyLinearVelocity.Z * Bats.LAG
					)
				)
			then
				hit(player, other, bat, root, theirs)
				hits += 1
			end
		end
	end
	return hits
end

-- The material that fits each bat's name.
function BatTool.material(name: string): Enum.Material
	local key = string.gsub(name, " Bat$", "")
	local map: { [string]: Enum.Material } = {
		Wooden = Enum.Material.Wood,
		Foam = Enum.Material.SmoothPlastic,
		Rubber = Enum.Material.SmoothPlastic,
		Stone = Enum.Material.Slate,
		Iron = Enum.Material.Metal,
		Silver = Enum.Material.Metal,
		Golden = Enum.Material.Foil,
		Ruby = Enum.Material.Glass,
		Emerald = Enum.Material.Glass,
		Frost = Enum.Material.Ice,
		Lava = Enum.Material.Neon,
		Neon = Enum.Material.Neon,
		Ghost = Enum.Material.Glass,
		Cloud = Enum.Material.SmoothPlastic,
		Galaxy = Enum.Material.Neon,
		Divine = Enum.Material.Neon,
	}
	return map[key] or Enum.Material.Wood
end

local function build(player: Player, tier: number): Tool
	local bat = Bats.get(tier)
	local tool = Instance.new("Tool")
	tool.Name = "Bat"
	tool.ToolTip = bat.name
	tool.TextureId = Config.ItemIcons.bat
	tool.CanBeDropped = false
	tool.RequiresHandle = true
	tool.Grip = GRIP_READY
	local handle = Instance.new("Part")
	handle.Name = "Handle"
	handle.Size = Vector3.new(0.6, 3.4, 0.6)
	handle.Transparency = 1
	handle.CanCollide = false
	handle.Massless = true
	handle.Parent = tool
	-- the bat itself: smooth round parts (not bricks), turned like a real bat: a knob, a taped grip, then a taper into a thick
	-- rounded barrel. Each bat keeps its colours and gets a material to match (wood, stone, metal, gold, ice, neon...).
	local look = BatTool.material(bat.name)
	local headColor = Color3.fromRGB(bat.head[1], bat.head[2], bat.head[3])
	local handleColor = Color3.fromRGB(bat.handle[1], bat.handle[2], bat.handle[3])
	local function piece(
		name: string,
		shape: Enum.PartType,
		size: Vector3,
		y: number,
		color: Color3,
		material: Enum.Material
	)
		local p = Instance.new("Part")
		p.Name = name
		p.Shape = shape
		p.Size = size
		p.Color = color
		p.Material = material
		p.CanCollide = false
		p.CanQuery = false
		p.Massless = true
		p.CastShadow = false
		-- a Roblox cylinder runs along its X size: turn it to run along the handle (Y)
		p.CFrame = handle.CFrame * CFrame.new(0, y, 0) * CFrame.Angles(0, 0, math.pi / 2)
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = handle
		weld.Part1 = p
		weld.Parent = p
		p.Parent = tool
		return p
	end
	local LENGTH = 3.6
	local bottom = -LENGTH / 2
	-- (start, end) along the bat as a share of its length, and the diameter there
	local PROFILE = {
		{ 0.00, 0.05, 0.34 }, -- the knob
		{ 0.05, 0.30, 0.22 }, -- the grip
		{ 0.30, 0.45, 0.26 },
		{ 0.45, 0.58, 0.32 },
		{ 0.58, 0.70, 0.40 },
		{ 0.70, 0.82, 0.48 },
		{ 0.82, 0.94, 0.54 }, -- the barrel
	}
	for i, seg in PROFILE do
		local len = (seg[2] - seg[1]) * LENGTH
		local mid = bottom + (seg[1] + seg[2]) / 2 * LENGTH
		local grip = i <= 2
		piece(
			if i == 1 then "Knob" elseif grip then "Grip" else `Barrel{i}`,
			Enum.PartType.Cylinder,
			Vector3.new(len + 0.02, seg[3], seg[3]),
			mid,
			if grip then handleColor else headColor,
			if grip then Enum.Material.Fabric else look
		)
	end
	-- the rounded end of the barrel
	piece("Cap", Enum.PartType.Ball, Vector3.new(0.54, 0.54, 0.54), bottom + 0.94 * LENGTH, headColor, look)
	tool.Activated:Connect(function()
		local ready = BatTool.swing(player)
		-- the swing: the bat tips forward and comes back
		tool.Grip = GRIP_SWUNG
		task.delay(0.16, function()
			if tool.Parent then
				tool.Grip = GRIP_READY
			end
		end)
		return ready
	end)
	return tool
end

-- Puts the player's items in their backpack like any Roblox game: the bat for their tier and the trap. Nothing is forced into
-- their hands; they pick an item from the bar (1, 2 or a click) and put it away again. A better bat replaces the old one, and
-- if they were holding the old one they hold the new one.
function BatTool.give(player: Player)
	local tier = (player:GetAttribute("BatTier") :: number?) or 0
	local character = player.Character
	local backpack = player:FindFirstChildOfClass("Backpack")
	if not character or not backpack then
		return
	end
	local holding = character:FindFirstChild("Bat") ~= nil
	local function clear(holder: Instance)
		for _, child in holder:GetChildren() do
			if child:IsA("Tool") and child.Name == "Bat" then
				child:Destroy()
			end
		end
	end
	clear(backpack)
	clear(character)
	local tool = build(player, tier)
	tool.Parent = backpack
	given[player] = tier
	Traps.syncTool(player)
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if humanoid and holding then
		pcall(function()
			humanoid:EquipTool(tool)
		end)
	end
end

function BatTool.start()
	local function watch(player: Player)
		player.CharacterAdded:Connect(function()
			task.defer(BatTool.give, player)
		end)
		if player.Character then
			task.defer(BatTool.give, player)
		end
	end
	for _, player in Players:GetPlayers() do
		watch(player)
	end
	Players.PlayerAdded:Connect(watch)
	Players.PlayerRemoving:Connect(function(player)
		lastSwing[player] = nil
		immuneUntil[player] = nil
		given[player] = nil
	end)
	-- a finished world gives a better bat straight away
	Session.onWorldComplete(function(player, zone)
		notify(player, `{zone.name} Index complete! You got a better bat.`)
		sfx(player, "deliver")
		BatTool.give(player)
	end)
end

return BatTool
