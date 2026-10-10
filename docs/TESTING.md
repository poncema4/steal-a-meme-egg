# Testing

Claude Code works on Linux with no Roblox Studio, so everything that can be checked without Roblox is checked, in layers:

1. **Rules** (`src/shared/Game`): pure Luau with no Roblox globals; `tests/specs/{Eggs,Base,Economy,Events,Admin,Zones,Progression,Guardian,Limited,Store,Objective,Rebirth,Config}.luau`. Each rule has a check that FAILS when the rule is broken (prove it once by breaking the code).
2. **Real scripts against a fake Roblox** (`tests/fake/Roblox.luau`): the actual server and client scripts run in a simulated world (parts, prompts, remotes, players, DataStore, MarketplaceService, a clock). Specs: `Game, Wilds, Shop, Purchases, ShopUi, Retention, Prompts`.
3. **Lint and format**: `selene src tests`, `stylua --check src tests`.
4. **Type check against the real Roblox API**: `scripts/typecheck.sh` (luau-lsp).
5. **Build**: `rojo build` produces the place file (CI also publishes it as an artifact).

Run everything: `./scripts/check.sh` (the same as CI). Read real exit codes; never pipe selene or stylua through `tail`.

## What the fake world cannot tell you
It is a stand-in, so it can hide bugs that only appear in Roblox. It has caught itself lying several times; each time the fake was made to behave like Roblox FIRST (so a test fails), then the code was fixed:
- `Model:PivotTo` moves the whole model by its pivot (the guardian bodies would have sunk into the ground).
- `CFrame.lookAt(p, p)` is an invalid rotation (guardians would have vanished at their nests).
- `CFrame + Vector3` is a CFrame; `Instance.DescendantAdded` fires for everything inside an inserted model.
Things it cannot show: how anything LOOKS, physics and prompt feel, performance, real DataStore/MessagingService/MemoryStore behaviour, Robux purchase dialogs, TextChat commands. Those need a Studio playtest (see HANDOFF).
