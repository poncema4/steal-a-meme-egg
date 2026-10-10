# Reference: what the real games look like

Sources: Marco's two screenshots (brand/reference1.png, brand/reference2.png, from Steal a Brainrot), a Steal an Egg gameplay video frame, and written guides. Third-party frames are kept out of the repo; this is our own description. Base gameplay only: events are ours to design later.

## Map
- One long straight corridor with tall checkered dirt walls on both sides and a flat bright floor (two alternating greens).
- The Safe Zone is a wide strip at the start. A red line marks its edge, "SAFE ZONE" is written large on the ground, and the zone title ("Forest" + a face) shows at the top while you stand in a terrain.
- Terrains follow each other down the corridor, each with its own floor colour and oversized props (bones/claws in the desert); the next terrain is visible at the far end.
- Each player has a fenced pen (blue/purple/white fences) inside the safe zone where their eggs and pets sit. There is no conveyor.
- Treadmill: in front of the player's base; standing on it trains speed.
- Each terrain has 5 egg nests, each watched by a guardian (here: a meme).

## Carry and chase
- Stealing an egg lights it up above your head. A big red "RUN!!" banner shows at the top and a red "Drop" button at the bottom centre. A speed trail follows you.
- A guardian chases you; if it catches you, you are flung away and the egg drops.
- Traps: up to 3 placed at once; they slow guardians. Hotbar at the bottom centre shows the traps.

## HUD
- Left: Shop (green), Index (blue), Slow Mode toggle.
- Bottom left: speed (shoe icon, big suffixed number, multiplier in brackets) and money ($ with suffixes up to Qa).
- Bottom right: timer; speed boost timer ("x1.25 3m 54s").
- Right: three square icon buttons: eggs (red, count badge), pets (orange paw), trophy (gold).
- Top right: a People list with Speed and Money/s per player.
- Floating green "+$1.8B" numbers rise above pets as they earn.
- Eggs and pets can have mutations.

## More detail from gameplay frames (Marco's video, base game only)
- Panels: dark charcoal rounded panel with a thick black outline, a bright gradient title bar with a heavy white title, a red square X on the top-right corner. Buttons are chunky gradient fills (green action, blue, orange, red) with a thick black outline and a white heavy label.
- Sell panel: "Sort By" column on the left (Weight, Value, Select All), a grid of item cards (picture, weight in Kg, green $ value), "Total Value: $0" and a green Sell button at the bottom.
- Inventory: a hotbar-style "All Items" grid with a search box at the bottom centre.
- A pen holds one big display egg with a tag above it ("Egg 17h 59m": hatch timers can be hours).
- On join: "You earn $2.2Qa/Day offline!" banner.
- Left stack: Shop (green), Index (blue), Slow Mode (small toggle). Right edge: red egg button with a count badge, orange pets button, a green potion button with a timer.
- Scaling: everything is relative to the screen so the same layout works on phone, console and desktop.

## How ours maps (src/client/Ui.luau, Hud.luau)
Ui.screen scales to the real screen (UiScale: touch uses a smaller design screen so everything is bigger, 44 px minimum tap target, device safe area, rescales on resize). Ui.panel = the dark panel with title bar and red X; B on a gamepad closes it and a gamepad cursor starts on its first button. Preview without Studio: `lune run scripts/preview/dump_ui out.json 844 390 touch` then `python3 scripts/preview/render_ui.py out.json out.png`.
