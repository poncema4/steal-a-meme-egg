# Workflow: Linux laptop (Claude Code) -> GitHub -> Windows PC (Studio)

Code is edited on Linux and pushed to GitHub through PRs. On the Windows PC: `.\scripts\serve.ps1` (git pull + `rojo serve`), Studio plugin > Connect. Rojo syncs scripts live.
Rojo does NOT carry meshes: export from Blender into `assets/`, then Studio > Asset Manager > Bulk Import. Parts-only visuals (the v0 game) need no import.

## Thumbnail and icon
`scripts/blender.sh art/blender/thumb.py` renders the scene (Blender 4.5 portable in ~/tools), then `python3 brand/make_thumb.py` adds the text layer and writes `brand/thumb_1920x1080.png` and `brand/icon_512.png`. Layout follows the top Roblox egg games (rainbow egg name, green income line, red arrow, "!!", a pet guarding its egg and an avatar running off with it); the art itself is ours.

## Map preview (no Studio needed)
`lune run scripts/preview/dump /tmp/map.json` builds the real server world in the fake Roblox and writes every part to JSON; `python3 scripts/preview/render.py /tmp/map.json out_prefix [x0 x1]` draws `out_prefix_top.png` and `out_prefix_side.png`. Use it to look at the layout after any map change (the z-fight test checks flicker, this shows placement).

## 3D map view (the closest thing to Studio on Linux)
After `lune run scripts/preview/dump /tmp/map.json`: `~/tools/blender-4.5.14-linux-x64/blender -b -P scripts/preview/blender_view.py -- /tmp/map.json out.png camX camY camZ targetX targetY targetZ [lens] [x0 x1]` renders every part as a coloured box in Blender from any camera (Roblox coordinates). E.g. the plaza from the red line: `-10 22 0 -150 3 0 24`. Text, meshes and textures are not drawn.
