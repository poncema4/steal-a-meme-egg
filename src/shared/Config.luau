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
		ChaseSeconds = 40, -- a boss gives up after this long (enough to chase a thief from the deepest terrain all the way back)
		CatchRadius = 4.5, -- studs: close enough to take the egg back
		Leash = 1500, -- studs from its nest before it gives up: longer than the whole map, so a boss follows you through every terrain
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
	-- HUD icons (art/blender/icons.py), uploaded to the studio group. These are the IMAGE ids behind the uploaded decals: an ImageLabel
	-- draws nothing from a Decal id (that was the blank 2D art). A missing icon falls back to a glyph.
	Icons = table.freeze({
		egg = "rbxassetid://110547279413560",
		paw = "rbxassetid://121001547126743",
		trophy = "rbxassetid://91111671267228",
		shoe = "rbxassetid://70704749436741",
		cash = "rbxassetid://129678275199466",
		cart = "rbxassetid://133314915023675",
		book = "rbxassetid://90086215685737",
		potion = "rbxassetid://139436806491139",
		trap = "rbxassetid://71968910053970",
	}),
	-- character portraits (art/blender/pets.py), one decal each; a character without one shows a coloured letter tile
	PetIcons = table.freeze({
		SoggyToast = "rbxassetid://132591899723134",
		BonkBean = "rbxassetid://73279292853937",
		SleepySock = "rbxassetid://73667216189558",
		DiscoPickle = "rbxassetid://137272521031555",
		GigachadGoose = "rbxassetid://112737686849112",
		MoonwalkMoth = "rbxassetid://108666671744307",
		ChiliChihuahua = "rbxassetid://140404503491444",
		LavaLatte = "rbxassetid://84729703544839",
		VolcanoVicar = "rbxassetid://117055184477853",
		PharaohPancake = "rbxassetid://117066958565574",
		SphinxSneaker = "rbxassetid://132287761494589",
		CleoCroissant = "rbxassetid://75588493596559",
		NebulaNoodle = "rbxassetid://114449036509424",
		QuasarQuokka = "rbxassetid://121468505842324",
		BlackHoleBagel = "rbxassetid://73728144988466",
		TaxAngel = "rbxassetid://96696153650365",
		FinalBossHamster = "rbxassetid://134048138818749",
		OmegaMeme = "rbxassetid://79607471364855",
		GoldenGoose = "rbxassetid://129470914352155",
		PlatinumGoose = "rbxassetid://118505484359325",
		MythicGoose = "rbxassetid://107377119274238",
		CosmicKitten = "rbxassetid://140210632555594",
		NebulaCat = "rbxassetid://132130020464725",
		GalaxyTiger = "rbxassetid://117185310790150",
		MemeLordJr = "rbxassetid://86542685322694",
		MemeLordPrime = "rbxassetid://91260843157866",
		MemeLordOmega = "rbxassetid://90200570380531",
	}),
	Save = table.freeze({
		StoreName = "StealAMemeEgg_v1",
		AutosaveSeconds = 60,
	}),
	Server = table.freeze({
		MaxPlayers = 8,
	}),
})
