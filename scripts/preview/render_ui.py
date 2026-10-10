"""Draws the dumped UI as boxes with their text. Usage: render_ui.py ui.json out.png"""
import json
import sys

from PIL import Image, ImageDraw, ImageFont

data = json.load(open(sys.argv[1]))
W, H = int(data["width"]), int(data["height"])
img = Image.new("RGB", (W, H), (120, 190, 235))
d = ImageDraw.Draw(img, "RGBA")
try:
    font = ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf", 14)
except OSError:
    font = ImageFont.load_default()
for r in sorted(data["rects"], key=lambda q: q["depth"]):
    x0, y0, x1, y1 = r["x"], r["y"], r["x"] + r["w"], r["y"] + r["h"]
    if r["kind"] != "TextLabel" or r["transparent"] < 1:
        alpha = int(255 * (1 - r["transparent"]))
        fill = (r["r"], r["g"], r["b"], alpha)
        if r["gradient"]:
            fill = (90, 200, 90, 230) if r["name"].endswith("Button") or r["name"] == "SlowToggle" else fill
        d.rectangle([x0, y0, x1, y1], fill=fill, outline=(0, 0, 0, 255), width=2)
    if r["text"]:
        d.text((x0 + 4, y0 + 2), r["text"][:40], fill=(255, 255, 255, 255), font=font, stroke_width=2, stroke_fill=(0, 0, 0, 255))
img.save(sys.argv[2])
print("ok", sys.argv[2], len(data["rects"]), "elements")
