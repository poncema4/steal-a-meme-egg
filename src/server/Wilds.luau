--!strict
-- The Wilds: a long strip of themed terrains east of the bases. Meme guardians sit on eggs in nests; hold E to steal one,
-- the guardian chases you, and you run it home. Gates keep you out of terrains you have not unlocked with Meme Points.
-- The rules live in Shared/Game (Zones, Guardian, Nest, Progression); this file builds parts and moves them.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local Eggs = require(ReplicatedStorage.Shared.Game.Eggs)
local Guardian = require(ReplicatedStorage.Shared.Game.Guardian)
local Nest = require(ReplicatedStorage.Shared.Game.Nest)
local Plots = require(script.Parent.Plots)
local Session = require(script.Parent.Session)
local Zones = require(ReplicatedStorage.Shared.Game.Zones)

local Wilds = {}

export type Entry = {
	id: string,
	zone: Zones.Zone,
	nest: Nest.Nest,
	guardian: Guardian.Guardian,
	model: Model,
	egg: BasePart,
	prompt: ProximityPrompt,
	character: string, -- the meme character this guardian looks like
	thief: Player?,
}

local TIER_COLORS: { [string]: Color3 } = {
	Soggy = Color3.fromRGB(235, 225, 190),
	Disco = Color3.fromRGB(255, 120, 220),
	Spicy = Color3.fromRGB(255, 90, 40),
	Golden = Color3.fromRGB(255, 205, 40),
	Cosmic = Color3.fromRGB(110, 90, 255),
	Divine = Color3.fromRGB(255, 255, 255),
}

local entries: { Entry } = {}
local notify: (Player, string) -> () = function(_player: Player, _text: string) end

function Wilds.setNotify(fn: (Player, string) -> ())
	notify = fn
end

function Wilds.entries(): { Entry }
	return entries
end

local function box(
	name: string,
	size: Vector3,
	cf: CFrame,
	color: Color3,
	parent: Instance,
	material: Enum.Material?
): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	if material then
		p.Material = material
	end
	p.Parent = parent
	return p
end

local function rgb(c: { number }): Color3
	return Color3.fromRGB(c[1], c[2], c[3])
end

local function label(parent: BasePart, lines: { string }, offset: number, width: number)
	local gui = Instance.new("BillboardGui")
	gui.Name = "Tag"
	gui.Size = UDim2.fromOffset(width, 22 * #lines + 4)
	gui.StudsOffset = Vector3.new(0, offset, 0)
	gui.AlwaysOnTop = true
	gui.MaxDistance = 90
	gui.Parent = parent
	for i, text in lines do
		local l = Instance.new("TextLabel")
		l.Name = `L{i}`
		l.Size = UDim2.new(1, 0, 0, 22)
		l.Position = UDim2.fromOffset(0, (i - 1) * 22)
		l.BackgroundTransparency = 1
		l.Font = Enum.Font.FredokaOne
		l.TextScaled = true
		l.TextColor3 = Color3.new(1, 1, 1)
		l.TextStrokeTransparency = 0.25
		l.Text = text
		l.Parent = gui
	end
end

-- Scenery per terrain: simple parts only (no meshes), seeded so every server builds the same map.
local function decorate(zone: Zones.Zone, parent: Instance)
	local rng = Random.new(zone.startX)
	for _ = 1, 28 do
		local x = zone.startX + 12 + rng:NextNumber() * (zone.length - 24)
		local z = (rng:NextNumber() - 0.5) * (Zones.WIDTH - 20)
		local s = 3 + rng:NextNumber() * 5
		if zone.id == "Meadow" then
			box("Trunk", Vector3.new(1.6, s * 1.6, 1.6), CFrame.new(x, s * 0.8, z), Color3.fromRGB(110, 70, 40), parent)
			local leaves = box(
				"Leaves",
				Vector3.new(s * 1.6, s, s * 1.6),
				CFrame.new(x, s * 1.9, z),
				Color3.fromRGB(40, 150, 60),
				parent
			)
			leaves.Shape = Enum.PartType.Ball
		elseif zone.id == "Dune" then
			box(
				"Cactus",
				Vector3.new(1.8, s * 1.5, 1.8),
				CFrame.new(x, s * 0.75, z),
				Color3.fromRGB(30, 150, 60),
				parent
			)
			box("CactusArm", Vector3.new(3.4, 1.4, 1.4), CFrame.new(x, s * 0.9, z), Color3.fromRGB(30, 150, 60), parent)
		elseif zone.id == "Volcano" then
			box("Rock", Vector3.new(s * 1.4, s, s * 1.2), CFrame.new(x, s * 0.5, z), Color3.fromRGB(50, 40, 45), parent)
			if rng:NextNumber() < 0.35 then
				box(
					"Lava",
					Vector3.new(s * 2, 0.2, s * 2),
					CFrame.new(x + 6, 0.12, z),
					Color3.fromRGB(255, 110, 20),
					parent,
					Enum.Material.Neon
				)
			end
		elseif zone.id == "Frost" then
			local ice = box(
				"Ice",
				Vector3.new(s, s * 1.8, s),
				CFrame.new(x, s * 0.9, z),
				Color3.fromRGB(190, 230, 255),
				parent,
				Enum.Material.Ice
			)
			ice.Transparency = 0.25
		else
			local crystal = box(
				"Crystal",
				Vector3.new(s * 0.7, s * 2, s * 0.7),
				CFrame.new(x, s, z),
				Color3.fromRGB(170, 90, 255),
				parent,
				Enum.Material.Neon
			)
			crystal.Transparency = 0.15
		end
	end
end

local function buildGuardian(entry: Entry, parent: Instance, c: Eggs.Character)
	local model = Instance.new("Model")
	model.Name = "Guardian"
	local tint = Color3.fromHSV((#c.id * 0.137) % 1, 0.55, 1)
	local body = box("Body", Vector3.new(6, 7, 8), CFrame.new(0, 4.5, 0), tint, model)
	model.PrimaryPart = body
	local head = box("Head", Vector3.new(5, 5, 5), CFrame.new(0, 10, -2.5), tint, model)
	head.Shape = Enum.PartType.Ball
	for _, sx in { -1, 1 } do
		box("Eye", Vector3.new(1.2, 1.6, 0.6), CFrame.new(sx * 1.3, 10.6, -4.8), Color3.new(0, 0, 0), model)
		box("Pupil", Vector3.new(0.6, 0.8, 0.3), CFrame.new(sx * 1.3, 10.6, -5.2), Color3.fromRGB(255, 20, 20), model)
		local brow = box("Brow", Vector3.new(2, 0.5, 0.5), CFrame.new(sx * 1.3, 11.8, -4.9), Color3.new(0, 0, 0), model)
		brow.CFrame = brow.CFrame * CFrame.Angles(0, 0, -sx * 0.45)
	end
	box("Beak", Vector3.new(3, 1.2, 3), CFrame.new(0, 9.2, -5.2), Color3.fromRGB(255, 140, 20), model)
	label(head, { c.name, "GUARDIAN" }, 4.2, 200)
	model.Parent = parent
	entry.model = model
end

local function setEgg(entry: Entry, tier: string?)
	entry.egg.Transparency = if tier then 0 else 1
	entry.prompt.Enabled = tier ~= nil
	if tier then
		entry.egg.Color = TIER_COLORS[tier] or Color3.new(1, 1, 1)
		local def = Eggs.tier(tier)
		entry.prompt.ObjectText = def and def.name or "Egg"
	end
end

local function buildNests(zone: Zones.Zone, parent: Instance)
	local rng = Random.new(zone.startX + 7)
	for i = 1, zone.nests do
		local x = zone.startX + 25 + (i - 1) * ((zone.length - 50) / math.max(zone.nests - 1, 1))
		local side = if i % 2 == 0 then 1 else -1
		local z = side * (22 + rng:NextNumber() * 55)
		local tier = Zones.eggFor(zone, function()
			return rng:NextNumber()
		end)
		local model = Instance.new("Model")
		model.Name = `Nest_{zone.id}_{i}`
		local ring = box("Ring", Vector3.new(9, 0.6, 9), CFrame.new(x, 0.3, z), Color3.fromRGB(120, 85, 50), model)
		ring.Shape = Enum.PartType.Cylinder
		ring.CFrame = CFrame.new(x, 0.3, z) * CFrame.Angles(0, 0, math.pi / 2)
		local egg = box("Egg", Vector3.new(4, 5, 4), CFrame.new(x, 3.1, z), Color3.new(1, 1, 1), model)
		egg.Shape = Enum.PartType.Ball
		egg.CanCollide = false
		local prompt = Instance.new("ProximityPrompt")
		prompt.ActionText = "Steal egg"
		prompt.HoldDuration = Config.Wilds.StealHoldSeconds
		prompt.MaxActivationDistance = 11
		prompt.RequiresLineOfSight = false
		prompt.Parent = egg
		local pool = Eggs.tier(tier)
		local pick = pool and pool.pool[1].id or "SoggyToast"
		local c = Eggs.character(pick) or Eggs.Characters.SoggyToast
		local entry: Entry = {
			id = model.Name,
			zone = zone,
			nest = Nest.new(tier),
			guardian = Guardian.new(x + 9, z, zone.guardianSpeed),
			model = model,
			egg = egg,
			prompt = prompt,
			character = c.id,
			thief = nil,
		}
		model.Parent = parent
		buildGuardian(entry, parent, c)
		entry.model:PivotTo(CFrame.new(entry.guardian.x, 0, entry.guardian.z))
		setEgg(entry, tier)
		prompt.Triggered:Connect(function(who)
			Wilds.steal(who, entry)
		end)
		table.insert(entries, entry)
	end
end

function Wilds.build(): Folder
	local folder = Instance.new("Folder")
	folder.Name = "Wilds"
	folder.Parent = workspace
	for _, zone in Zones.List do
		local floor = box(
			zone.id,
			Vector3.new(zone.length, 2, Zones.WIDTH),
			CFrame.new(zone.startX + zone.length / 2, -1, 0),
			rgb(zone.ground),
			folder
		)
		floor:SetAttribute("Zone", zone.id)
		decorate(zone, folder)
		buildNests(zone, folder)
		-- the gate: a see-through frame with the price on it (the server, not the frame, keeps people out)
		local gate = box(
			`Gate_{zone.id}`,
			Vector3.new(Zones.GATE_DEPTH, 26, Zones.WIDTH),
			CFrame.new(zone.startX, 13, 0),
			Color3.fromRGB(255, 70, 70),
			folder,
			Enum.Material.Neon
		)
		gate.Transparency = 0.7
		gate.CanCollide = false
		label(gate, { zone.name, if zone.mp > 0 then `{zone.mp} Meme Points` else "open" }, 14, 260)
	end
	-- invisible walls keep everyone on the strip
	local first, last = Zones.List[1], Zones.List[#Zones.List]
	local x0, x1 = first.startX - 20, Zones.endX(last)
	for _, side in { -1, 1 } do
		local wall = box(
			"Wall",
			Vector3.new(x1 - x0, 60, 2),
			CFrame.new((x0 + x1) / 2, 30, side * (Zones.WIDTH / 2 + 1)),
			Color3.new(1, 1, 1),
			folder
		)
		wall.Transparency = 1
	end
	local cap = box("EndWall", Vector3.new(2, 60, Zones.WIDTH), CFrame.new(x1 + 1, 30, 0), Color3.new(1, 1, 1), folder)
	cap.Transparency = 1
	return folder
end

local function homePosition(player: Player): CFrame
	local plot = Plots.of(player)
	return if plot then plot.spawn.CFrame + Vector3.new(0, 5, 0) else CFrame.new(0, 10, 0)
end

local function rootOf(player: Player): BasePart?
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not character or not humanoid or humanoid.Health <= 0 then
		return nil
	end
	return character:FindFirstChild("HumanoidRootPart") :: BasePart?
end

-- A player holds E on a nest's egg.
function Wilds.steal(player: Player, entry: Entry)
	local state = Session.get(player)
	if not state or not rootOf(player) then
		return
	end
	if state.carry then
		notify(player, "You are already carrying an egg!")
		return
	end
	if not Zones.unlocked(entry.zone, state.mp) then
		notify(player, `You need {entry.zone.mp} Meme Points for {entry.zone.name}`)
		return
	end
	local tier = Nest.take(entry.nest, Config.Wilds.NestRespawnSeconds)
	if not tier then
		return
	end
	entry.thief = player
	Session.setCarry(player, tier, entry.id)
	setEgg(entry, nil)
	Guardian.alert(entry.guardian, Config.Wilds.ChaseSeconds)
	local c = Eggs.character(entry.character)
	notify(player, `You stole the egg! {if c then c.name else "The guardian"} is chasing you. RUN HOME!`)
end

-- The egg goes back to its nest and the thief (if any) is sent home.
local function recover(entry: Entry, message: string?)
	local thief = entry.thief
	entry.thief = nil
	local carried = if thief then Session.carrying(thief) else nil
	if thief and carried then
		Session.setCarry(thief, nil)
		local root = rootOf(thief)
		if root and message then
			root.CFrame = homePosition(thief)
		end
		if message then
			notify(thief, message)
		end
	end
	if carried then
		Nest.giveBack(entry.nest, carried)
		setEgg(entry, carried)
	end
end

function Wilds.start()
	local sinceGate = 0
	local lastWarn: { [Player]: number } = {}
	RunService.Heartbeat:Connect(function(dt)
		-- guardians and nests
		for _, entry in entries do
			local target: { x: number, z: number }? = nil
			local thief = entry.thief
			if thief then
				local carried, from = Session.carrying(thief)
				local root = rootOf(thief)
				if table.find(Players:GetPlayers(), thief) == nil or not root then
					recover(entry, nil) -- they left or died carrying it: it goes back
				elseif carried == nil or from ~= entry.id then
					entry.thief = nil -- delivered it home
				else
					target = { x = root.Position.X, z = root.Position.Z }
				end
			end
			local before = entry.guardian.state
			local caught = Guardian.step(entry.guardian, dt, target, Config.Wilds.CatchRadius, Config.Wilds.Leash)
			if caught then
				local c = Eggs.character(entry.character)
				recover(entry, `{if c then c.name else "The guardian"} caught you! The egg went back.`)
			elseif before == "Chase" and entry.guardian.state == "Return" and thief then
				notify(thief, "The guardian lost you! Get the egg home.")
			end
			local g = entry.guardian
			if g.state ~= "Idle" or before ~= "Idle" then
				local look = if target then Vector3.new(target.x, 0, target.z) else Vector3.new(g.homeX, 0, g.homeZ)
				entry.model:PivotTo(CFrame.lookAt(Vector3.new(g.x, 0, g.z), look + Vector3.new(0, 0, 0)))
			end
			if Nest.tick(entry.nest, dt, function()
				return Zones.eggFor(entry.zone, math.random)
			end) then
				setEgg(entry, entry.nest.tier)
			end
		end
		-- the gates, and the "Zone" label the HUD shows
		sinceGate += dt
		if sinceGate >= Config.Wilds.GatePushSeconds then
			sinceGate = 0
			for _, player in Players:GetPlayers() do
				local root = rootOf(player)
				local state = Session.get(player)
				if root and state then
					local x = root.Position.X
					local back = Zones.pushBack(x, state.mp)
					if back then
						root.CFrame = CFrame.new(back, root.Position.Y, root.Position.Z)
						local zone = Zones.at(x) :: Zones.Zone
						local now = os.clock()
						if now - (lastWarn[player] or -10) > 3 then
							lastWarn[player] = now
							notify(player, `{zone.name} needs {zone.mp} Meme Points`)
						end
						x = back
					end
					local zone = Zones.at(x)
					player:SetAttribute("Zone", if zone then zone.name else "Home Base")
				end
			end
		end
	end)
end

return Wilds
