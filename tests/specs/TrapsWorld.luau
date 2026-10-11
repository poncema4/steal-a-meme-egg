--!strict
-- Traps on the real server: placing, the limit of 3, the Trap item leaving and coming back, springing on a guardian, holding
-- another player for 10 seconds, and cleaning up after a player.
local Fake = require("../fake/Roblox")
local Guardian = require("../../src/shared/Game/Guardian")
local Trap = require("../../src/shared/Game/Trap")
local Zones = require("../../src/shared/Game/Zones")

return function(t)
	local world = Fake.world()
	local V3 = world.Vector3
	local ok, err = pcall(world.load, "src/server/main.server")
	t.check("the server starts", ok, tostring(err))
	if not ok then
		return
	end
	local wilds = world.load("src/server/Wilds")
	local remotes = world.service("ReplicatedStorage"):FindFirstChild("Remotes") :: Instance
	local place = remotes:FindFirstChild("PlaceTrap") :: RemoteEvent
	t.check("the server offers PlaceTrap", place ~= nil)
	local folder = world.workspace:FindFirstChild("Traps") :: Instance
	local ana = world.addPlayer("Ana", 61)
	world.spawnCharacter(ana)
	world.advance(0.6)
	world.setLocal(ana)
	local root = world.root(ana)

	-- not in the Safe Zone
	place:FireServer()
	t.equal("no traps in the Safe Zone", ana:GetAttribute("TrapsPlaced"), 0)
	t.equal("and no part", #folder:GetChildren(), 0)

	-- out in the Meadow
	local meadow = Zones.List[1]
	root.Position = V3.new(meadow.startX + 60, 3, 0)
	place:FireServer()
	t.equal("a trap goes down in the Meadow", ana:GetAttribute("TrapsPlaced"), 1)
	t.equal("and is drawn", #folder:GetChildren(), 1)
	place:FireServer()
	t.equal("the next trap needs the cooldown", ana:GetAttribute("TrapsPlaced"), 1)
	for i = 2, 3 do
		world.advance(Trap.COOLDOWN + 0.1)
		root.Position = V3.new(meadow.startX + 60 + i * 12, 3, 0)
		place:FireServer()
	end
	t.equal("three traps are down", ana:GetAttribute("TrapsPlaced"), 3)
	local function trapItem(p: Player): boolean
		local backpack = p:FindFirstChildOfClass("Backpack") :: Instance
		return backpack:FindFirstChild("Trap") ~= nil or (p.Character :: Model):FindFirstChild("Trap") ~= nil
	end
	t.check("with all 3 out, the Trap item leaves the inventory", not trapItem(ana))
	world.advance(Trap.COOLDOWN + 0.1)
	root.Position = V3.new(meadow.startX + 150, 3, 0)
	place:FireServer()
	place:FireServer("junk", 5, {})
	t.equal("a fourth is refused", ana:GetAttribute("TrapsPlaced"), 3)
	t.equal("and no fourth part is drawn", #folder:GetChildren(), 3)

	-- a guardian on the move springs the nearest trap and is held
	local entry = wilds.entries()[1]
	local g = entry.guardian
	local spot = world.service("Players") and folder:GetChildren()[1]
	local trapAt = (spot :: BasePart).Position
	g.x, g.z = trapAt.X, trapAt.Z
	world.advance(0.2)
	t.equal("a sleeping guardian does not spring a trap", ana:GetAttribute("TrapsPlaced"), 3)
	Guardian.alert(g, 12)
	world.advance(0.2)
	t.equal("a guardian on the move springs it", ana:GetAttribute("TrapsPlaced"), 2)
	t.equal("the trap is used up", #folder:GetChildren(), 2)
	t.check("and the guardian is held", g.stun > 0)
	local x0 = g.x
	world.advance(1)
	t.equal("a held guardian stays put", g.x, x0)
	world.advance(Trap.STUN + 1)
	t.check("then it moves again (or heads home)", g.state ~= "Chase" or g.x ~= x0)

	t.check("a trap used on a guardian gives the Trap item back", trapItem(ana))

	-- another player steps on one: held still for 10 seconds, then Ana gets that trap back
	local ben = world.addPlayer("Ben", 62)
	world.spawnCharacter(ben)
	world.advance(0.6)
	local benRoot = world.root(ben)
	local trapPart = folder:GetChildren()[1] :: BasePart
	local before = ana:GetAttribute("TrapsPlaced") :: number
	benRoot.Position = V3.new(trapPart.Position.X, 3, trapPart.Position.Z)
	world.advance(0.2)
	t.check("Ben is held still", benRoot.Anchored == true)
	t.check("and knows for how long", ben:GetAttribute("TrappedUntil") ~= nil)
	t.equal("the trap still counts while it holds him", ana:GetAttribute("TrapsPlaced"), before)
	world.advance(Trap.HOLD - 1)
	t.check("he is still held after 9 seconds", benRoot.Anchored == true)
	world.advance(1.5)
	t.check("after 10 seconds he can move", benRoot.Anchored == false and ben:GetAttribute("TrappedUntil") == nil)
	t.check("and Ana has that trap back", (ana:GetAttribute("TrapsPlaced") :: number) < before)
	benRoot.Position = V3.new(trapPart.Position.X, 3, trapPart.Position.Z + 200)
	world.removePlayer(ben)
	-- clear the rest so the next part starts empty
	for _ = 1, 3 do
		local left = folder:GetChildren()[1] :: BasePart?
		if left then
			g.state, g.stun = "Idle", 0
			g.x, g.z = left.Position.X, left.Position.Z
			Guardian.alert(g, 12)
			world.advance(Trap.STUN + 1)
		end
	end
	t.equal("guardians clear the last trap", ana:GetAttribute("TrapsPlaced"), 0)

	-- a fresh one, then the player leaves
	root.Position = V3.new(meadow.startX + 60, 3, 0)
	place:FireServer()
	t.equal("a new trap goes down once there is room", #folder:GetChildren(), 1)
	world.removePlayer(ana)
	world.advance(0.2)
	t.equal("a leaving player's traps are removed", #folder:GetChildren(), 0)
end
