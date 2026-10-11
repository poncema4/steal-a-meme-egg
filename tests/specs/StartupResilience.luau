--!strict
-- The server must finish starting even when a Roblox service never answers (it happened in Studio: a stuck MessagingService made
-- the server stop before it created the Buy remote, so the client's shop, and with it the whole HUD, waited forever).
local task = require("@lune/task")
local Fake = require("../fake/Roblox")

local REMOTES = { "Buy", "BuyLimited", "SlowMode", "Drop", "PlaceTrap", "LeaveTreadmill", "Sfx" }

return function(t)
	local world = Fake.world()
	-- a messaging service that never replies: the call yields and nothing ever resumes it
	world.service("MessagingService").SubscribeAsync = function()
		coroutine.yield()
	end
	-- the server runs on its own Lune thread: if it hangs on the messaging call it simply never finishes
	local co = task.spawn(function()
		world.load("src/server/main.server")
	end)
	for _ = 1, 100 do
		if coroutine.status(co) == "dead" then
			break
		end
		task.wait(0.02)
	end
	local remotes = world.service("ReplicatedStorage"):FindFirstChild("Remotes")
	t.check("the remotes folder exists", remotes ~= nil)
	if not remotes then
		return
	end
	for _, name in REMOTES do
		t.check(`the {name} remote exists even though messaging never answered`, remotes:FindFirstChild(name) ~= nil)
	end
	t.equal("the server script ran to its end", coroutine.status(co), "dead")
end
