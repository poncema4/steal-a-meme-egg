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
	-- Robux items. Every id is 0 until the item is created in Creator Hub; nothing with id 0 is ever offered or prompted.
	Monetization = table.freeze({
		Passes = table.freeze({
			coins2x = table.freeze({
				id = 0,
				name = "2x Coins",
				blurb = "Your meme characters earn double, forever.",
				robux = 399,
				effect = "income",
				factor = 2,
			}),
			luck2x = table.freeze({
				id = 0,
				name = "2x Luck",
				blurb = "Better odds on every hatch, forever.",
				robux = 299,
				effect = "luck",
				factor = 2,
			}),
			train2x = table.freeze({
				id = 0,
				name = "2x Training",
				blurb = "The treadmill trains you twice as fast.",
				robux = 199,
				effect = "train",
				factor = 2,
			}),
		}),
		Products = table.freeze({
			hatch1 = table.freeze({ id = 0, name = "Instant Hatch", robux = 25, kind = "hatch", amount = 1 }),
			hatch5 = table.freeze({ id = 0, name = "5 Instant Hatches", robux = 99, kind = "hatch", amount = 5 }),
			limitedGoose = table.freeze({
				id = 0,
				name = "Golden Goose Egg",
				robux = 199,
				kind = "limited",
				amount = 1,
				tier = "GooseGold",
			}),
			limitedCat = table.freeze({
				id = 0,
				name = "Cosmic Cat Egg",
				robux = 199,
				kind = "limited",
				amount = 1,
				tier = "CatCosmic",
			}),
			limitedLord = table.freeze({
				id = 0,
				name = "Meme Lord Egg",
				robux = 199,
				kind = "limited",
				amount = 1,
				tier = "MemeLord",
			}),
		}),
	}),
	-- Our own synthesised sounds (scripts/audio/make_game_sfx.py), uploaded to the Nexus Hollow Studios audio library.
	Sounds = table.freeze({
		hatch = "rbxassetid://79876660142856",
		steal = "rbxassetid://102219946348103",
		roar = "rbxassetid://124311047029123",
		caught = "rbxassetid://115820906972723",
		deliver = "rbxassetid://109009369699894",
		coin = "rbxassetid://121693957394972",
		horn = "rbxassetid://83883870627410",
		limited = "rbxassetid://125238903514063",
		click = "rbxassetid://117766235870284",
		music = "rbxassetid://77664441261326",
	}),
	Save = table.freeze({
		StoreName = "StealAMemeEgg_v1",
		AutosaveSeconds = 60,
	}),
	Server = table.freeze({
		MaxPlayers = 12,
	}),
})
