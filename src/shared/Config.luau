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
	-- Badges on the experience page. A badge with id 0 has not been created on Roblox yet and is skipped. The art is in art/ui/make_badges.py.
	Badges = table.freeze({
		welcome = table.freeze({
			id = 3384399178322110,
			name = "Welcome to the Wilds",
			description = "Joined Steal a Meme Egg.",
		}),
		firstSteal = table.freeze({
			id = 3863015721156614,
			name = "Egg Thief",
			description = "Stole your first egg from a meme boss.",
		}),
		firstHatch = table.freeze({
			id = 2363721362972337,
			name = "Crack!",
			description = "Hatched your first meme character.",
		}),
		homeSafe = table.freeze({
			id = 392480807481606,
			name = "Home Safe",
			description = "Ran a stolen egg all the way home.",
		}),
		speedDemon = table.freeze({
			id = 2688228397962935,
			name = "Speed Demon",
			description = "Reached a speed of 100,000.",
		}),
		reborn = table.freeze({ id = 1420399396852850, name = "Reborn", description = "Rebirthed for the first time." }),
		collector = table.freeze({
			id = 3070658632390701,
			name = "Meme Collector",
			description = "Discovered 10 meme characters in the Index.",
		}),
		bossEscape = table.freeze({
			id = 1111059166219026,
			name = "Boss Escape",
			description = "Brought home an egg from Lava Lands or deeper.",
		}),
		deepDiver = table.freeze({
			id = 1934365254932598,
			name = "Sky High",
			description = "Brought home an egg from the Sky Kingdom.",
		}),
		trapSpringer = table.freeze({
			id = 94641520571964,
			name = "Gotcha!",
			description = "Caught a meme boss in one of your traps.",
		}),
	}),
	BadgeRules = table.freeze({
		SpeedDemon = 100000, -- the Speed number that earns Speed Demon
		Collector = 10, -- characters discovered
		BossEscapeZone = 3, -- the terrain number (1 = Meadow) an egg must come from
	}),
	-- The Wilds: guarded eggs out in themed terrains (see Shared/Game/Zones, Guardian, Nest, Progression).
	Wilds = table.freeze({
		ChaseSeconds = 60, -- a boss gives up after this long (enough to chase a thief from the deepest terrain all the way back)
		CatchRadius = 4.5, -- studs: close enough to take the egg back
		Leash = 4500, -- studs from its nest before it gives up: longer than the whole map, so a boss follows you through every terrain
		NestRespawnSeconds = 25, -- a stolen nest grows a new egg after this
		StealHoldSeconds = 1.5,
		ZoneLabelSeconds = 0.5, -- how often the server updates which terrain each player is in (the HUD's zone banner)
	}),
	-- Finishing a world's Index pays this many of that world's common egg, and unlocks the next bat.
	Index = table.freeze({ RewardEggs = 25 }),
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
			fastHatch = table.freeze({
				id = 2026820930,
				name = "2x Hatch Speed",
				blurb = "Every egg in your pen hatches twice as fast, forever.",
				robux = 249,
				effect = "hatch",
				factor = 2,
			}),
			vip = table.freeze({
				id = 2025434937,
				name = "VIP",
				blurb = "25% more coins from every meme, forever.",
				robux = 349,
				effect = "income",
				factor = 1.25,
			}),
			trapMaster = table.freeze({
				id = 2025446938,
				name = "Trap Master",
				blurb = "Set 6 traps at once, and set the next one twice as fast.",
				robux = 149,
				effect = "traps",
				factor = 6,
			}),
			bossSlow = table.freeze({
				id = 2027030902,
				name = "Slow Bosses",
				blurb = "Meme bosses chase you 25% slower, forever.",
				robux = 299,
				effect = "bossSlow",
				factor = 1.25,
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
	-- HUD icons: sticker renders of the brick models (art/ui/make_all.sh), uploaded to the studio group. These are IMAGE ids (an ImageLabel draws
	-- nothing from a Decal id). A missing icon falls back to a glyph.
	-- HUD icons from Google's Noto Color Emoji art (Apache 2.0; art/ui/emoji_icons.py): glossy like Steal an Egg, the Shop cart and
	-- Index book as white silhouettes with a black outline like the reference. One Image id each.
	Icons = table.freeze({
		book = "rbxassetid://97952116811228",
		cart = "rbxassetid://138284838244499",
		cash = "rbxassetid://86253579644854",
		clock = "rbxassetid://127413837879622",
		egg = "rbxassetid://100302718886608",
		paw = "rbxassetid://111724444278545",
		potion = "rbxassetid://115856427959528",
		shoe = "rbxassetid://80065126082671",
		trap = "rbxassetid://135157184755259",
		bat = "rbxassetid://96955999977109",
		trophy = "rbxassetid://93248775215980",
	}),
	-- character portraits: a sticker render of each character's brick model (art/ui/make_all.sh), one Image id each; a character without one shows a letter tile
	PetIcons = table.freeze({
		BlackHoleBagel = "rbxassetid://109535728537463",
		BogBurrito = "rbxassetid://97239361906109",
		BonkBean = "rbxassetid://76107615589567",
		BooBanana = "rbxassetid://77469714549583",
		ChiliChihuahua = "rbxassetid://136233475585517",
		CleoCroissant = "rbxassetid://79925363872043",
		CosmicKitten = "rbxassetid://140583797641449",
		DiscoPickle = "rbxassetid://89479740304770",
		FinalBossHamster = "rbxassetid://122930338984913",
		GalaxyTiger = "rbxassetid://97261490086399",
		GigachadGoose = "rbxassetid://78185692981846",
		GloopGoblin = "rbxassetid://91454828893755",
		GoldenGoose = "rbxassetid://81442985107411",
		GummyGolem = "rbxassetid://119682376922119",
		LavaLatte = "rbxassetid://135091094413506",
		LichLasagna = "rbxassetid://107334865687373",
		MemeLordJr = "rbxassetid://90326403312078",
		MemeLordOmega = "rbxassetid://82584811887152",
		MemeLordPrime = "rbxassetid://119252737152375",
		MoonwalkMoth = "rbxassetid://123805092594753",
		MummyMuffin = "rbxassetid://105865448558411",
		MythicGoose = "rbxassetid://71769692485935",
		NebulaCat = "rbxassetid://106465818062461",
		NebulaNoodle = "rbxassetid://133137279625584",
		NimbusNugget = "rbxassetid://102670400953584",
		OmegaMeme = "rbxassetid://107959741188853",
		PharaohPancake = "rbxassetid://82652518074278",
		PixelPigeon = "rbxassetid://113180419509064",
		PlatinumGoose = "rbxassetid://74612535899809",
		QuasarQuokka = "rbxassetid://125684152371581",
		SleepySock = "rbxassetid://135277176295602",
		SoggyToast = "rbxassetid://94136816007417",
		SphinxSneaker = "rbxassetid://140578425195106",
		SprinkleSloth = "rbxassetid://98511686861373",
		StormSandwich = "rbxassetid://140598315600037",
		SwampSensei = "rbxassetid://136216114978340",
		SynthSquid = "rbxassetid://93650468411429",
		TaffyTitan = "rbxassetid://128900509948689",
		TaxAngel = "rbxassetid://95867865886570",
		VaporVulture = "rbxassetid://101615996677197",
		VolcanoVicar = "rbxassetid://76040536489956",
		ZeusZucchini = "rbxassetid://123182217096686",
		BrickBuddy = "rbxassetid://77004614276752",
		WobblyWindup = "rbxassetid://119952426768063",
		RubberDuckLord = "rbxassetid://137585351693708",
		CaptainCrouton = "rbxassetid://83467608410008",
		KrakenKebab = "rbxassetid://95899730095630",
		DavyJonesDonut = "rbxassetid://108940594180876",
		ToasterTron = "rbxassetid://86227444263660",
		MicrowaveMike = "rbxassetid://135559393039119",
		OmniOven = "rbxassetid://106004376654266",
		BananaBandit = "rbxassetid://89711601881275",
		TikiTaco = "rbxassetid://120573546059116",
		TempleTofu = "rbxassetid://93788271500272",
		CrownCookie = "rbxassetid://115447098167831",
		RoyalRamen = "rbxassetid://88871242705215",
		EmperorEggplant = "rbxassetid://112593189665742",
	}),
	-- egg pictures, one per egg tier
	EggIcons = table.freeze({
		Candy = "rbxassetid://108133285737160",
		Cloud = "rbxassetid://70562203405648",
		Cosmic = "rbxassetid://93588422609404",
		Cursed = "rbxassetid://76561920676551",
		Disco = "rbxassetid://119166559650213",
		Divine = "rbxassetid://105882793891585",
		Golden = "rbxassetid://115734346216933",
		Neon = "rbxassetid://132674450141353",
		Slime = "rbxassetid://84356014695029",
		Soggy = "rbxassetid://92800554938569",
		Spicy = "rbxassetid://104423055775057",
		Toy = "rbxassetid://77494638421799",
		Pirate = "rbxassetid://78107776877089",
		Robot = "rbxassetid://132972271904835",
		Jungle = "rbxassetid://91022935794343",
		Throne = "rbxassetid://136063886269390",
	}),
	-- the picture on each shop card (and on its Creator Hub page): art/ui/make_passes.py
	-- the backpack items' pictures: real 3D renders like Steal an Egg's hotbar (art/items/render_items.py + compose.py). The trap
	-- shows how many you have left ("x3"), so it has one picture per count.
	ItemIcons = table.freeze({
		bat = "rbxassetid://72860451054073",
		trap = table.freeze({
			"rbxassetid://72887371170636",
			"rbxassetid://102113398108718",
			"rbxassetid://75022657488140",
			"rbxassetid://123929134723653",
			"rbxassetid://105735304661373",
			"rbxassetid://114475299313939",
		}),
	}),
	ShopArt = table.freeze({
		bossSlow = "rbxassetid://84756472712938",
		coins2x = "rbxassetid://132674884843989",
		fastHatch = "rbxassetid://102787296177824",
		hatch1 = "rbxassetid://130847694442489",
		hatch5 = "rbxassetid://87793078736493",
		limitedCat = "rbxassetid://87129330236782",
		limitedGoose = "rbxassetid://106312171531319",
		limitedLord = "rbxassetid://99730474500273",
		luck2x = "rbxassetid://82336471303566",
		train2x = "rbxassetid://75868109748157",
		trapMaster = "rbxassetid://77309875624031",
		vip = "rbxassetid://134476897212303",
	}),
	Save = table.freeze({
		StoreName = "StealAMemeEgg_v1",
		AutosaveSeconds = 60,
	}),
	Server = table.freeze({
		MaxPlayers = 8,
	}),
})
