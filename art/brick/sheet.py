"""Lays several model previews side by side in one JSON so Blender renders them in a single picture.
Usage: python3 art/brick/sheet.py out.json spacing columns Name1 Name2 ..."""
import json
import os
import sys

root = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "renders", "models"))
out, spacing, cols = sys.argv[1], float(sys.argv[2]), int(sys.argv[3])
names = sys.argv[4:]
rows = []
for i, n in enumerate(names):
    for p in json.load(open(os.path.join(root, n + ".json"))):
        p = dict(p)
        c, r = i % cols, i // cols
        p["x"] += (c - (min(cols, len(names)) - 1) / 2) * spacing
        p["y"] -= r * spacing * 1.05
        rows.append(p)
json.dump(rows, open(out, "w"))
print(len(rows), "parts")
