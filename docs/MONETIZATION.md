# Monetization

Same shape as the top egg games: speed-ups and luck, never a wall. Nothing here is required to play.

## What is for sale (all ids are 0 until created in Creator Hub; an id of 0 is never offered or prompted)
**Game passes** (permanent): 2x Coins (R$399), 2x Luck (R$299), 2x Training (R$199).
**Developer products**: Instant Hatch (R$25), 5 Instant Hatches (R$99), and one limited egg per rotation (Golden Goose, Cosmic Cat, Meme Lord, R$199 each).
Coins buy the same limited eggs (1,000,000,000 coins) and skip hatches (60% of the egg price), so Robux is a shortcut, not a gate.

## Turning it on (Creator Hub; Claude does not price anything on your account without you saying so)
1. Creator Hub > the experience > Monetization > Passes: create each pass, copy its id.
2. Same area > Developer Products: create each product, copy its id.
3. Paste the ids into `src/shared/Config.luau` under `Monetization`, open a PR, merge, sync.
4. Test a purchase in Studio before telling anyone.

## How it is kept safe
- The client sends only a key ("pass", "coins2x"); the server maps it to the real id, so a client cannot name an id.
- A receipt is acknowledged only after the player is SAVED. If the DataStore is down Roblox retries, and the retry is recognised by its receipt id so the player is never paid twice (tested with a failing DataStore).
- Receipt ids are kept in the save (the newest 300). Passes are re-checked on every join.
- A paid limited egg is always delivered: if the base is full it waits and is placed the moment a slot frees up.
- Tested: `tests/specs/Store` (rules) and `tests/specs/Purchases` (real services).
