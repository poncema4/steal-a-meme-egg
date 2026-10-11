--!strict
-- Traps out in the Wilds. A player presses 1/2/3 (or taps a hotbar slot) and a trap goes down where they stand; a guardian
-- that runs over one is held for a few seconds. At most 3 per player (shared/Game/Trap). Traps only work out in a terrain:
-- the Safe Zone is for safety.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Guardian = require(ReplicatedStorage.Shared.Game.Guardian)
local Trap = require(ReplicatedStorage.Shared.Game.Trap)
local Zones = require(ReplicatedStorage.Shared.Game.Zones)
local Models = require(script.Parent.Models)
local Session = require(script.Parent.Session)
local Wilds = require(script.Parent.Wilds)

local Traps = {}

local springListeners: { (Player) -> () } = {}

-- Called when one of a player's traps holds a boss.
function Traps.onSprung(fn: (Player) -> ())
	table.insert(springListeners, fn)
end

local states: { [Player]: Trap.State } = {}
local pieces: { [Trap.Spot]: Part } = {}
local folder: Folder? = nil
local notify: (Player, string) -> () = function(_player: Player, _text: string) end
local sfx: (Player, string) -> () = function(_player: Player, _name: string) end

local function publish(player: Player)
	local state = states[player]
	player:SetAttribute("TrapsPlaced", if state then Trap.count(state) else 0)
	-- when the next trap is ready, in server time (the client cannot read the server's os.clock)
	local wait = if state then math.max(0, state.lastPlaced + Trap.COOLDOWN - os.clock()) else 0
	player:SetAttribute("TrapReadyAt", workspace:GetServerTimeNow() + wait)
end

local function build(x: number, z: number): Part
	local base = Instance.new("Part")
	base.Name = "Trap"
	base.Size = Vector3.new(5, 0.4, 5)
	base.CFrame = CFrame.new(x, 0.2, z)
	base.Color = Color3.fromRGB(60, 60, 70)
	base.Material = Enum.Material.Metal
	base.Anchored = true
	base.CanCollide = false
	for _, corner in { { -1.6, -1.6 }, { 1.6, -1.6 }, { -1.6, 1.6 }, { 1.6, 1.6 } } do
		local spike = Instance.new("Part")
		spike.Name = "Spike"
		spike.Size = Vector3.new(0.7, 1.4, 0.7)
		spike.CFrame = CFrame.new(x + corner[1], 1.1, z + corner[2])
		spike.Color = Color3.fromRGB(210, 40, 40)
		spike.Anchored = true
		spike.CanCollide = false
		spike.Parent = base
	end
	base.Parent = folder
	-- the real model: a steel bear trap lying open; the plain plate and spikes stay as the fallback
	if Models.place(base, "Props", "BearTrap", CFrame.new(x, 0, z), 0.9) then
		base.Transparency = 1
		for _, spike in base:GetChildren() do
			if spike.Name == "Spike" then
				spike:Destroy()
			end
		end
	end
	return base
end

local function remove(spot: Trap.Spot)
	local piece = pieces[spot]
	if piece then
		piece:Destroy()
		pieces[spot] = nil
	end
end

-- Puts a trap down where the player stands. Returns (ok, message).
function Traps.place(player: Player): (boolean, string)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root or not humanoid or humanoid.Health <= 0 then
		return false, "no character"
	end
	local x, z = root.Position.X, root.Position.Z
	if Zones.at(x) == nil then
		return false, "Traps only work out in the Wilds"
	end
	local state = states[player]
	if not state then
		state = Trap.new()
		states[player] = state
	end
	local now = os.clock()
	-- rotten traps go first (their parts too), so they never block a new one
	for _, spot in table.clone(state.spots) do
		if spot.expires <= now then
			remove(spot)
		end
	end
	local perks = Session.perks(player)
	local ok, why = Trap.place(state, x, z, now, perks.trapMax, perks.trapCooldown)
	if not ok then
		return false, why or "cannot place"
	end
	pieces[state.spots[#state.spots]] = build(x, z)
	publish(player)
	return true, `Trap set ({Trap.count(state)}/{Trap.MAX})`
end

function Traps.count(player: Player): number
	local state = states[player]
	return if state then Trap.count(state) else 0
end

function Traps.start(remotes: Instance, notifyFn: (Player, string) -> (), sfxFn: (Player, string) -> ())
	notify, sfx = notifyFn, sfxFn
	local f = Instance.new("Folder")
	f.Name = "Traps"
	f.Parent = workspace
	folder = f
	local remote = Instance.new("RemoteEvent")
	remote.Name = "PlaceTrap"
	remote.Parent = remotes
	remote.OnServerEvent:Connect(function(player: Player)
		local ok, message = Traps.place(player)
		notify(player, message)
		if ok then
			sfx(player, "click")
		end
	end)
	Players.PlayerAdded:Connect(publish) -- so the HUD has a number (0) before the first trap
	for _, player in Players:GetPlayers() do
		publish(player)
	end
	Players.PlayerRemoving:Connect(function(player)
		local state = states[player]
		if state then
			for _, spot in state.spots do
				remove(spot)
			end
			states[player] = nil
		end
	end)
	RunService.Heartbeat:Connect(function()
		local now = os.clock()
		for player, state in states do
			local changed = false
			-- rotten traps disappear
			for _, spot in table.clone(state.spots) do
				if spot.expires <= now then
					remove(spot)
					changed = true
				end
			end
			Trap.prune(state, now)
			-- a guardian that is on the move and runs onto a trap is held
			for _, entry in Wilds.entries() do
				local g = entry.guardian
				if g.state ~= "Idle" and g.stun <= 0 then
					local index = Trap.hit(state, g.x, g.z)
					if index then
						local spot = state.spots[index]
						table.remove(state.spots, index)
						remove(spot)
						Guardian.stunned(g, Trap.STUN)
						notify(player, "Your trap caught a guardian!")
						for _, fn in springListeners do
							fn(player)
						end
						sfx(player, "caught")
						changed = true
					end
				end
			end
			if changed then
				publish(player)
			end
		end
	end)
end

return Traps
