--!strict
local Admin = require("../../src/shared/Game/Admin")

return function(t)
	t.check("the group owner is an admin", Admin.isAdmin(5, 255, 250, {}))
	t.check("a high rank is an admin", Admin.isAdmin(5, 250, 250, {}))
	t.check("a normal member is not", not Admin.isAdmin(5, 1, 250, {}))
	t.check("a non-member is not", not Admin.isAdmin(5, 0, 250, {}))
	t.check("a listed user id is", Admin.isAdmin(5, 0, 250, { 5 }))

	local denied = Admin.run("/give 1000", false)
	t.check("a non-admin cannot run anything", not denied.ok and denied.action == nil)
	t.check("normal chat is not a command", not Admin.run("hello", true).ok)

	local ev = Admin.run("/event luckyhour 120", true)
	t.check("/event starts an event", ev.ok and ev.action ~= nil and ev.action.kind == "event")
	t.equal("the id is normalised", (ev.action :: any).id, "LuckyHour")
	t.equal("with the given seconds", (ev.action :: any).seconds, 120)
	t.equal("spaces and case do not matter", (Admin.run("/EVENT Lucky_Hour", true).action :: any).id, "LuckyHour")
	t.check("an unknown event is refused", not Admin.run("/event meteor", true).ok)
	t.check("an absurd length is refused", not Admin.run("/event luckyhour 999999", true).ok)
	t.check("a zero length is refused", not Admin.run("/event luckyhour 0", true).ok)

	local give = Admin.run("/give 5000", true)
	t.check("/give gives coins", give.ok and (give.action :: any).kind == "give" and (give.action :: any).coins == 5000)
	t.equal("/giveall is a giveaway", (Admin.run("/giveall 100", true).action :: any).kind, "giveAll")
	t.check("a negative amount is refused", not Admin.run("/give -5", true).ok)
	t.check("a huge amount is refused", not Admin.run("/give 1e15", true).ok)
	t.check("a non-number is refused", not Admin.run("/give lots", true).ok)
	t.equal("a fraction is floored", (Admin.run("/give 10.9", true).action :: any).coins, 10)

	local say = Admin.run("/announce Egg Rain in 1 minute!", true)
	t.equal("/announce keeps the whole text", (say.action :: any).text, "Egg Rain in 1 minute!")
	t.check("an empty announce is refused", not Admin.run("/announce", true).ok)
	t.check("a very long announce is refused", not Admin.run("/announce " .. string.rep("x", 200), true).ok)
	t.equal("/clear stops events", (Admin.run("/clear", true).action :: any).kind, "clearEvents")
	t.equal("/help answers", (Admin.run("/help", true).action :: any).kind, "help")
	t.check("an unknown command is refused", not Admin.run("/nuke", true).ok)
end
