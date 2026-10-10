# Workflow: Linux laptop (Claude Code) -> GitHub -> Windows PC (Studio)

Code is edited on Linux and pushed to GitHub through PRs. On the Windows PC: `.\scripts\serve.ps1` (git pull + `rojo serve`), Studio plugin > Connect. Rojo syncs scripts live.
Rojo does NOT carry meshes: export from Blender into `assets/`, then Studio > Asset Manager > Bulk Import. Parts-only visuals (the v0 game) need no import.

## Thumbnail and icon
`scripts/blender.sh art/blender/thumb.py` renders the scene (Blender 4.5 portable in ~/tools), then `python3 brand/make_thumb.py` adds the text layer and writes `brand/thumb_1920x1080.png` and `brand/icon_512.png`. Layout follows the top Roblox egg games (rainbow egg name, green income line, red arrow, "!!", a pet guarding its egg and an avatar running off with it); the art itself is ours.

## Map preview (no Studio needed)
`lune run scripts/preview/dump /tmp/map.json` builds the real server world in the fake Roblox and writes every part to JSON; `python3 scripts/preview/render.py /tmp/map.json out_prefix [x0 x1]` draws `out_prefix_top.png` and `out_prefix_side.png`. Use it to look at the layout after any map change (the z-fight test checks flicker, this shows placement).

## 3D map view (the closest thing to Studio on Linux)
After `lune run scripts/preview/dump /tmp/map.json`: `~/tools/blender-4.5.14-linux-x64/blender -b -P scripts/preview/blender_view.py -- /tmp/map.json out.png camX camY camZ targetX targetY targetZ [lens] [x0 x1]` renders every part as a coloured box in Blender from any camera (Roblox coordinates). E.g. the plaza from the red line: `-10 22 0 -150 3 0 24`. Text, meshes and textures are not drawn.

## UI preview that looks like the game
`lune run scripts/preview/dump_ui /tmp/ui.json 1280 720 desktop none` then `python3 scripts/preview/render_ui.py /tmp/ui.json out.png [background.png]` draws the real HUD (rounded corners, gradients, outlines, heavy text, the real icon art). Pass a reference screenshot as the background to compare placement with the game we are copying; the reference's own HUD shows through, so judge position and style, not overlaps. Last argument of dump_ui is a panel to open: `index`, `eggs`, `pets` or `shop`.

## Brick models (art/brick)

`python3 art/brick/build.py` writes the eggs and pets to `src/models/**.rbxmx` (Rojo maps them to `ServerStorage.Models`) and
preview data to `art/renders/models`. `python3 art/brick/sheet.py out.json 7 5 Name...` lays models side by side; render it with
`scripts/preview/blender_view.py`. The server (`src/server/Models.luau`) stands a clone on each pen pedestal and nest, tinting Gold
and Rainbow; with no template it keeps the plain look. Models face -Z, with `Root` at the feet.

## Seeing the whole map with the real models

`lune run scripts/preview/dump /tmp/map.json` now also writes `/tmp/map.models.json` (where scenery, nests, eggs and bosses stand). `python3 scripts/preview/compose.py /tmp/map.json /tmp/scene.json` stamps the brick models from `art/renders/models` in (dropping the plain stand-ins the fake world builds) and `blender -b -P scripts/preview/blender_view.py -- /tmp/scene.json out.png camX camY camZ targetX targetY targetZ [lens] [x0 x1]` renders it. The viewer builds one mesh per colour, so a 20,000-part scene renders in seconds. E.g. the Meadow from the gate: `30 40 60 130 6 0 34 12 260`.

## Phone performance budget

`tests/specs/Perf.luau` fails the build if the brick models add more than 13,500 parts to the Wilds (3,500 in any one terrain), if
streaming is off, or if scenery and eggs cast shadows. How it is kept small: bigger bricks for round props and eggs
(`art/brick/props.py` UNITS, `eggs.py` U), 22 props per terrain (`Layout.PROPS`), no shadows from scenery or eggs, models
stream in whole (`ModelStreamingMode` Atomic), and `Workspace.StreamingEnabled` is set in `default.project.json` (radius 128 to 512,
MinimumRadiusPause). If Rojo's live sync does not apply the Workspace streaming properties in Studio, set them by hand once.
