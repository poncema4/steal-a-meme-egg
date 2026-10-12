"""Crops the rendered item pictures square and writes the backpack icons: bat.png and trap_x1..trap_x6.png (the trap shows how
many you have left, like Steal an Egg's "x3"). Usage: python3 art/items/compose.py render_dir"""
import pathlib
import sys

from PIL import Image, ImageDraw, ImageFont

ROOT = pathlib.Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "brand"))
from make_thumb_lib import FONT  # noqa: E402

src = pathlib.Path(sys.argv[1])
OUT = ROOT / "art" / "items" / "icons"
OUT.mkdir(parents=True, exist_ok=True)


def square(path: pathlib.Path) -> Image.Image:
    im = Image.open(path).convert("RGBA")
    box = im.getbbox()
    im = im.crop(box)
    side = int(max(im.size) * 1.08)
    sq = Image.new("RGBA", (side, side), (0, 0, 0, 0))
    sq.alpha_composite(im, ((side - im.width) // 2, (side - im.height) // 2))
    return sq.resize((256, 256), Image.LANCZOS)


square(src / "bat.png").save(OUT / "bat.png")
trap = square(src / "trap.png")
for n in range(1, 7):
    im = trap.copy()
    d = ImageDraw.Draw(im)
    font = ImageFont.truetype(FONT, 92)
    text = f"x{n}"
    w = d.textlength(text, font=font)
    d.text(((256 - w) / 2, 76), text, font=font, fill=(255, 255, 255, 255), stroke_width=9, stroke_fill=(20, 18, 24, 255))
    im.save(OUT / f"trap_x{n}.png")
print("wrote", OUT)
