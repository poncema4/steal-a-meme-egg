--!strict
-- The reasons to come back: the daily reward streak across real day boundaries, rebirth, and the player-list scores.
local Daily = require("../../src/shared/Game/Daily")
local Fake = require("../fake/Roblox")
local Rebirth = require("../../src/shared/Game/Rebirth")

return function(t)
	local world = Fake.world()
	local ok, err = pcall(world.load, "src/server/main.server")
	t.check("the server starts", ok, tostring(err))
	if not ok then
		return
	end
	local session = world.load("src/server/Session")
	local plots = world.load("src/server/Plots")
	local day1 = (Daily.reward(1, 0))

	-- the daily reward: first login pays day 1 and tells the player
	local ana = world.addPlayer("Ana", 81)
	world.advance(0.6)
	t.equal("a first login starts the streak at 1", ana:GetAttribute("DailyStreak"), 1)
	t.equal("and pays the day-1 reward on top of the starting coins", ana:GetAttribute("Coins"), 150 + day1)
	local told = false
	for _, entry in world.log do
		if
			entry.remote == "Notice"
			and entry.args[1] == ana
			and string.find(tostring(entry.args[2]), "Daily reward", 1, true)
		then
			told = true
		end
	end
	t.check("the player is told about it", told)

	-- same day: nothing more, and the coins survived the round trip through the save
	local coins = ana:GetAttribute("Coins") :: number
	world.removePlayer(ana)
	local again = world.addPlayer("Ana", 81)
	world.advance(0.6)
	t.equal("logging in again the same day pays nothing more", again:GetAttribute("DailyStreak"), 1)
	t.check("and the saved coins are still there", math.abs((again:GetAttribute("Coins") :: number) - coins) < 5)

	-- the next day: the streak grows
	world.removePlayer(again)
	world.advance(Daily.DAY, 600)
	local day2 = world.addPlayer("Ana", 81)
	world.advance(0.6)
	t.equal("the next day makes it 2", day2:GetAttribute("DailyStreak"), 2)
	t.check("and pays more", (day2:GetAttribute("Coins") :: number) >= coins + (Daily.reward(2, 0)))

	-- skipping days resets it
	world.removePlayer(day2)
	world.advance(Daily.DAY * 3, 3600)
	local late = world.addPlayer("Ana", 81)
	world.advance(0.6)
	t.equal("a missed day resets the streak to 1", late:GetAttribute("DailyStreak"), 1)

	-- the seventh day also gives an egg
	local state = session.get(late)
	state.dailyStreak = 6
	state.dailyLast = Daily.dayOf(world.workspace:GetServerTimeNow()) - 1
	for n = 1, state.base.size do
		state.base.slots[n] = nil
	end
	t.check("a streak that is still alive can be claimed", session.claimDaily(late))
	t.equal("and is now day 7", late:GetAttribute("DailyStreak"), 7)
	local gotEgg = false
	for n = 1, state.base.size do
		local item = state.base.slots[n]
		if item and item.kind == "egg" and item.tier == "Disco" then
			gotEgg = true
		end
	end
	t.check("day 7 puts a free egg in the base", gotEgg)
	t.check("claiming twice in a day is refused", not session.claimDaily(late))

	-- the leaderboard shows Meme Points and Rebirths next to the name
	session.addPoints(late, 12)
	local board = late:FindFirstChild("leaderstats") :: Instance
	t.check("a player has the scoreboard folder", board ~= nil)
	t.equal("with their Meme Points", (board:FindFirstChild("Meme Pts") :: IntValue).Value, 12)
	t.equal("and their Rebirths", (board:FindFirstChild("Rebirths") :: IntValue).Value, 0)

	-- rebirth
	local cost = Rebirth.cost(0)
	local plot = plots.of(late)
	state.base.slots[1] = { kind = "char", id = "BonkBean", mutation = "Normal" }
	state.coins = cost - 1
	session.changed(late)
	local income = late:GetAttribute("Income") :: number
	local pad = world.prompts(plot.model, "Rebirth")
	t.equal("every base has a rebirth pad", #pad, 1)
	pad[1].Triggered:Fire(late)
	t.equal("without the coins nothing happens", late:GetAttribute("Rebirths"), 0)
	state.coins = cost
	local other = world.addPlayer("Ben", 82)
	world.advance(0.6)
	pad[1].Triggered:Fire(other)
	t.equal("nobody else can use your pad", late:GetAttribute("Rebirths"), 0)
	session.setCarry(late, "Soggy", "Nest_Meadow_1")
	pad[1].Triggered:Fire(late)
	t.equal("you cannot rebirth while carrying an egg", late:GetAttribute("Rebirths"), 0)
	session.setCarry(late, nil)
	pad[1].Triggered:Fire(late)
	t.equal("with the coins it works", late:GetAttribute("Rebirths"), 1)
	t.equal("coins go back to the start", late:GetAttribute("Coins"), 150)
	t.equal("the base is empty again", late:GetAttribute("Characters"), 0)
	t.equal("Meme Points are kept", late:GetAttribute("MemePoints"), 12)
	t.equal("the scoreboard shows the rebirth", (board:FindFirstChild("Rebirths") :: IntValue).Value, 1)
	state.base.slots[1] = { kind = "char", id = "BonkBean", mutation = "Normal" }
	session.changed(late)
	t.equal("income is boosted by 50%", late:GetAttribute("Income"), income * Rebirth.multiplier(1))
	t.equal("the next rebirth costs more", late:GetAttribute("RebirthCost"), Rebirth.cost(1))

	-- a rebirth, a treadmill upgrade and the Index survive leaving and coming back
	session.get(late).treadmill = 3
	session.get(late).base.slots[2] = { kind = "char", id = "SleepySock", mutation = "Rainbow" }
	session.changed(late)
	session.get(late).base.slots[2] = nil -- seen once, then gone: the Index must still remember it
	session.changed(late)
	session.changed(late)
	world.removePlayer(late)
	local back = world.addPlayer("Ana", 81)
	world.advance(0.6)
	t.equal("rebirths are saved", back:GetAttribute("Rebirths"), 1)
	t.equal("the treadmill upgrade is saved", back:GetAttribute("TreadmillLevel"), 3)
	local savedIndex = tostring(back:GetAttribute("Index"))
	t.check(
		"the Index remembers a character that is gone from the base",
		string.find(savedIndex, "SleepySock:Rainbow", 1, true) ~= nil,
		savedIndex
	)
	t.check("even after a rebirth wiped the base", string.find(savedIndex, "BonkBean", 1, true) ~= nil)
	t.equal("and so is the income bonus", back:GetAttribute("Income"), income * Rebirth.multiplier(1))
end
