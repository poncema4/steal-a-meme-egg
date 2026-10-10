--!strict
-- A soak test: eight simulated players doing random things for ten simulated minutes (stealing, being caught, delivering,
-- stealing from guardians, using the pads, admin events, leaving and rejoining). It checks that nothing throws and that
-- the numbers that must always hold really always hold.
local Fake = require("../fake/Roblox")
local Zones = require("../../src/shared/Game/Zones")

return function(t)
	math.randomseed(1234)
	local world = Fake.world()
	world.studio = true -- everyone is an admin here, so admin commands run too
	local V3 = world.Vector3
	local ok, err = pcall(world.load, "src/server/main.server")
	t.check("the server starts", ok, tostring(err))
	if not ok then
		return
	end
	local session = world.load("src/server/Session")
	local plots = world.load("src/server/Plots")
	local wilds = world.load("src/server/Wilds")
	local liveOps = world.load("src/server/LiveOps")
	local entries = wilds.entries()

	local players: { any } = {}
	for i = 1, 8 do
		local p = world.addPlayer(`Soak{i}`, 500 + i)
		world.spawnCharacter(p)
		table.insert(players, p)
		session.add(p, 50000) -- enough to try the shop
	end
	world.advance(1)

	local failure: string? = nil
	local function fail(message: string)
		if not failure then
			failure = message
		end
	end

	local function finite(n: any): boolean
		return type(n) == "number" and n == n and n ~= math.huge and n ~= -math.huge
	end

	local lingering: { [any]: number } = {}
	local function checkInvariants(step: number)
		for _, p in players do
			local state = session.get(p)
			if state then
				if not finite(state.coins) or state.coins < 0 then
					fail(`step {step}: {p.Name} has bad coins {state.coins}`)
				end
				if not finite(state.mp) or state.mp < 0 then
					fail(`step {step}: {p.Name} has bad Meme Points {state.mp}`)
				end
				if not finite(state.speedXp) or state.speedXp < 0 then
					fail(`step {step}: {p.Name} has bad speed XP`)
				end
				if state.base.size < 6 or state.base.size > 12 then
					fail(`step {step}: {p.Name} has a base of size {state.base.size}`)
				end
				for slot in state.base.slots do
					if slot < 1 or slot > state.base.size then
						fail(`step {step}: {p.Name} has an item in slot {slot} of {state.base.size}`)
					end
				end
				-- carrying an egg means exactly one nest has you as its thief
				local carrying = state.carry ~= nil
				local holders = 0
				for _, entry in entries do
					if entry.thief == p then
						holders += 1
					end
				end
				if carrying and holders ~= 1 then
					fail(`step {step}: {p.Name} carries an egg but {holders} nests have them as thief`)
				end
				-- a thief marker may linger for a tick while the guardian notices, but never for two checks in a row
				if not carrying and holders > 0 then
					lingering[p] = (lingering[p] or 0) + 1
					if lingering[p] >= 2 then
						fail(`step {step}: {p.Name} is not carrying but {holders} nests still name them as thief`)
					end
				else
					lingering[p] = 0
				end
			end
		end
		for _, entry in entries do
			if entry.nest.tier == nil and not (entry.thief ~= nil or entry.nest.regrow > 0) then
				fail(`step {step}: nest {entry.id} is empty with nobody to blame and no regrow timer`)
			end
			local g = entry.guardian
			if not finite(g.x) or not finite(g.z) then
				fail(`step {step}: guardian {entry.id} has a bad position`)
			end
		end
	end

	local stuck: { [any]: number } = {}
	local steps = 1200 -- 600 simulated seconds
	for step = 1, steps do
		for _, p in players do
			local state = session.get(p)
			local character = p.Character
			local root = character and world.root(p)
			if state and root then
				local roll = math.random()
				local home = plots.of(p)
				if state.carry then
					-- the runner keeps running home (they move continuously, below, every tenth of a second)
					stuck[p] = (stuck[p] or 0) + 1
					if stuck[p] > 400 then
						fail(`step {step}: {p.Name} has carried an egg for 200 seconds`)
					end
				else
					stuck[p] = 0
					if roll < 0.12 then
						-- go and steal from a random nest this player has unlocked
						local entry = entries[math.random(1, #entries)]
						if Zones.unlocked(entry.zone, state.mp) and entry.prompt.Enabled then
							root.Position = V3.new(entry.egg.Position.X - 7, 3, entry.egg.Position.Z)
							entry.prompt.Triggered:Fire(p)
						end
					elseif roll < 0.2 then
						session.grantEgg(p, "Soggy") -- eggs also arrive from the daily reward and the shop
					elseif roll < 0.3 and home then
						for _, action in { "Upgrade treadmill", "Buy slot", "Skip hatch" } do
							local found = world.prompts(home.model, action)
							if #found > 0 and math.random() < 0.3 then
								found[math.random(1, #found)].Triggered:Fire(p)
							end
						end
					elseif roll < 0.31 then
						liveOps.command(p, "/event eggrain 20")
					elseif roll < 0.315 then
						session.addPoints(p, math.random(1, 500)) -- open more of the map over time
					elseif roll < 0.318 then
						session.addSpeedXp(p, math.random(200, 4000)) -- train, so deeper terrains can be outrun
					elseif roll < 0.32 then
						session.add(p, 5e9)
						world.load("src/server/LimitedService").buyWithCoins(p)
					elseif roll < 0.325 then
						session.rebirth(p)
					end
				end
			end
		end
		-- someone leaves and comes back now and then
		if step % 150 == 0 then
			local i = math.random(1, #players)
			local old = players[i]
			world.removePlayer(old)
			local back = world.addPlayer(old.Name, old.UserId)
			world.spawnCharacter(back)
			players[i] = back
		end
		for _ = 1, 5 do
			for _, p in players do
				local state = session.get(p)
				local home = plots.of(p)
				local character = p.Character
				local root = character and world.root(p)
				if state and state.carry and home and root then
					local speed = world.humanoid(p).WalkSpeed
					local dx, dz = home.center.X - root.Position.X, home.center.Z - root.Position.Z
					local m = math.sqrt(dx * dx + dz * dz)
					if m > 0.1 then
						local len = math.min(speed * 0.1, m)
						root.Position = root.Position + V3.new(dx / m * len, 0, dz / m * len)
					end
				end
			end
			world.advance(0.1)
		end
		if step % 20 == 0 then
			checkInvariants(step)
		end
		if failure then
			break
		end
	end
	t.check(
		"ten simulated minutes of 8 players ran without an error or a broken invariant",
		failure == nil,
		tostring(failure)
	)

	-- nothing the game does should have warned (DataStore and MemoryStore are faked, so any warning is ours)
	local ours = {}
	for _, w in world.warnings do
		table.insert(ours, w)
	end
	t.check("the game raised no warnings during the soak", #ours == 0, table.concat(ours, " / "):sub(1, 300))

	-- the world did not leak: parts are about the same as at the start
	local total = #world.workspace:GetDescendants()
	t.check("the part count stayed sane (no leak)", total < 12000, tostring(total))
	local stole, delivered = 0, 0
	for _, p in players do
		local state = session.get(p)
		if state then
			stole += if state.mp > 0 then 1 else 0
			delivered += state.rebirths
		end
	end
	-- the test must not be vacuous: count what the sound effects (one per event) say really happened
	local counts: { [string]: number } = {}
	for _, entry in world.log do
		if entry.remote == "Sfx" and entry.to == "client" then
			local name = tostring(entry.args[2])
			counts[name] = (counts[name] or 0) + 1
		end
	end
	local summary = {}
	for _, name in { "steal", "caught", "deliver", "hatch", "limited", "caught" } do
		table.insert(summary, `{name}={counts[name] or 0}`)
	end
	local detail = table.concat(summary, " ")
	t.check("the players stole eggs", (counts.steal or 0) >= 20, detail)
	t.check("some were caught", (counts.caught or 0) >= 1, detail)
	t.check("many got home", (counts.deliver or 0) >= 30, detail)
	t.check("eggs hatched", (counts.hatch or 0) >= 20, detail)
	t.check("someone earned Meme Points", stole > 0, tostring(stole))
	print("SOAK " .. detail .. " rebirths=" .. tostring(delivered))
end
