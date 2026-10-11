"""Builds every brick model into src/models/*.rbxmx (and a preview JSON per model for Blender).
Usage: python3 art/brick/build.py [name ...]"""
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
from kit import grid_parts, preview_json, write_rbxmx  # noqa: E402

ROOT = os.path.abspath(os.path.join(HERE, "..", ".."))
MODELS = os.path.join(ROOT, "src", "models")
PREVIEW = os.path.join(ROOT, "art", "renders", "models")


BOSS_SCALE = 2.6
BOSSES = {"Meadow": "SoggyToast", "Dune": "PharaohPancake", "Volcano": "VolcanoVicar", "Frost": "SleepySock",
          "Cosmic": "FinalBossHamster", "Swamp": "SwampSensei", "Candy": "TaffyTitan", "Neon": "VaporVulture",
          "Haunted": "LichLasagna", "Sky": "ZeusZucchini", "Toy": "RubberDuckLord", "Pirate": "DavyJonesDonut",
          "Robot": "OmniOven", "Jungle": "TempleTofu", "Throne": "EmperorEggplant"}


def emit(folder, name, parts, report):
    # scenery and eggs cast no shadows (dozens on screen at once; shadows are what phones struggle with most)
    n = write_rbxmx(os.path.join(MODELS, folder, name + ".rbxmx"), name, parts, shadows=folder not in ("Props", "Eggs"))
    preview_json(os.path.join(PREVIEW, name + ".json"), parts)
    report.append((folder, name, n))


def main(only):
    report = []
    import eggs
    for tier in eggs.TIERS:
        if only and tier not in only:
            continue
        emit("Eggs", tier, grid_parts(eggs.build(tier), "Brick"), report)
    import pets
    for name in pets.RECIPES:
        if only and name not in only:
            continue
        emit("Pets", name, grid_parts(pets.build(name), "Brick"), report)
    import props
    for name in props.RECIPES:
        if only and name not in only:
            continue
        emit("Props", name, grid_parts(props.build(name), "Brick"), report)
    import bats
    for name in bats.RECIPES:
        if only and name not in only:
            continue
        emit("Bats", name, grid_parts(bats.build(name), "Brick"), report)
    import icons
    for name in icons.RECIPES:
        if only and name not in only:
            continue
        emit("Icons", name, grid_parts(icons.build(name), "Brick"), report)
    # one big meme boss per terrain: the same recipes grown 2.6x (about 14 studs tall); no geese
    for zone, recipe in BOSSES.items():
        if only and "Boss" + zone not in only:
            continue
        parts = grid_parts(pets.build(recipe), "Brick")
        for q in parts:
            q.pos = tuple(a * BOSS_SCALE for a in q.pos)
            q.size = tuple(a * BOSS_SCALE for a in q.size)
        emit("Bosses", "Boss" + zone, parts, report)
    for folder, name, n in report:
        print(f"{folder}/{name}: {n} parts")


if __name__ == "__main__":
    main(set(sys.argv[1:]))
