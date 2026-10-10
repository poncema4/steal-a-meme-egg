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
	-- Robux items (created in Creator Hub for experience 10770101743; prices are set there and match `robux`). An id of 0 means the
	-- item does not exist yet, and nothing with id 0 is ever offered or prompted.
	Monetization = table.freeze({
		Passes = table.freeze({
			coins2x = table.freeze({
				id = 2026694498,
				name = "2x Coins",
				blurb = "Your meme characters earn double, forever.",
				robux = 399,
				effect = "income",
				factor = 2,
			}),
			luck2x = table.freeze({
				id = 2026622537,
				name = "2x Luck",
				blurb = "Better odds on every hatch, forever.",
				robux = 299,
				effect = "luck",
				factor = 2,
			}),
			train2x = table.freeze({
				id = 2025116507,
				name = "2x Training",
				blurb = "The treadmill trains you twice as fast.",
				robux = 199,
				effect = "train",
				factor = 2,
			}),
		}),
		Products = table.freeze({
			hatch1 = table.freeze({ id = 3717784767, name = "Instant Hatch", robux = 25, kind = "hatch", amount = 1 }),
			hatch5 = table.freeze({
				id = 3717784806,
				name = "5 Instant Hatches",
				robux = 99,
				kind = "hatch",
				amount = 5,
			}),
			limitedGoose = table.freeze({
				id = 3717784827,
				name = "Golden Goose Egg",
				robux = 199,
				kind = "limited",
				amount = 1,
				tier = "GooseGold",
			}),
			limitedCat = table.freeze({
				id = 3717784864,
				name = "Cosmic Cat Egg",
				robux = 199,
				kind = "limited",
				amount = 1,
				tier = "CatCosmic",
			}),
			limitedLord = table.freeze({
				id = 3717784893,
				name = "Meme Lord Egg",
				robux = 199,
				kind = "limited",
				amount = 1,
				tier = "MemeLord",
			}),
		}),
	}),
	-- Licensed audio from the Roblox Creator Store (free for any experience): Distrokid loops for the music, short community
	-- effects picked from the trending lists. `music` plays in the Safe Zone, `musicWilds` out in the terrains.
	Sounds = table.freeze({
		hatch = "rbxassetid://126409451844008", -- egg crack 2
		steal = "rbxassetid://138890894929151", -- Whoosh2
		roar = "rbxassetid://131916027000817", -- Boing
		caught = "rbxassetid://108601872025792", -- Fail
		deliver = "rbxassetid://136993031050456", -- SuccessSfx
		coin = "rbxassetid://135483737426662", -- Coin Collect
		horn = "rbxassetid://112485797063762", -- UI Level Up
		limited = "rbxassetid://134821092416328", -- Rewards Level Up Next Tier
		click = "rbxassetid://88442833509532", -- ui simple button click
		music = "rbxassetid://139242395374944", -- Playground Adventure (Distrokid)
		musicWilds = "rbxassetid://135549334341493", -- Obby Rush BGM (Distrokid)
	}),
	-- HUD icons (art/blender/icons.py, uploaded as decals to the studio group). A missing icon falls back to an emoji.
	Icons = table.freeze({
		egg = "rbxassetid://104717160451898",
		paw = "rbxassetid://93563946436036",
		trophy = "rbxassetid://116011940435741",
		shoe = "rbxassetid://95694304794409",
		cash = "rbxassetid://112346576423757",
		cart = "rbxassetid://89391297052756",
		book = "rbxassetid://137262363418536",
		potion = "rbxassetid://77914679765922",
		trap = "rbxassetid://119912792349429",
	}),
	-- character portraits (art/blender/pets.py), one decal each; a character without one shows a coloured letter tile
	PetIcons = table.freeze({
		SoggyToast = "rbxassetid://101512084032061",
		BonkBean = "rbxassetid://106724049620779",
		SleepySock = "rbxassetid://95106084936080",
		DiscoPickle = "rbxassetid://133963308488384",
		GigachadGoose = "rbxassetid://122620992855612",
		MoonwalkMoth = "rbxassetid://130933040436007",
		ChiliChihuahua = "rbxassetid://100176983090312",
		LavaLatte = "rbxassetid://123772798267857",
		VolcanoVicar = "rbxassetid://115048766241778",
		PharaohPancake = "rbxassetid://136021186358887",
		SphinxSneaker = "rbxassetid://109625356589026",
		CleoCroissant = "rbxassetid://83494331918823",
		NebulaNoodle = "rbxassetid://140654683474046",
		QuasarQuokka = "rbxassetid://116735144500563",
		BlackHoleBagel = "rbxassetid://136019749192167",
		TaxAngel = "rbxassetid://85886475637784",
		FinalBossHamster = "rbxassetid://120492090199165",
		OmegaMeme = "rbxassetid://93283741226509",
		GoldenGoose = "rbxassetid://120294861121785",
		PlatinumGoose = "rbxassetid://124489907816619",
		MythicGoose = "rbxassetid://76834101232125",
		CosmicKitten = "rbxassetid://133559588203933",
		NebulaCat = "rbxassetid://107048640464428",
		GalaxyTiger = "rbxassetid://114130296585341",
		MemeLordJr = "rbxassetid://117920400287170",
		MemeLordPrime = "rbxassetid://94382542186792",
		MemeLordOmega = "rbxassetid://129979641210267",
	}),
	Save = table.freeze({
		StoreName = "StealAMemeEgg_v1",
		AutosaveSeconds = 60,
	}),
	Server = table.freeze({
		MaxPlayers = 8,
	}),
})
