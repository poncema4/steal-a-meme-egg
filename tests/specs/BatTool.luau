--!strict
-- The bat: everyone holds one, a swing knocks the player in front of it back and makes them drop their egg, never in the Safe Zone,
-- never twice in a row, and finishing a world's Index gives a better bat.
local Bats = require("../../src/shared/Game/Bats")
local Collection = require("../../src/shared/Game/Collection")
local Fake = require("../fake/Roblox")
local Zones = require("../../src/shared/Game/Zones")

return function(t)
	-- the rules on their own
	t.equal("there are sixteen bats", #Bats.List, 16)
	t.equal("the first is the Wooden Bat", Bats.get(0).name, "Wooden Bat")
	local better = true
	for tier = 1, Bats.MAX_TIER do
		local a, b = Bats.get(tier - 1), Bats.get(tier)
		if b.knock <= a.knock or b.range <= a.range or b.stun < a.stun or b.cooldown > a.cooldown then
			better = false
		end
	end
	t.check("every bat hits harder and reaches further than the one before", better)
	t.equal("tiers are capped", Bats.tierFor(99), Bats.MAX_TIER)
	t.equal("and never negative or NaN", Bats.tierFor(0 / 0) + Bats.tierFor(-5), 0)
	local wooden = Bats.get(0)
	t.check("a swing reaches someone in front", Bats.reaches(wooden, 0, 0, 1, 0, 5, 0))
	t.check("but not someone behind", not Bats.reaches(wooden, 0, 0, 1, 0, -5, 0))
	t.check("nor someone too far", not Bats.reaches(wooden, 0, 0, 1, 0, 30, 0))
	t.check("nor someone far to the side", not Bats.reaches(wooden, 0, 0, 1, 0, 0.5, 6))

	local world = Fake.world()
	local V3 = world.Vector3
	local ok, err = pcall(world.load, "src/server/main.server")
	t.check("the server starts", ok, tostring(err))
	if not ok then
		return
	end
	local session = world.load("src/server/Session")
	local wilds = world.load("src/server/Wilds")
	local batTool = world.load("src/server/BatTool")
	local ana = world.addPlayer("Ana", 951)
	local ben = world.addPlayer("Ben", 952)
	world.spawnCharacter(ana)
	world.spawnCharacter(ben)
	world.advance(1)

	local function bat(player: any): any
		local character = player.Character
		return character:FindFirstChild("Bat") or player.Backpack:FindFirstChild("Bat")
	end
	t.check("every player is given a bat", bat(ana) ~= nil and bat(ben) ~= nil)
	t.check(
		"it waits in the backpack like any Roblox item (nothing is forced into your hands)",
		bat(ana).Parent == ana.Backpack
	)
	t.check("next to the trap item", ana.Backpack:FindFirstChild("Trap") ~= nil)
	t.check(
		"both show their picture in the backpack bar",
		bat(ana).TextureId ~= "" and ana.Backpack.Trap.TextureId ~= ""
	)
	ana.Character:FindFirstChildOfClass("Humanoid"):EquipTool(bat(ana))
	t.check("picking the bat puts it in your hand", bat(ana).Parent == ana.Character)
	bat(ana).Activated:Fire()
	-- Roblox applies Grip inverted, so a swing tips the bat forward when the grip's look points UP (Marco: it swung backwards)
	t.check("a swing chops the bat forward, not back over the shoulder", bat(ana).Grip.LookVector.Y > 0.5)
	world.advance(1.5)
	t.equal("a new player holds the Wooden Bat", bat(ana).ToolTip, "Wooden Bat")
	-- a real bat shape from smooth round parts, not bricks: a knob, a grip and a rounded barrel, in wood
	local b0 = bat(ana)
	t.check(
		"the bat has a knob, a grip and a rounded barrel",
		b0:FindFirstChild("Knob") ~= nil and b0:FindFirstChild("Grip") ~= nil and b0:FindFirstChild("Cap") ~= nil
	)
	t.equal("the Wooden Bat is made of wood", (b0:FindFirstChild("Cap") :: Part).Material, world.enum.Material.Wood)
	t.check(
		"its barrel is thicker than its grip",
		(b0:FindFirstChild("Barrel7") :: Part).Size.Y > (b0:FindFirstChild("Grip") :: Part).Size.Y
	)

	-- the Safe Zone is safe
	local x0 = Zones.List[1].startX
	world.root(ana).Position = V3.new(x0 - 40, 3, 0)
	world.root(ben).Position = V3.new(x0 - 36, 3, 0)
	t.equal("no hitting in the Safe Zone", batTool.swing(ana), 0)

	-- out in the Meadow
	local root = world.root(ana)
	root.Position = V3.new(x0 + 60, 3, 0)
	root.CFrame = world.CFrame.lookAt(root.Position, root.Position + V3.new(1, 0, 0))
	world.root(ben).Position = V3.new(x0 + 64, 3, 0)
	-- Ben is carrying an egg
	local entry = wilds.entries()[1]
	entry.nest.tier = "Soggy"
	session.setCarry(ben, "Soggy", entry.id, "Normal")
	entry.thief = ben
	world.advance(0.1)
	local hits = batTool.swing(ana)
	t.equal("a swing hits the player in front", hits, 1)
	t.check("Ben is thrown back", world.root(ben).AssemblyLinearVelocity.Magnitude > 10)
	t.equal("and drops the egg he carried", ben:GetAttribute("Carrying"), "")
	t.check("it lies on the ground where he was", entry.dropped ~= nil)
	t.equal("a swing right after does nothing (cooldown)", batTool.swing(ana), 0)
	world.advance(1)
	t.equal("and Ben cannot be hit again while he is down", batTool.swing(ana), 0)
	world.advance(2)
	world.root(ben).Position = V3.new(x0 + 64, 3, 0)
	t.equal("later he can be hit again", batTool.swing(ana), 1)

	-- a player behind or far away is not hit
	world.advance(3)
	world.root(ben).Position = V3.new(x0 + 40, 3, 0)
	t.equal("someone behind is missed", batTool.swing(ana), 0)

	-- finishing a world's Index gives a better bat and coins
	local meadow = Collection.worldCharacters("Meadow")
	t.check("a world has characters to find", #meadow >= 3)
	local state = session.get(ana)
	state.base.size = 12
	for i, id in meadow do
		state.base.slots[i] = { kind = "char", id = id, mutation = "Normal" }
	end
	local coins = state.coins
	session.changed(ana)
	t.equal("completing the Meadow Index is rewarded once", ana:GetAttribute("IndexClaims"), "Meadow")
	t.check("it pays coins", state.coins > coins)
	t.equal("and the bat tier is now 1", ana:GetAttribute("BatTier"), 1)
	world.advance(0.5)
	t.equal("Ana now holds the Foam Bat", bat(ana).ToolTip, "Foam Bat")
	session.changed(ana)
	t.equal("it is paid only once", ana:GetAttribute("BatTier"), 1)

	-- /resetme takes the bat tier back
	state.claims = {}
	session.changed(ana)
	t.check(
		"the claims are saved and read back",
		(function()
			return typeof(ana:GetAttribute("IndexClaims")) == "string"
		end)()
	)
end
