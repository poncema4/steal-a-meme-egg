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
local Layout = require(ReplicatedStorage.Shared.Game.Layout)
local Nest = require(ReplicatedStorage.Shared.Game.Nest)
local Look = require(script.Parent.Look)
local Models = require(script.Parent.Models)
local Session = require(script.Parent.Session)
local World = require(script.Parent.World)
local Zones = require(ReplicatedStorage.Shared.Game.Zones)

local Wilds = {}

-- One big meme boss guards each terrain; it chases whoever has stolen an egg from any of that terrain's nests.
export type Boss = {
	zone: Zones.Zone,
	guardian: Guardian.Guardian,
	model: Model,
	name: string,
}

export type Entry = {
	id: string,
	zone: Zones.Zone,
	nest: Nest.Nest,
	boss: Boss,
	guardian: Guardian.Guardian, -- the zone boss's state, shared by every nest of the terrain
	model: Model, -- the nest
	egg: BasePart,
	prompt: ProximityPrompt,
	thief: Player?,
}

-- the boss model's pivot is its body centre (14 studs tall), so its feet touch the ground when the pivot is this high
local BOSS_HEIGHT = 14
local BODY_Y = BOSS_HEIGHT / 2

local bosses: { Boss } = {}

local entries: { Entry } = {}
local notify: (Player, string) -> () = function(_player: Player, _text: string) end

function Wilds.setNotify(fn: (Player, string) -> ())
	notify = fn
end

local sfx: (Player, string) -> () = function(_player: Player, _name: string) end

local nestRate: () -> number = function()
	return 1
end

function Wilds.setNestRate(fn: () -> number)
	nestRate = fn
end

function Wilds.setSfx(fn: (Player, string) -> ())
	sfx = fn
end

function Wilds.entries(): { Entry }
	return entries
end

function Wilds.bosses(): { Boss }
	return bosses
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

local SCENERY = { Meadow = "Tree", Dune = "Cactus", Volcano = "LavaRock", Frost = "IcePine", Cosmic = "Crystal" }

-- Scenery per terrain: simple parts only (no meshes), seeded so every server builds the same map.
local function decorate(zone: Zones.Zone, nests: { Layout.Nest }, parent: Instance)
	local lavaPools: { { x: number, z: number, r: number } } = {}
	for _, prop in Layout.scenery(zone, nests) do
		local x, z, s = prop.x, prop.z, prop.size
		-- the real brick model when there is one (a lava pool still goes beside a rock)
		local name = SCENERY[zone.id]
		local placed = name ~= nil
			and Models.place(
				parent,
				"Props",
				name,
				CFrame.new(x, 0, z) * CFrame.Angles(0, prop.extra * math.pi * 2, 0),
				s / 5.5
			)
		local keepsPools = zone.id == "Volcano"
		if placed and not keepsPools then
			continue
		end
		if zone.id == "Meadow" then
			box("Trunk", Vector3.new(1.6, s * 1.6, 1.6), CFrame.new(x, s * 0.8, z), Color3.fromRGB(110, 70, 40), parent)
			local leaves = box(
				"Leaves",
				Vector3.new(s * 1.6, s, s * 1.6),
				CFrame.new(x, s * 1.9, z),
				Color3.fromRGB(40, 150, 60),
				parent
			)
			World.roundify(leaves)
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
			if not placed then
				box(
					"Rock",
					Vector3.new(s * 1.4, s, s * 1.2),
					CFrame.new(x, s * 0.5, z),
					Color3.fromRGB(50, 40, 45),
					parent
				)
			end
			-- two pools at the same height would flicker where they overlap, so a pool is skipped if it would touch another
			local overlaps = false
			for _, pool in lavaPools do
				if math.sqrt((pool.x - (x + 6)) ^ 2 + (pool.z - z) ^ 2) < pool.r + s * 2 then
					overlaps = true
				end
			end
			if prop.extra < 0.35 and not overlaps then
				table.insert(lavaPools, { x = x + 6, z = z, r = s * 2 })
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

local function buildBoss(zone: Zones.Zone, parent: Instance): Boss
	local c = Eggs.character(zone.boss) or Eggs.Characters.SoggyToast
	local model = Instance.new("Model")
	model.Name = `Boss_{zone.id}`
	local tint = Color3.fromHSV((#c.id * 0.137) % 1, 0.55, 1)
	local body = box("Body", Vector3.new(9, BOSS_HEIGHT, 9), CFrame.new(0, BODY_Y, 0), tint, model)
	model.PrimaryPart = body
	local name = `{c.name} BOSS`
	local home = Layout.bossSpot(zone)
	local boss: Boss = {
		zone = zone,
		guardian = Guardian.new(home.x, home.z, zone.guardianSpeed),
		model = model,
		name = c.name,
	}
	if Models.has("Bosses", `Boss{zone.id}`) then
		-- the boss is its real model; the (invisible) body is what moves, and carries the name
		body.Transparency = 1
		body.CanCollide = false
		Models.show(body, "Bosses", `Boss{zone.id}`, nil, Vector3.new(0, 0, -1))
		label(body, { name }, BOSS_HEIGHT / 2 + 4, 260)
	else
		local art = (Config.PetIcons :: { [string]: string })[c.id]
		if art then
			body.Transparency = 1
			body.CanCollide = false
			local card = Instance.new("BillboardGui")
			card.Name = "Portrait"
			card.Size = UDim2.fromScale(26, 26)
			card.StudsOffset = Vector3.new(0, 6, 0)
			card.MaxDistance = 500
			card.Parent = body
			local picture = Instance.new("ImageLabel")
			picture.Name = "Picture"
			picture.BackgroundTransparency = 1
			picture.Size = UDim2.fromScale(1, 1)
			picture.Image = art
			picture.Parent = card
		end
		label(body, { name }, BOSS_HEIGHT / 2 + 4, 260)
	end
	model:PivotTo(CFrame.new(boss.guardian.x, BODY_Y, boss.guardian.z))
	model.Parent = parent
	table.insert(bosses, boss)
	return boss
end

local function setEgg(entry: Entry, tier: string?, mutation: string?)
	entry.egg.Transparency = if tier then 0 else 1
	entry.prompt.Enabled = tier ~= nil
	local mutated = tier ~= nil and Look.isMutated(mutation)
	local tint = if mutation then Look.MutationColors[mutation] else nil
	entry.egg:SetAttribute("Mutation", if mutated and mutation then mutation else "Normal")
	local tag = entry.egg:FindFirstChild("MutationTag")
	if tag and tag:IsA("BillboardGui") then
		tag.Enabled = mutated
		local text = tag:FindFirstChild("L1")
		if text and text:IsA("TextLabel") and mutation then
			text.Text = `* {string.upper(mutation)} *`
			text.TextColor3 = tint or Color3.new(1, 1, 1)
		end
	end
	if tier and Models.has("Eggs", tier) then
		entry.egg.Transparency = 1
		Models.show(entry.egg, "Eggs", tier, mutation)
	else
		Models.hide(entry.egg)
	end
	if tier then
		entry.egg.Color = Look.eggColor(tier, mutation)
		entry.egg.Material = if mutated then Enum.Material.Neon else Enum.Material.SmoothPlastic
		local def = Eggs.tier(tier)
		entry.prompt.ObjectText = (if mutated then `{mutation} ` else "") .. (if def then def.name else "Egg")
	end
end

local function buildNests(zone: Zones.Zone, nests: { Layout.Nest }, boss: Boss, parent: Instance)
	for i, place in nests do
		local x, z, tier = place.x, place.z, place.tier
		local model = Instance.new("Model")
		model.Name = `Nest_{zone.id}_{i}`
		-- a Roblox cylinder runs along its X size, so the thin height is X and the disc is Y by Z; the turn stands it up
		local ring = box("Ring", Vector3.new(0.6, 9, 9), CFrame.new(x, 0.3, z), Color3.fromRGB(120, 85, 50), model)
		ring.Shape = Enum.PartType.Cylinder
		ring.CFrame = CFrame.new(x, 0.3, z) * CFrame.Angles(0, 0, math.pi / 2)
		if Models.place(model, "Props", "Nest", CFrame.new(x, 0, z), 1) then
			ring.Transparency = 1 -- the twig nest stands on it; the ring stays as the invisible floor
			ring.CanCollide = false
		end
		local egg = box("Egg", Vector3.new(4, 5, 4), CFrame.new(x, 3.1, z), Color3.new(1, 1, 1), model)
		World.roundify(egg)
		egg.CanCollide = false
		local prompt = Instance.new("ProximityPrompt")
		prompt.ActionText = "Steal egg"
		prompt.HoldDuration = Config.Wilds.StealHoldSeconds
		prompt.MaxActivationDistance = 11
		prompt.RequiresLineOfSight = false
		prompt.Parent = egg
		label(egg, { "" }, 4.6, 200)
		local mutationTag = egg:FindFirstChild("Tag")
		if mutationTag then
			mutationTag.Name = "MutationTag"
		end
		local entry: Entry = {
			id = model.Name,
			zone = zone,
			nest = Nest.new(tier, Eggs.nestMutation(table.find(Zones.List, zone) or 1, math.random)),
			boss = boss,
			guardian = boss.guardian,
			model = model,
			egg = egg,
			prompt = prompt,
			thief = nil,
		}
		model.Parent = parent
		setEgg(entry, tier, entry.nest.mutation)
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
		local nests = Layout.nests(zone)
		decorate(zone, nests, folder)
		buildNests(zone, nests, buildBoss(zone, folder), folder)
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
	return folder
end

local function rootOf(player: Player): BasePart?
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not character or not humanoid or humanoid.Health <= 0 then
		return nil
	end
	return character:FindFirstChild("HumanoidRootPart") :: BasePart?
end

-- A catch flings you back toward the Safe Zone like a rag doll: you tumble for a moment, then have to walk the rest of the way.
local FLING = Vector3.new(-120, 90, 0)
local TUMBLE_SECONDS = 1.4

local function fling(player: Player)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = rootOf(player)
	if not humanoid or not root then
		return
	end
	humanoid.PlatformStand = true
	root.AssemblyLinearVelocity = FLING
	task.delay(TUMBLE_SECONDS, function()
		if humanoid.Parent then
			humanoid.PlatformStand = false
		end
	end)
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
	local tier, mutation = Nest.take(entry.nest, Config.Wilds.NestRespawnSeconds)
	if not tier then
		return
	end
	entry.thief = player
	Session.setCarry(player, tier, entry.id, mutation)
	setEgg(entry, nil)
	Guardian.alert(entry.guardian, Config.Wilds.ChaseSeconds)
	sfx(player, "steal")
	sfx(player, "roar")
	notify(player, `You stole the egg! {entry.boss.name} is chasing you. RUN HOME!`)
end

-- The egg goes back to its nest and the thief (if any) is sent home.
local function recover(entry: Entry, message: string?, sendHome: boolean?)
	local thief = entry.thief
	entry.thief = nil
	local carried: string?, carriedMutation: string? = nil, nil
	if thief then
		local tier, _, mutation = Session.carrying(thief)
		carried, carriedMutation = tier, mutation
	end
	if thief and carried then
		Session.setCarry(thief, nil)
		if message and sendHome ~= false then
			fling(thief)
		end
		if message then
			notify(thief, message)
			sfx(thief, "caught")
		end
	end
	if carried then
		Nest.giveBack(entry.nest, carried, carriedMutation)
		setEgg(entry, carried, carriedMutation)
	end
end

-- The player lets go of the egg they are carrying: it goes back to its nest, and they stay where they are.
function Wilds.drop(player: Player)
	for _, entry in entries do
		if entry.thief == player then
			recover(entry, "You dropped the egg. It went back to its nest.", false)
			return
		end
	end
end

function Wilds.start()
	local sinceGate = 0
	local lastWarn: { [Player]: number } = {}
	RunService.Heartbeat:Connect(function(dt: number)
		-- guardians and nests
		for _, entry in entries do
			local thief = entry.thief
			if thief then
				local carried, from = Session.carrying(thief)
				if table.find(Players:GetPlayers(), thief) == nil or not rootOf(thief) then
					recover(entry, nil) -- they left or died carrying it: it goes back
				elseif carried == nil or from ~= entry.id then
					entry.thief = nil -- delivered it home
				end
			end
			-- a nest grows a new egg only once the old one is resolved (delivered, or back after a catch): otherwise a second
			-- thief could take the regrown egg and overwrite the first one's record
			if
				entry.thief == nil
				and Nest.tick(entry.nest, dt * nestRate(), function()
					return Zones.eggFor(entry.zone, math.random),
						Eggs.nestMutation(table.find(Zones.List, entry.zone) or 1, math.random)
				end)
			then
				setEgg(entry, entry.nest.tier, entry.nest.mutation)
			end
			-- a Rainbow egg slowly cycles through every colour
			if entry.egg:GetAttribute("Mutation") == "Rainbow" and entry.nest.tier ~= nil then
				entry.egg.Color = Color3.fromHSV((os.clock() * 0.25) % 1, 0.6, 1)
			end
		end
		-- each terrain's boss chases the nearest thief who stole from it
		for _, boss in bosses do
			local nearest: Entry? = nil
			local nearestDistance = math.huge
			local g = boss.guardian
			for _, entry in entries do
				local root = if entry.boss == boss and entry.thief then rootOf(entry.thief) else nil
				if root then
					local d = (Vector3.new(g.x, 0, g.z) - Vector3.new(root.Position.X, 0, root.Position.Z)).Magnitude
					if d < nearestDistance then
						nearest, nearestDistance = entry, d
					end
				end
			end
			local target: { x: number, z: number }? = nil
			if nearest and nearest.thief then
				local root = rootOf(nearest.thief)
				if root then
					target = { x = root.Position.X, z = root.Position.Z }
				end
			end
			local before = g.state
			local caught = Guardian.step(g, dt, target, Config.Wilds.CatchRadius, Config.Wilds.Leash)
			if caught and nearest then
				recover(nearest, `{boss.name} caught you! The egg went back.`)
				-- another thief of this terrain is still running: the boss goes after them next
				for _, other in entries do
					if other.boss == boss and other.thief then
						Guardian.alert(g, Config.Wilds.ChaseSeconds)
						break
					end
				end
			elseif before == "Chase" and g.state == "Return" then
				for _, entry in entries do
					if entry.boss == boss and entry.thief then
						notify(entry.thief, "The boss lost you! Get the egg home.")
					end
				end
			end
			if g.state ~= "Idle" or before ~= "Idle" then
				local here = Vector3.new(g.x, BODY_Y, g.z)
				local look = if target
					then Vector3.new(target.x, BODY_Y, target.z)
					else Vector3.new(g.homeX, BODY_Y, g.homeZ)
				if (look - here).Magnitude > 0.05 then
					boss.model:PivotTo(CFrame.lookAt(here, look))
				else
					-- already there: looking at where you stand has no direction (an invalid rotation in Roblox), so keep facing
					boss.model:PivotTo(CFrame.new(here) * boss.model:GetPivot().Rotation)
				end
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
					player:SetAttribute("Zone", if zone then zone.name else "Safe Zone")
				end
			end
		end
	end)
end

return Wilds
