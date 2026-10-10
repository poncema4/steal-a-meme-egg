--!strict
-- Stealing and locking. The rules (who can be raided, when) live in Shared/Game/Base; this file turns a prompt press
-- into those calls and tells both players what happened.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Base = require(ReplicatedStorage.Shared.Game.Base)
local Config = require(ReplicatedStorage.Shared.Config)
local Eggs = require(ReplicatedStorage.Shared.Game.Eggs)
local Session = require(script.Parent.Session)

local Raid = {}

local notify: (Player, string) -> () = function(_player: Player, _text: string) end

function Raid.setNotify(fn: (Player, string) -> ())
	notify = fn
end

function Raid.steal(thief: Player, owner: Player, slot: number)
	if thief == owner then
		return
	end
	local victim, mine = Session.get(owner), Session.get(thief)
	if not victim or not mine then
		return
	end
	local now = Session.now()
	local ok, result = Base.steal(victim.base, mine.base, slot, now)
	if not ok then
		local why = result :: string
		if why == "locked" then
			notify(thief, `{owner.DisplayName}'s base is locked!`)
		elseif why == "full" then
			notify(thief, "Your base is full!")
		end
		return
	end
	local item = mine.base.slots[result :: number]
	local c = item and Eggs.character(item.id or "")
	notify(thief, `You stole {if c then c.name else "a character"} from {owner.DisplayName}!`)
	notify(owner, `{thief.DisplayName} stole your {if c then c.name else "character"}!`)
	Session.changed(owner)
	Session.changed(thief)
end

function Raid.lock(player: Player)
	local state = Session.get(player)
	if not state then
		return
	end
	local ok, wait = Base.lock(state.base, Session.now(), Config.Steal.LockSeconds, Config.Steal.LockCooldownSeconds)
	if ok then
		notify(player, `Base locked for {Config.Steal.LockSeconds}s`)
		player:SetAttribute("LockedUntil", Session.now() + Config.Steal.LockSeconds)
	else
		notify(player, `Lock ready in {math.ceil(wait)}s`)
	end
end

return Raid
