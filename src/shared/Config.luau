--!strict
-- Every tunable number lives here. Logic in Shared/Game reads these through its callers, never hard-codes them.
return table.freeze({
	GameName = "Steal a Meme Egg",
	Version = "0.1.0",
	GroupId = 749648777, -- Nexus Hollow Studios: group owner and high ranks are admins (no user ids to maintain)
	Economy = table.freeze({
		StartCoins = 150,
		StartSlots = 6,
		MaxSlots = 12,
		SlotCostBase = 1000, -- the next slot costs SlotCostBase * 4^(slots - StartSlots)
		OfflineCapSeconds = 2 * 60 * 60, -- coming back after a long time pays at most this many seconds of income
	}),
	Conveyor = table.freeze({
		SpawnSeconds = 2.5, -- a new egg rides the belt this often
		TravelSeconds = 18, -- how long an egg takes to cross the belt
		MaxEggs = 14,
	}),
	Steal = table.freeze({
		HoldSeconds = 1.5, -- hold E on a character in someone's base to take it
		LockSeconds = 45, -- a base lock lasts this long...
		LockCooldownSeconds = 90, -- ...and cannot be used again for this long after it started
		Reach = 14, -- studs
	}),
	-- The Wilds: guarded eggs out in themed terrains (see Shared/Game/Zones, Guardian, Nest, Progression).
	Wilds = table.freeze({
		ChaseSeconds = 12, -- a guardian gives up after this long
		CatchRadius = 4.5, -- studs: close enough to take the egg back
		Leash = 150, -- studs from its nest before it gives up
		NestRespawnSeconds = 25, -- a stolen nest grows a new egg after this
		StealHoldSeconds = 1.5,
		GatePushSeconds = 0.5, -- how often the server checks that nobody is somewhere they have not unlocked
	}),
	Admin = table.freeze({
		MinGroupRank = 250, -- the owner is 255
		UserIds = table.freeze({} :: { number }), -- extra admins by user id
	}),
	Events = table.freeze({
		PeriodSeconds = 30 * 60, -- the schedule repeats every half hour
		ClaimSeconds = 5 * 60, -- ...and each scheduled event runs this long
	}),
	Save = table.freeze({
		StoreName = "StealAMemeEgg_v1",
		AutosaveSeconds = 60,
	}),
	Server = table.freeze({
		MaxPlayers = 12,
	}),
})
