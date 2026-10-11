# Design: Steal a Meme Egg

## One sentence
Steal eggs from meme guardians, run them home, hatch them into meme characters that earn coins. Players cannot steal from each other (trading may come later).

## Why this shape (research 2026-10-10, see the research notes in the studio folder)
- Steal-a-X loops are the biggest lane on Roblox (Steal An Egg 1.6M players). The loop beats the theme.
- Roblox ranks games by 28-day retention, so there is always a reason to come back: hatch timers, a collection, live events.
- Every rule fits in one TikTok clip.

## Loop
1. Eggs ride a belt. Press E on one to buy it (coins). It goes in your next free slot.
2. It hatches after a timer into a character (our own meme cast) with a rarity and sometimes a Gold (x2) / Rainbow (x5) mutation.
3. Characters earn coins per second, even offline (capped).
4. Hold E on a character in someone else's base to steal it. Lock your base (45 s, 90 s cooldown) to be safe.
5. Coins buy better eggs and more slots (up to 12).

## The Wilds (built)
One long walled corridor: the Safe Zone at the west end (eight fenced pens in a semicircle around a plaza (one per player; a server holds 8), a red line, a gateway sign over it reading SAFE ZONE), then a strip of themed terrains going east (x 10 to 1210): Meme Meadow, Dune Desert, Lava Lands, Frozen Peaks, Cosmic Void. Each has 5 nests; on every nest a meme guardian sits on an egg. Hold E on the egg to steal it. The terrain's boss chases you through every terrain on the way back (it gives up after 40 s, never enters the Safe Zone, and takes the egg back if it touches you and flings you back toward the Safe Zone like a rag doll). Carry the egg into your own base to start it hatching and earn Meme Points. If your base is full when you get home the egg is sold for half its price instead (you still get the Meme Points), so a full base never traps you. You carry one egg at a time and run 10% slower while carrying.

Gates: each terrain opens at a Speed level (0 / 5 / 10 / 16 / 23), chosen so you outrun that terrain's boss when you arrive; Meme Points never block anyone. The server pushes you back from a terrain you have not unlocked. Rarer terrains hold rarer eggs and faster guardians (12 / 20 / 30 / 42 / 56 studs per second). Speed is slow to build: the first level takes about 15 s on a new treadmill, and the top needs hundreds of thousands of training XP, so you upgrade the treadmill (it repaints from rusty to divine).

Speed cannot be bought: step onto the treadmill in front of your pen and you are LOCKED on it: the game runs for you (no keys to hold) and the belt carries you backward at your pace while you train. Jump (Space / gamepad A / the Jump off button) to get off; you cannot be locked again for about 1.6 s, carrying an egg or dying also takes you off. Your speed number and walking speed rise continuously while you train (not in steps at each level). It gives 2 XP per second at level 0 and 1.6x more per treadmill level (12 levels, 100 coins for the first upgrade, x3.2 each). Speed levels 0 to 30 raise walk speed from 16 to 43. The level you need to outrun a terrain while carrying: Meadow 0, Dune 4, Lava 9, Frost 14, Cosmic 18 (tested in `tests/specs/Zones`).

Meme Points per delivered egg: Soggy 1, Disco 5, Spicy 25, Golden 150, Cosmic 1,000, Divine 10,000.

There is no conveyor and no raiding: the Wilds are the only source of eggs (plus daily rewards and the shop).

## Hatching and limited eggs (built)
Eggs take real time to hatch (8 s up to 5 minutes by tier). Hatching can only be sped up with Robux (an Instant hatch, or a hatch token bought with them), never with coins. Pets are not tied to anything: each one walks around the whole pen (`Shared/Game/Wander`, `client/Roam`). The pen is clear (no platforms): an egg is put down wherever you stand when you deliver it (`Base.freeSpot`, nudged off other eggs, kept inside the fence).

Limited eggs: every 30 minutes one of three exclusive eggs (Golden Goose, Cosmic Cat, Meme Lord) goes on sale for 1,000,000,000 coins with a stock of 100 shared by every server (one MemoryStore counter per rotation; each server falls back to its own count if MemoryStore is unavailable). Limited characters earn 15M to 80M per second, more than anything in the Wilds, and pay their egg back in 20 to 120 seconds (tested). Robux purchase of the same eggs and Robux instant-hatch come with the monetization PR.

Next: game passes and Robux products, then the shop screen.

## Reasons to come back (built)
- **Rebirth** (purple pad at the left of your base, hold E): spend 2,000,000 coins (5x more each time, up to 20) to reset coins and your base for a permanent +50% income. Meme Points, speed and passes stay, so every terrain you opened stays open. You cannot rebirth while carrying an egg.
- **Daily reward**: log in on consecutive UTC days to grow a streak; coins scale with the day and with your income (at least a minute's worth), and day 7 adds a free Disco egg. A missed day resets it. It is paid automatically when you join.
- **Player list scores**: Meme Pts and Rebirths show beside every name (Roblox leaderstats).
- **Objective line**: the HUD always tells you the next step, including when a rebirth is affordable.

## Live ops (the reason people join)
- Schedule every half hour on every server: Lucky Hour (:00), Egg Rain (:10), Coin Rain (:20).
- Admin commands in chat (group owner/rank 250+; everyone in Studio): `/event <name> [seconds]`, `/give <coins>`, `/giveall <coins>`, `/announce <text>`, `/clear`, `/help`. Admin events go to EVERY server through MessagingService.
- Events: Lucky Hour (2x luck), Coin Rain (2x income), Egg Rain (belt 6x faster), Mega Luck (5x), Meme Frenzy (3x both).

## Where the rules live (all tested in `tests/specs`)
`Shared/Game/Eggs` (tables, hatch roll, conveyor odds), `Base` (slots, hatching, steal, lock), `Economy` (prices, offline, number format), `Events`, `Admin`.

## Next
The Wilds (above), game passes (2x coins, 2x luck, extra slot), Robux luck boosts, aura face-offs, rebirth, daily reward, invite prompt, thumbnails and TikTok plan (docs/GROWTH.md).

## Traps
Press 1, 2 or 3 (gamepad X, tap a hotbar slot) out in a terrain to put a trap down where you stand. At most 3 per player at once, 2 s between placements, they rot after 90 s. A guardian that is chasing (or heading home) and runs within 5 studs of a trap is held for 3.5 s; the trap is used up. Sleeping guardians do not spring them. Not in the Safe Zone. Rules: `Shared/Game/Trap`, `Guardian.stunned`; server: `src/server/Traps.luau`.

## Mutated eggs
A nest can grow a Gold or Rainbow egg (`Eggs.nestMutation`: Meadow about 8% Gold and 2% Rainbow, more in each deeper terrain, capped at 40% and 12%). The egg is Gold or Rainbow-coloured with a tag in the nest, keeps its mutation when stolen, carried, dropped and returned, and when delivered: Gold is worth double Meme Points (and sale price), Rainbow five times. In your base it hatches into a pet with that mutation (a Normal egg still rolls the usual chance at hatching). Saved with the base.

## Carrying
While you carry an egg it floats above your head (Gold and Rainbow ones are coloured and shine), a blue speed trail follows you, the HUD shows a RUN!! banner and a Drop button, and you run 10% slower. It follows the `Carrying` attribute (`src/server/Carry.luau`) so it also survives a respawn. Being caught flings you (`Wilds.fling`, tumbling 1.4 s); dropping the egg on purpose does not.

## Dropping an egg
The Drop button puts the egg on the ground exactly where you stand; anyone can hold E on it to pick it up again (its terrain's boss then chases them), and it goes back to its nest after 90 seconds if nobody does. Being caught by the boss sends it back to its nest at once. The nest does not grow a new egg while one lies on the ground.

## Admin
`/resetme` (admins only, only affects the person who typed it) puts you back at the start: speed, treadmill, rebirths, coins, Meme Points, base and Index. Robux purchases are kept.

## Speed has no ceiling, and ten worlds
- **Speed** is a number that never stops growing: each level multiplies it by 1.22 (1,600 at the start, then thousands, millions, B, T, Qa...). A level takes `30 * (level+1)^2 * 1.12^level` training XP, so every level is a bigger effort than the last; each treadmill upgrade triples the training rate (12 upgrades, each with its own look). How fast your character REALLY runs is separate: it climbs from 16 and settles toward 88 studs a second (a body cannot run a billion studs a second).
- **Worlds:** Meadow, Dune, Lava Lands, Frozen Peaks, Cosmic Void, Slime Swamp, Candy Canyon, Neon City, Haunted Hollow, Sky Kingdom. Nothing blocks anyone: two signposts at each entrance say the recommended speed (about the level where you can outrun that boss while carrying an egg). Bosses go from 12 to 76 studs a second. A boss chases a thief through every terrain back to the Safe Zone (it never enters it).
- **Eggs and characters:** eleven egg tiers (Soggy ... Divine, then Slime, Candy, Neon, Cursed, Cloud) and 42 standard characters, grouped by world in the Index. Meme Points are just a number; they open nothing.

## Passes, products and badges
- Passes: 2x Coins, 2x Luck, 2x Training, 2x Hatch Speed, VIP (+25% coins), Trap Master (6 traps, half the wait), Slow Bosses (bosses chase 25% slower). Developer products: Instant Hatch (1, 5) and the three limited eggs. Pass pictures are made by `art/ui/make_passes.py` with a safe margin so nothing is cut off.
- Badges (`Config.Badges`, `server/Badges.luau`): Welcome, Egg Thief, Crack!, Home Safe, Speed Demon, Reborn, Meme Collector, Boss Escape, Sky High, Gotcha!. Roblox allows five free badge creations per experience per day, so five exist and the rest have id 0 (skipped) until they are created.

## 2D art
Every picture in the UI is a sticker render of the real brick model (`scripts/preview/portrait.py` renders it on a transparent background, `art/ui/stylize.py` crops, outlines and shades it, `art/ui/make_all.sh` does all of them). Uploaded images must use their IMAGE id (look the Decal id up with Roblox's asset delivery), never the Decal id, or an ImageLabel draws nothing.

## The Index, and bats
- The Index screen has one tab per world (and one for the limited eggs), like the reference: pick a world to see its characters, with how many you have found on the tab. Finding every character of a world pays a reward (25 of that world's common egg, in coins) and unlocks the next bat; the tab turns green with a tick.
- Everyone starts with the Wooden Bat, held at all times (Roblox's own tool bar is hidden; the number keys place traps). Click or tap to swing: a player in front of the swing is thrown back and stunned for a moment, and a runner who is hit drops the egg they carry where they stand. There is no fighting in the Safe Zone or the bases. Sixteen bats, each better than the last (more knockback, longer stun, longer reach, faster swing): Wooden, Foam, Rubber, Stone, Iron, Silver, Golden, Ruby, Emerald, Frost, Lava, Neon, Ghost, Cloud, Galaxy, Divine (`Shared/Game/Bats`, `server/BatTool`).
