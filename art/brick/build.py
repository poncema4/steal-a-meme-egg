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


def emit(folder, name, parts, report):
    n = write_rbxmx(os.path.join(MODELS, folder, name + ".rbxmx"), name, parts)
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
    for folder, name, n in report:
        print(f"{folder}/{name}: {n} parts")


if __name__ == "__main__":
    main(set(sys.argv[1:]))
