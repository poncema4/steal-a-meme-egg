"""Draws the dumped map: a top-down view and a side view, as PNGs. Usage: render.py map.json out_prefix [x0 x1]"""
import json
import sys

from PIL import Image, ImageDraw

parts = json.load(open(sys.argv[1]))
prefix = sys.argv[2]
x0 = float(sys.argv[3]) if len(sys.argv) > 3 else min(p["x"] - p["sx"] / 2 for p in parts)
x1 = float(sys.argv[4]) if len(sys.argv) > 4 else max(p["x"] + p["sx"] / 2 for p in parts)
Z = 170
scale = 1400 / (x1 - x0)
H_TOP = int(2 * Z * scale)


import math


def corners(p):
    """The footprint as 4 (x, z) points, turned by the part's yaw."""
    c, s = math.cos(p["yaw"]), math.sin(p["yaw"])
    out = []
    width = p["sy"] if p.get("rolled") else p["sx"]
    for sx, sz in ((-1, -1), (1, -1), (1, 1), (-1, 1)):
        lx, lz = sx * width / 2, sz * p["sz"] / 2
        out.append((p["x"] + lx * c + lz * s, p["z"] - lx * s + lz * c))
    return out


# top view: draw low parts first so tall ones cover them
top = Image.new("RGB", (1400, H_TOP), (140, 190, 235))
d = ImageDraw.Draw(top)
for p in sorted(parts, key=lambda q: q["y"] + q["sy"] / 2):
    d.polygon([((x - x0) * scale, (z + Z) * scale) for x, z in corners(p)], fill=(p["r"], p["g"], p["b"]))
top.save(prefix + "_top.png")

# side view (looking along z), so heights and walls show
ymax = max(p["y"] + p["sy"] / 2 for p in parts)
H_SIDE = int((ymax + 6) * scale)
side = Image.new("RGB", (1400, H_SIDE), (140, 190, 235))
d = ImageDraw.Draw(side)
for p in sorted(parts, key=lambda q: -abs(q["z"])):
    sx = abs(p["sx"] * math.cos(p["yaw"])) + abs(p["sz"] * math.sin(p["yaw"]))
    d.rectangle(
        [
            (p["x"] - sx / 2 - x0) * scale,
            H_SIDE - (p["y"] + p["sy"] / 2) * scale,
            (p["x"] + sx / 2 - x0) * scale,
            H_SIDE - (p["y"] - p["sy"] / 2) * scale,
        ],
        fill=(p["r"], p["g"], p["b"]),
    )
side.save(prefix + "_side.png")
print("ok", prefix)
