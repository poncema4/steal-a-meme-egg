--!strict
-- Throws garbage at everything a client (or a chat message) can reach: every remote the server listens to and every admin
-- command. Nothing may error, and nobody's money or state may end up broken, whatever is sent.
local Fake = require("../fake/Roblox")

local function finite(n: any): boolean
	return type(n) == "number" and n == n and n ~= math.huge and n ~= -math.huge
end

return function(t)
	math.randomseed(99)
	local world = Fake.world()
	local ok, err = pcall(world.load, "src/server/main.server")
	t.check("the server starts", ok, tostring(err))
	if not ok then
		return
	end
	local session = world.load("src/server/Session")
	local liveOps = world.load("src/server/LiveOps")
	local storage = world.service("ReplicatedStorage")
	local remotes = storage:FindFirstChild("Remotes") :: Instance

	local ana = world.addPlayer("Fuzzy", 701)
	world.spawnCharacter(ana)
	world.advance(1)
	world.setLocal(ana)

	local junk: { any } = {
		nil,
		true,
		false,
		0,
		-1,
		1e308,
		-1e308,
		0 / 0,
		math.huge,
		-math.huge,
		2 ^ 53,
		"",
		"pass",
		"product",
		"coins2x",
		"hatch1",
		"limitedGoose",
		"../../etc/passwd",
		string.rep("x", 20000),
		{},
		{ 1, 2, 3 },
		{ kind = "pass", key = "coins2x" },
		{ [1] = { [1] = {} } },
		"\0\1\2",
		"💥🥚",
	}
	local picks = #junk + 1 -- nil is a valid pick too

	-- every remote a client can fire at the server
	local fired = 0
	local names: { string } = {}
	for _, remote in remotes:GetChildren() do
		if remote:IsA("RemoteEvent") then
			table.insert(names, remote.Name)
			for _ = 1, 400 do
				local a, b, c = junk[math.random(1, picks)], junk[math.random(1, picks)], junk[math.random(1, picks)]
				world.advance(1.1) -- past the per-remote rate limits so the arguments are really looked at
				local sent, why = pcall(function()
					(remote :: RemoteEvent):FireServer(a, b, c)
				end)
				fired += 1
				if not sent then
					t.check(`firing {remote.Name} with junk does not throw`, false, tostring(why))
					break
				end
			end
		end
	end
	t.check("the server has remotes to fuzz", #names >= 2, table.concat(names, ","))
	t.check("and all of them survived the junk", fired >= 400)

	-- the admin chat commands, with random words and numbers
	local words = {
		"/event",
		"/give",
		"/giveall",
		"/announce",
		"/clear",
		"/help",
		"/nuke",
		"/",
		"",
		"luckyhour",
		"megaluck",
		"eggrain",
		"frenzy",
		"coinrain",
		"-5",
		"0",
		"1e999",
		"nan",
		"inf",
		"99999999999999",
		"0.5",
		"💥",
		"a b c",
		string.rep("z", 500),
	}
	local worked = 0
	for _ = 1, 600 do
		local line = words[math.random(1, #words)]
		for _ = 1, math.random(0, 3) do
			line ..= " " .. words[math.random(1, #words)]
		end
		local sent, why = pcall(liveOps.command, ana, line)
		if sent then
			worked += 1
		else
			t.check("an admin command line does not throw", false, `{line:sub(1, 60)} -> {tostring(why)}`)
			break
		end
	end
	t.equal("600 random command lines were all handled", worked, 600)

	-- nothing is broken afterwards
	local state = session.get(ana)
	t.check("coins are still a sane number", finite(state.coins) and state.coins >= 0, tostring(state.coins))
	t.check("Meme Points are still sane", finite(state.mp) and state.mp >= 0)
	t.check("the base is still the right size", state.base.size >= 6 and state.base.size <= 12)
	t.check(
		"the player cannot have been given an unreasonable amount of coins by a bad command",
		state.coins < 1e13,
		tostring(state.coins)
	)
	local luck, income = session.passMultipliers(ana)
	t.check("pass multipliers are sane", finite(luck) and finite(income) and luck >= 1 and income >= 1)
	t.check(
		"the live event multipliers are sane",
		finite(liveOps.luck()) and finite(liveOps.income()) and liveOps.luck() >= 1 and liveOps.income() >= 1
	)
	t.check("the belt rate is sane", liveOps.beltRate() >= 1)
	world.advance(5)
	t.check("the world still ticks after all of it", finite(ana:GetAttribute("Coins")))

	-- prompts fired by someone who is not even nearby or has no base cannot break anything either
	local stranger = world.addPlayer("Stranger", 702)
	world.advance(0.6)
	local count = 0
	for _, inst in world.workspace:GetDescendants() do
		if inst:IsA("ProximityPrompt") and count < 400 then
			count += 1
			local fine, problem = pcall(function()
				inst.Triggered:Fire(stranger)
			end)
			if not fine then
				t.check(
					"a prompt pressed by a stranger does not throw",
					false,
					`{inst.ActionText}: {tostring(problem)}`
				)
				break
			end
		end
	end
	t.check("a stranger pressing every prompt in the world is harmless", count > 50, tostring(count))
	local sstate = session.get(stranger)
	t.check("and their numbers are still sane", finite(sstate.coins) and sstate.coins >= 0)

	-- a corrupt or tampered save loads as sane numbers instead of poisoning the economy
	local bad = Fake.world()
	local garbage = {
		coins = 0 / 0,
		mp = -50,
		speedXp = math.huge,
		size = 999,
		savedAt = -math.huge,
		slots = {
			["1"] = { kind = "egg", tier = "Nope", hatchLeft = 0 / 0 },
			["2"] = { kind = "char", id = "NoSuchCharacter" },
			["3"] = { kind = "egg", tier = "Soggy", hatchLeft = -1e9 },
			["400"] = { kind = "char", id = "BonkBean" },
			["x"] = "junk",
		},
		passes = { coins2x = "yes", ghost = true },
		receipts = { 1, 2, "ok", {} },
		hatchTokens = 0 / 0,
		pendingLimited = { "Nope", 5, "GooseGold" },
		rebirths = 500,
		dailyLast = 0 / 0,
		dailyStreak = -9,
	}
	bad.service("DataStoreService").GetDataStore = function()
		return {
			GetAsync = function()
				return garbage
			end,
			UpdateAsync = function(_, _, fn)
				return fn(nil)
			end,
		}
	end
	local loaded, loadErr = pcall(bad.load, "src/server/main.server")
	t.check("the server starts with a corrupt save waiting", loaded, tostring(loadErr))
	local victim = bad.addPlayer("Corrupt", 801)
	bad.advance(1)
	local vs = bad.load("src/server/Session").get(victim)
	t.check("a NaN coin balance is replaced", finite(vs.coins) and vs.coins >= 0, tostring(vs.coins))
	t.check("negative Meme Points become zero", finite(vs.mp) and vs.mp >= 0, tostring(vs.mp))
	t.check("infinite speed XP does not survive", finite(vs.speedXp) and vs.speedXp >= 0, tostring(vs.speedXp))
	t.check("an absurd base size is clamped", vs.base.size >= 6 and vs.base.size <= 12, tostring(vs.base.size))
	t.check("rebirths are capped", vs.rebirths >= 0 and vs.rebirths <= 20, tostring(vs.rebirths))
	t.check("hatch tokens are sane", finite(vs.purchases.hatchTokens) and vs.purchases.hatchTokens >= 0)
	for slot, item in vs.base.slots do
		t.check(
			`slot {slot} holds something real`,
			slot >= 1 and slot <= vs.base.size and (item.kind == "egg" or item.kind == "char")
		)
		if item.kind == "egg" then
			t.check(
				"a loaded egg has a real timer",
				finite(item.hatchLeft) and (item.hatchLeft :: number) > 0,
				tostring(item.hatchLeft)
			)
		end
	end
	bad.advance(5)
	t.check(
		"the corrupt player's coins are still sane after the game ticks",
		finite(victim:GetAttribute("Coins")) and (victim:GetAttribute("Coins") :: number) >= 0
	)
end
