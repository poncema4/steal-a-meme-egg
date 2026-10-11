--!strict
-- Admin commands, typed in chat ("/event luckyhour 300"). This module only decides WHO may run a command and WHAT it
-- means; the server applies the returned action. Keeping it pure means the permission rule is tested, not trusted.
local Events = require("./Events")

local Admin = {}

export type Action =
	{ kind: "event", id: string, seconds: number? }
	| { kind: "give", coins: number }
	| { kind: "giveAll", coins: number }
	| { kind: "announce", text: string }
	| { kind: "clearEvents" }
	| { kind: "resetMe" }
	| { kind: "help" }
export type Result = { ok: boolean, message: string, action: Action? }

Admin.MaxGive = 1e12
Admin.MaxEventSeconds = 3600

-- Is this player an admin? `rank` is their rank in the studio group (0 if not a member).
function Admin.isAdmin(userId: number, rank: number, minRank: number, userIds: { number }): boolean
	return rank >= minRank or table.find(userIds, userId) ~= nil
end

local function words(text: string): { string }
	local list = {}
	for word in string.gmatch(text, "%S+") do
		table.insert(list, word)
	end
	return list
end

-- Maps "luckyhour" / "Lucky Hour" / "lucky_hour" to an event id.
local function findEvent(name: string): string?
	local want = string.lower((string.gsub(name, "[%s_%-]", "")))
	for id in Events.Defs do
		if string.lower(id) == want then
			return id
		end
	end
	return nil
end

function Admin.run(text: string, isAdmin: boolean): Result
	if string.sub(text, 1, 1) ~= "/" then
		return { ok = false, message = "not a command" }
	end
	if not isAdmin then
		return { ok = false, message = "you are not an admin" }
	end
	local w = words(string.sub(text, 2))
	local name = string.lower(w[1] or "")
	if name == "event" then
		local id = findEvent(w[2] or "")
		if not id then
			return { ok = false, message = "unknown event; try /help" }
		end
		local seconds = tonumber(w[3])
		-- written as "must be inside the range" so NaN (tonumber accepts "nan") fails every comparison and is refused
		if seconds and not (seconds > 0 and seconds <= Admin.MaxEventSeconds) then
			return { ok = false, message = `seconds must be 1 to {Admin.MaxEventSeconds}` }
		end
		return {
			ok = true,
			message = `starting {Events.Defs[id].name}`,
			action = { kind = "event", id = id, seconds = seconds },
		}
	elseif name == "give" or name == "giveall" then
		local coins = tonumber(w[2])
		if not coins or not (coins > 0 and coins <= Admin.MaxGive) then
			return { ok = false, message = "usage: /" .. name .. " <coins>" }
		end
		coins = math.floor(coins)
		local kind = if name == "give" then "give" else "giveAll"
		return { ok = true, message = `{kind} {coins}`, action = { kind = kind, coins = coins } :: any }
	elseif name == "announce" then
		local body = string.match(text, "^/%S+%s+(.+)$")
		if not body or #body > 120 then
			return { ok = false, message = "usage: /announce <text up to 120 characters>" }
		end
		return { ok = true, message = "announcing", action = { kind = "announce", text = body } }
	elseif name == "resetme" then
		-- starts the caller over (speed, treadmill, rebirths, coins, base, Index); purchases are kept. It only ever touches whoever typed it.
		return { ok = true, message = "resetting YOUR progress to the start", action = { kind = "resetMe" } }
	elseif name == "clear" then
		return { ok = true, message = "events cleared", action = { kind = "clearEvents" } }
	elseif name == "help" then
		return {
			ok = true,
			message = "/event <name> [seconds], /give <coins>, /giveall <coins>, /announce <text>, /clear, /resetme (only you)",
			action = { kind = "help" },
		}
	end
	return { ok = false, message = "unknown command; try /help" }
end

return Admin
