# Handoff: state of Steal a Meme Egg (2026-10-10)

## Built and merged (all through PRs, 658 automated checks, CI green)
- Rules: eggs/characters/mutations, bases, economy, events, admin, zones, progression, guardians, nests, limited eggs, store, objective hints, rebirth, daily reward.
- World: home lawn with 12 base plots, a conveyor, a sign to the Wilds, walls; the Wilds: 5 terrains, 6 nests each, guardians that chase, gates keyed to Meme Points.
- Layout: nest and scenery positions come from `Rng` + `Layout` (shared, deterministic, no Roblox `Random`), so the tests check exactly the map players get (nests apart, scenery clear of nests/guardians/gates, all inside the walls).
- Services: sessions + saving, treadmill/speed/slot pads, live events with a half-hourly schedule, admin chat commands (cross-server through MessagingService), limited eggs with shared stock, purchases with safe receipts, ten original sounds, shop screen, HUD with an always-on objective line.
- Creator Hub: experience under Nexus Hollow Studios (universe 10770101743, place 115281364108212), icon and thumbnail ACTIVE, genre Simulation/Idle, description set, three passes created OFF-SALE (coins2x 2026694498, luck2x 2026622537, train2x 2025116507), ten sounds in the audio library.

## NOT verified (no Studio on Linux): please playtest and send screenshots or the Output text
How it looks (terrain colours, guardian models, sign, HUD layout, shop), how chases and prompts feel, sound levels, performance with 12 players, real saves, real Robux purchases, TextChat commands, `Players.MaxPlayers` applying.

## Needs the owner (cannot be done by Claude)
1. Click **Agree** on Roblox's one-time "Managed Pricing" terms (it appears when you set a pass price or save a developer product). It is a binding agreement. After that Claude can: set the three pass prices and put them on sale, create the five developer products (Instant Hatch R$25, 5 Instant Hatches R$99, three limited eggs R$199), and paste every id into `Config.Monetization` so the shop lists them.
2. Roblox gates new experiences to 16+ and trusted friends until it has 250 highly-engaged players (or a refundable fee is paid). Ignored for now by choice.
3. Group description (still the old "Indie horror... NIGHT MANAGER" text): Roblox rejects every new wording with "The description is moderated"; try once from the group page by hand.
4. Publish workflow: add the secret `ROBLOX_API_KEY` and variables `ROBLOX_UNIVERSE_ID=10770101743`, `ROBLOX_PLACE_ID=115281364108212` (see README), or just publish from Studio.
5. TikTok: nothing posted for this game yet (verify the game works first; docs/GROWTH.md has the plan).

## Ideas not built yet
Aura face-offs between characters, a tutorial arrow/beam, pets that follow you, trading, a battle pass, more terrains and eggs, per-player music/sfx volume, mobile layout tuning.
