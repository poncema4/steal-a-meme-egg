--!strict
-- Traps on the real server: placing, the limit of 3, springing on a guardian, rotting away, and cleaning up after a player.
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

	-- rotting
	world.advance(Trap.LIFETIME + 1)
	t.equal("untouched traps rot away", ana:GetAttribute("TrapsPlaced"), 0)
	t.equal("and their parts go too", #folder:GetChildren(), 0)

	-- a fresh one, then the player leaves
	root.Position = V3.new(meadow.startX + 60, 3, 0)
	place:FireServer()
	t.equal("a new trap goes down after the old ones rot", #folder:GetChildren(), 1)
	world.removePlayer(ana)
	world.advance(0.2)
	t.equal("a leaving player's traps are removed", #folder:GetChildren(), 0)
end
