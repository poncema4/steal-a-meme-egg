# AGENTS.md - Steal a Meme Egg (Roblox, Rojo)

A Roblox game by Nexus Hollow Studios (Swag_Boy435 / V1RTU4L). Claude Code works on Linux (no Roblox Studio there); the owner playtests on a Windows PC through Rojo. The studio makes many games: keep group-level text game-agnostic.

## What Claude can and cannot check
- CAN: Luau logic in `src/shared` (Lune tests), the real server/client scripts against `tests/fake/Roblox.luau`, lint (Selene), format (StyLua), type-check (luau-lsp), build (`rojo build`), CI.
- CANNOT: see the 3D game, physics, GUI layout, real DataStores/MessagingService/TextChat. Keep those parts thin; ask the owner to playtest (screenshots or Output text).

## Workflow
1. Branch -> small change -> `./scripts/check.sh` (read real exit codes: never pipe selene/stylua through `tail`) -> commit -> PR -> CI green -> rebase merge, delete branch.
2. Every new rule gets a spec that FAILS when the rule is broken (break it once to prove it).
3. Commits: Claude as author (`--author="Claude <noreply@anthropic.com>"`), owner `poncema4` as `Co-authored-by`; PRs opened with plain `gh` (account poncema4); merge with `--rebase`.
4. The repo is PUBLIC: never commit keys. The Roblox API key lives only in the GitHub secret `ROBLOX_API_KEY`.
5. Publishing is manual (the `Publish to Roblox` workflow); never publish live without the owner saying so.
6. Never claim the game is "coming soon" or "out" in public text without checking its real state.
7. Pure modules under `src/shared/Game` use `require("./Sibling")` (works in Lune and Rojo), never `script.Parent`, and no Roblox globals.
