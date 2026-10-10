"""Stamps the brick models into a dumped map so the Blender render shows the real scenery, nests, eggs and bosses.
Usage: python3 scripts/preview/compose.py map.json out.json   (reads map.models.json next to the map; models from art/renders/models)"""
import json
import math
import os
import sys

root = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
src, out = sys.argv[1], sys.argv[2]
# the fake world has no model templates, so it also built the plain stand-ins; the real models replace them
STAND_INS = {"Trunk", "Leaves", "Cactus", "CactusArm", "Rock", "Ice", "Crystal", "Ring", "Egg", "Body"}
parts = [p for p in json.load(open(src)) if p["name"] not in STAND_INS]
placements = json.load(open(src.replace(".json", "") + ".models.json"))
cache = {}
for m in placements:
    if m["id"] not in cache:
        cache[m["id"]] = json.load(open(os.path.join(root, "art", "renders", "models", m["id"] + ".json")))
    a, c, s = m["yaw"], math.cos(m["yaw"]), m["scale"]
    sn = math.sin(m["yaw"])
    for p in cache[m["id"]]:
        x, y, z = p["x"] * s, p["y"] * s, p["z"] * s
        q = dict(p)
        # a turn about the vertical axis, Roblox's way: x' = x cos + z sin, z' = -x sin + z cos
        q["x"], q["y"], q["z"] = m["x"] + x * c + z * sn, m["y"] + y, m["z"] - x * sn + z * c
        q["sx"], q["sy"], q["sz"] = p["sx"] * s, p["sy"] * s, p["sz"] * s
        q["yaw"] = p.get("yaw", 0.0) + a
        parts.append(q)
json.dump(parts, open(out, "w"))
print(f"{len(placements)} models, {len(parts)} parts -> {out}")
