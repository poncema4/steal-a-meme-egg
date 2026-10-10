# Design: Steal a Meme Egg

## One sentence
Grab eggs off a conveyor, hatch them into meme characters that earn coins, and raid your friends' bases before they lock up.

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

## Live ops (the reason people join)
- Schedule every half hour on every server: Lucky Hour (:00), Egg Rain (:10), Coin Rain (:20).
- Admin commands in chat (group owner/rank 250+; everyone in Studio): `/event <name> [seconds]`, `/give <coins>`, `/giveall <coins>`, `/announce <text>`, `/clear`, `/help`. Admin events go to EVERY server through MessagingService.
- Events: Lucky Hour (2x luck), Coin Rain (2x income), Egg Rain (belt 6x faster), Mega Luck (5x), Meme Frenzy (3x both).

## Where the rules live (all tested in `tests/specs`)
`Shared/Game/Eggs` (tables, hatch roll, conveyor odds), `Base` (slots, hatching, steal, lock), `Economy` (prices, offline, number format), `Events`, `Admin`.

## Next
Game passes (2x coins, 2x luck, extra slot), Robux luck boosts, aura face-offs, rebirth, daily reward, invite prompt, thumbnails and TikTok plan (docs/GROWTH.md).
