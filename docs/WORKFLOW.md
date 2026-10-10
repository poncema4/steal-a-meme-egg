# Workflow: Linux laptop (Claude Code) -> GitHub -> Windows PC (Studio)

Code is edited on Linux and pushed to GitHub through PRs. On the Windows PC: `.\scripts\serve.ps1` (git pull + `rojo serve`), Studio plugin > Connect. Rojo syncs scripts live.
Rojo does NOT carry meshes: export from Blender into `assets/`, then Studio > Asset Manager > Bulk Import. Parts-only visuals (the v0 game) need no import.

## Thumbnail and icon
`scripts/blender.sh art/blender/thumb.py` renders the scene (Blender 4.5 portable in ~/tools), then `python3 brand/make_thumb.py` adds the text layer and writes `brand/thumb_1920x1080.png` and `brand/icon_512.png`. Layout follows the top Roblox egg games (rainbow egg name, green income line, red arrow, "!!", a pet guarding its egg and an avatar running off with it); the art itself is ours.
