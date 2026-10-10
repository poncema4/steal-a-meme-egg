"""Draws the dumped UI the way it will look: rounded corners, gradients, outlines, heavy text with a stroke and the real icon art.
Usage: render_ui.py ui.json out.png [background.png]   (a screenshot as background shows the UI on a real scene)"""
import json
import pathlib
import re
import sys

from PIL import Image, ImageDraw, ImageFont

ROOT = pathlib.Path(__file__).resolve().parents[2]
SS = 2  # supersampling for smooth edges
data = json.load(open(sys.argv[1]))
W, H = int(data["width"]), int(data["height"])

# asset id -> icon file, from Config.Icons
icons = {}
for name, ident in re.findall(r'(\w+) = "rbxassetid://(\d+)"', (ROOT / "src/shared/Config.luau").read_text()):
    for folder in ("icons", "pets"):
        f = ROOT / "art/renders" / folder / f"{name}.png"
        if f.exists():
            icons[ident] = f

if len(sys.argv) > 3:
    base = Image.open(sys.argv[3]).convert("RGB").resize((W * SS, H * SS))
else:
    base = Image.new("RGB", (W * SS, H * SS), (120, 190, 235))
img = base.convert("RGBA")
FONT = "/usr/share/fonts/truetype/lato/Lato-Black.ttf"
_fonts = {}


def font(size):
    size = max(8, int(size * SS))
    if size not in _fonts:
        _fonts[size] = ImageFont.truetype(FONT, size)
    return _fonts[size]


def gradient(w, h, top, bottom):
    g = Image.new("RGBA", (w, h))
    px = g.load()
    for y in range(h):
        t = y / max(1, h - 1)
        c = tuple(int(top[i] + (bottom[i] - top[i]) * t) for i in range(3)) + (255,)
        for x in range(w):
            px[x, y] = c
    return g


for r in sorted(data["rects"], key=lambda q: q["depth"]):
    x0, y0 = r["x"] * SS, r["y"] * SS
    w, h = max(1, int(r["w"] * SS)), max(1, int(r["h"] * SS))
    layer = Image.new("RGBA", img.size, (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    box = [x0, y0, x0 + w, y0 + h]
    rad = r["radius"] * SS
    if r["kind"] == "Image":
        path = icons.get(re.sub(r"\D", "", r.get("image") or ""))
        if path:
            pic = Image.open(path).convert("RGBA")
            side = min(w, h)
            pic = pic.resize((side, side), Image.LANCZOS)
            if r.get("imageColor") == [0, 0, 0]:
                black = Image.new("RGBA", pic.size, (0, 0, 0, 255))
                pic = Image.composite(black, Image.new("RGBA", pic.size, (0, 0, 0, 0)), pic.getchannel("A"))
            layer.alpha_composite(pic, (int(x0 + (w - side) / 2), int(y0 + (h - side) / 2)))
        img = Image.alpha_composite(img, layer)
        continue
    visible = r["transparent"] < 1
    if visible:
        alpha = int(255 * (1 - r["transparent"]))
        if r.get("gradient") and r.get("g1"):
            fill = gradient(w, h, r["g1"], r["g2"])
            mask = Image.new("L", (w, h), 0)
            ImageDraw.Draw(mask).rounded_rectangle([0, 0, w - 1, h - 1], radius=rad, fill=alpha)
            layer.paste(fill, (int(x0), int(y0)), mask)
        else:
            d.rounded_rectangle(box, radius=rad, fill=(r["r"], r["g"], r["b"], alpha))
        if r["stroke"] > 0:
            d.rounded_rectangle(box, radius=rad, outline=tuple(r["strokeColor"]) + (255,), width=int(r["stroke"] * SS))
    if r["text"]:
        f = font(r["textSize"])
        tw = d.textlength(r["text"], font=f)
        if r["align"] == "Left":
            tx = x0 + 6 * SS
        elif r["align"] == "Right":
            tx = x0 + w - tw - 6 * SS
        else:
            tx = x0 + (w - tw) / 2
        ty = y0 + (h - r["textSize"] * SS * 1.1) / 2
        sw = int(max(r["textStroke"], 2 if r["kind"] == "TextButton" else 0) * SS)
        d.text((tx, ty), r["text"], font=f, fill=tuple(r["textColor"]) + (255,), stroke_width=sw, stroke_fill=(0, 0, 0, 255))
    img = Image.alpha_composite(img, layer)

img.convert("RGB").resize((W, H), Image.LANCZOS).save(sys.argv[2])
print("ok", sys.argv[2], len(data["rects"]), "elements")
