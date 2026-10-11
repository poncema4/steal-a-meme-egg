--!strict
-- Badges: the little awards on the experience page. The server hands one out the first time a player does the thing (Config.Badges
-- says which badge, its Roblox id and what earns it). A badge with no id yet is simply skipped, so the game never waits on one.
local BadgeService = game:GetService("BadgeService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Collection = require(ReplicatedStorage.Shared.Game.Collection)
local Zones = require(ReplicatedStorage.Shared.Game.Zones)
local Session = require(script.Parent.Session)
local Traps = require(script.Parent.Traps)
local Wilds = require(script.Parent.Wilds)

local Badges = {}

local given: { [Player]: { [string]: boolean } } = {}
local catalog: { [string]: { id: number, name: string, description: string } } = Config.Badges :: any

-- Tests (and nothing else) swap the catalogue so the badges have ids.
function Badges.setCatalog(c: { [string]: { id: number, name: string, description: string } })
	catalog = c
end

-- How a badge reaches Roblox. Tests replace this to see which badges were handed out.
local award: (Player, number) -> () = function(player: Player, id: number)
	pcall(function()
		BadgeService:AwardBadge(player.UserId, id)
	end)
end

function Badges.setAwarder(fn: (Player, number) -> ())
	award = fn
end

-- Gives the player this badge once per visit (Roblox itself never gives the same badge twice). Returns true if it was handed out now.
function Badges.give(player: Player, key: string): boolean
	local badge = catalog[key]
	if not badge or badge.id == 0 then
		return false
	end
	local mine = given[player]
	if not mine then
		mine = {}
		given[player] = mine
	end
	if (mine :: { [string]: boolean })[key] then
		return false
	end
	(mine :: { [string]: boolean })[key] = true
	task.spawn(award, player, badge.id)
	return true
end

-- The badges that depend on how far a player has got, checked whenever their numbers change.
local function checkProgress(player: Player)
	local speed = player:GetAttribute("SpeedStat")
	if typeof(speed) == "number" and speed >= Config.BadgeRules.SpeedDemon then
		Badges.give(player, "speedDemon")
	end
	local rebirths = player:GetAttribute("Rebirths")
	if typeof(rebirths) == "number" and rebirths >= 1 then
		Badges.give(player, "reborn")
	end
	local index = player:GetAttribute("Index")
	if typeof(index) == "string" and index ~= "" then
		local found = Collection.progress(Collection.decode(index))
		if found >= Config.BadgeRules.Collector then
			Badges.give(player, "collector")
		end
	end
end

function Badges.start()
	Session.onLoaded(function(player)
		Badges.give(player, "welcome")
	end)
	Session.onHatched(function(player)
		Badges.give(player, "firstHatch")
	end)
	Session.onDelivered(function(player, tier)
		Badges.give(player, "homeSafe")
		local home = Zones.forTier(tier)
		if home and table.find(Zones.List, home) :: number >= Config.BadgeRules.BossEscapeZone then
			Badges.give(player, "bossEscape")
		end
		if home and home.id == Zones.List[#Zones.List].id then
			Badges.give(player, "deepDiver")
		end
	end)
	Wilds.onStolen(function(player)
		Badges.give(player, "firstSteal")
	end)
	Traps.onSprung(function(player)
		Badges.give(player, "trapSpringer")
	end)
	-- speed and the Index move all the time without announcing it, so progress is checked every few seconds
	local since = 0
	RunService.Heartbeat:Connect(function(dt)
		since += dt
		if since < 3 then
			return
		end
		since = 0
		for _, player in Players:GetPlayers() do
			checkProgress(player)
		end
	end)
	Session.onChanged(checkProgress)
	Players.PlayerRemoving:Connect(function(player)
		given[player] = nil
	end)
end

return Badges
