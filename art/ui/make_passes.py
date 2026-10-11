"""Square icons for the gamepasses and developer products (Creator Hub wants 512x512), with NOTHING cut off. The Roblox store shows
these icons cropped to a CIRCLE, so every line of text is sized to fit inside the circle at its height (with a margin), and the
picture sits in the middle. The picture is one of the sticker icons from art/ui (run art/ui/make_all.sh first).
Usage: python3 art/ui/make_passes.py     (writes brand/passes/*.png)"""
import pathlib
import sys

from PIL import Image, ImageDraw, ImageFont

ROOT = pathlib.Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "brand"))
from make_thumb_lib import FONT, MONEY, RAINBOW, gradient  # noqa: E402

OUT = ROOT / "brand" / "passes"
SIZE = 512
SAFE = 44  # nothing is drawn closer than this to an edge
CIRCLE = SIZE / 2 - 30  # the store crops to a circle: everything stays inside this radius


def chord(centre_y: int, height: int) -> int:
    """The widest a line of text may be at this height so its corners stay inside the circle."""
    import math

    far = max(abs(centre_y - height / 2 - SIZE / 2), abs(centre_y + height / 2 - SIZE / 2))
    return int(2 * math.sqrt(max(CIRCLE**2 - far**2, 0)))

# key: (picture, top line, bottom line, background top/bottom colours, text colours)
ICONS = {
    "coins2x": ("Icons/cash", "2X", "COINS", ((40, 190, 90), (10, 110, 50)), MONEY),
    "luck2x": ("Icons/potion", "2X", "LUCK", ((150, 80, 255), (70, 20, 150)), RAINBOW),
    "train2x": ("Icons/shoe", "2X", "TRAINING", ((255, 150, 30), (200, 60, 20)), RAINBOW),
    "fastHatch": ("Eggs/Disco", "2X", "HATCH SPEED", ((255, 90, 170), (170, 20, 100)), RAINBOW),
    "vip": ("Icons/trophy", "VIP", "+25% COINS", ((255, 205, 40), (200, 120, 10)), MONEY),
    "trapMaster": ("Icons/trap", "TRAP", "MASTER", ((90, 110, 140), (30, 40, 70)), RAINBOW),
    "bossSlow": ("Pets/FinalBossHamster", "SLOW", "BOSSES", ((235, 40, 60), (120, 10, 30)), RAINBOW),
    "hatch1": ("Eggs/Soggy", "HATCH", "NOW!", ((255, 90, 170), (170, 20, 100)), RAINBOW),
    "hatch5": ("Eggs/Golden", "5X", "HATCH", ((255, 90, 170), (170, 20, 100)), RAINBOW),
    "limitedGoose": ("Pets/GoldenGoose", "LIMITED", "GOOSE", ((255, 205, 40), (200, 120, 10)), RAINBOW),
    "limitedCat": ("Pets/CosmicKitten", "LIMITED", "CAT", ((90, 80, 255), (30, 20, 140)), RAINBOW),
    "limitedLord": ("Pets/MemeLordPrime", "LIMITED", "LORD", ((235, 40, 60), (120, 10, 30)), RAINBOW),
}


def fit_text(img: Image.Image, text: str, centre_y: int, max_height: int, stops, max_width: int):
    """Draws `text` centred, with a heavy outline, at the biggest size that fits max_width and max_height."""
    size = max_height
    while size > 14:
        font = ImageFont.truetype(FONT, size)
        outline = max(4, size // 9)
        box = ImageDraw.Draw(img).textbbox((0, 0), text, font=font, stroke_width=outline)
        w, h = box[2] - box[0], box[3] - box[1]
        if w <= max_width and h <= max_height:
            break
        size -= 2
    layer = Image.new("RGBA", (w + 16, h + 16), (0, 0, 0, 0))
    ld = ImageDraw.Draw(layer)
    ox, oy = 8 - box[0], 8 - box[1]
    ld.text((ox + 4, oy + 5), text, font=font, fill=(0, 0, 0, 140), stroke_width=outline, stroke_fill=(0, 0, 0, 140))
    ld.text((ox, oy), text, font=font, fill=(0, 0, 0, 255), stroke_width=outline, stroke_fill=(0, 0, 0, 255))
    mask = Image.new("L", layer.size, 0)
    ImageDraw.Draw(mask).text((ox, oy), text, font=font, fill=255)
    layer.paste(gradient(layer.size, stops, True), (0, 0), mask)
    img.alpha_composite(layer, ((SIZE - layer.width) // 2, centre_y - layer.height // 2))


def make(key: str):
    art, top, bottom, (c1, c2), stops = ICONS[key]
    img = gradient((SIZE, SIZE), [c1, c2]).convert("RGBA")
    # a soft light behind the picture
    glow = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    ImageDraw.Draw(glow).ellipse((SAFE, 120, SIZE - SAFE, 420), fill=(255, 255, 255, 60))
    img.alpha_composite(glow)
    sticker = Image.open(ROOT / "art" / "ui" / f"{art}.png").convert("RGBA")
    h = 236
    sticker = sticker.resize((h, h), Image.LANCZOS)
    img.alpha_composite(sticker, ((SIZE - h) // 2, (SIZE - h) // 2 + 4))
    fit_text(img, top, 120, 62, stops, chord(120, 62))
    fit_text(img, bottom, 392, 70, stops, chord(392, 70))
    OUT.mkdir(exist_ok=True)
    img.convert("RGB").save(OUT / f"{key}.png")


if __name__ == "__main__":
    for k in ICONS:
        make(k)
    print("wrote", len(ICONS), "pass icons")
