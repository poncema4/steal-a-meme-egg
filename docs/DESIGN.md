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
One long walled corridor: the Safe Zone at the west end (eight fenced pens in a semicircle around a plaza (one per player; a server holds 8), a red line, a gateway sign over it reading SAFE ZONE), then a strip of themed terrains going east (x 10 to 1210): Meme Meadow, Dune Desert, Lava Lands, Frozen Peaks, Cosmic Void. Each has 5 nests; on every nest a meme guardian sits on an egg. Hold E on the egg to steal it. The guardian chases you (it gives up after 12 s or 150 studs, and takes the egg back if it touches you and flings you back toward the Safe Zone like a rag doll). Carry the egg into your own base to start it hatching and earn Meme Points. If your base is full when you get home the egg is sold for half its price instead (you still get the Meme Points), so a full base never traps you. You carry one egg at a time and run 10% slower while carrying.

Gates: each terrain needs Meme Points (0 / 25 / 250 / 2,500 / 20,000). The server pushes you back from a terrain you have not unlocked. Rarer terrains hold rarer eggs and faster guardians (12 / 17 / 21 / 25 / 29 studs per second).

Speed cannot be bought: run on the treadmill in front of your pen (the belt carries you backward, standing still trains nothing). It gives 2 XP per second at level 0 and 1.6x more per treadmill level (12 levels, 100 coins for the first upgrade, x3.2 each). Speed levels 0 to 30 raise walk speed from 16 to 43. The level you need to outrun a terrain while carrying: Meadow 0, Dune 4, Lava 9, Frost 14, Cosmic 18 (tested in `tests/specs/Zones`).

Meme Points per delivered egg: Soggy 1, Disco 5, Spicy 25, Golden 150, Cosmic 1,000, Divine 10,000.

There is no conveyor and no raiding: the Wilds are the only source of eggs (plus daily rewards and the shop).

## Hatching and limited eggs (built)
Eggs take real time to hatch (8 s up to 5 minutes by tier). Hold E on a hatching egg in your base to skip the wait for coins: 60% of the egg's price, scaled by how much time is left (`Economy.skipCost`).

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
