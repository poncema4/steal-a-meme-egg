# Raid a Meme Egg

A simple, fast Roblox game by **Nexus Hollow Studios** (group owner: Swag_Boy435 / V1RTU4L): grab eggs off a conveyor, hatch them into meme characters that earn coins, and raid your friends' bases before they lock up. Live events and admin drops keep servers busy.

The code is plain Luau in this repo. **Rojo** syncs it into Roblox Studio, **Lune** tests the game logic on any computer, and a GitHub Action can publish the place to Roblox.

```
src/shared   code both sides use (ReplicatedStorage.Shared)   <- testable logic lives in Game/
src/server   server scripts (ServerScriptService.Server)
src/client   client scripts (StarterPlayerScripts.Client)
tests        checks that run without Roblox:  lune run tests/run
art          Blender scripts (thumbnails, models)
brand        store art
docs         DESIGN, WORKFLOW, GROWTH
```

## Set everything up

### Windows PC (where Roblox Studio runs)
Install **Roblox Studio** and **Git for Windows**, then in PowerShell:
```powershell
git clone https://github.com/poncema4/raid-a-meme-egg.git
cd raid-a-meme-egg
powershell -ExecutionPolicy Bypass -File scripts\setup.ps1
```
Open a NEW PowerShell window, then every session:
```powershell
cd raid-a-meme-egg
.\scripts\serve.ps1
```
That pulls the latest code from GitHub and starts the Rojo server. In Studio: open a **Baseplate**, **Plugins > Rojo > Connect**, then press **Play**.

### Linux / macOS (where Claude Code writes the code)
```bash
git clone https://github.com/poncema4/raid-a-meme-egg.git && cd raid-a-meme-egg
./scripts/setup.sh      # once: Rokit + every tool
./scripts/check.sh      # lint + format + tests + type-check + place build (same as CI)
```

## Every change goes through a pull request
Branch, small change, `./scripts/check.sh`, PR, CI green, rebase-merge. Then on the PC `.\scripts\serve.ps1` pulls it and Studio updates live.

## Connecting the game to the group (once)
1. In Studio: **File > New > Baseplate**, then **File > Publish to Roblox As...**, choose **Nexus Hollow Studios** as the owner and name it **Raid a Meme Egg**.
2. Creator Hub > the experience > "..." > copy the **Universe ID** and **Place ID**.
3. <https://create.roblox.com/dashboard/credentials>: make an API key with **Place Publishing** write access to that experience. Never paste it anywhere except GitHub's secret form.
4. GitHub repo **Settings > Secrets and variables > Actions**: secret `ROBLOX_API_KEY`, variables `ROBLOX_UNIVERSE_ID`, `ROBLOX_PLACE_ID`; create an environment named `roblox`.
5. **Actions > Publish to Roblox > Run workflow** ("saved" for Studio only, "published" for live).

## If Rojo says "denied script injection permission"
Studio > **Plugins** > **Manage Plugins** > Rojo > gear > turn on **Script Injection**, reconnect, click **Accept**.

## Rules
- Game logic goes in `src/shared/Game` with no Roblox services, with a spec in `tests/specs` that fails if the rule is wrong.
- The repo is PUBLIC: no keys, tokens or personal data, ever.
- See `docs/DESIGN.md` for the game and `docs/GROWTH.md` for the launch plan.
