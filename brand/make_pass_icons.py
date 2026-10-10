"""Square icons for the game passes and developer products (Creator Hub wants 512x512). Same look as the game thumbnail:
a bright saturated background, a big egg, and big gradient words with a heavy black outline.
Run: python3 brand/make_pass_icons.py   (needs Pillow; writes brand/passes/*.png)"""
import pathlib
import sys

from PIL import Image, ImageDraw

sys.path.insert(0, str(pathlib.Path(__file__).parent))
from make_thumb_lib import MONEY, RAINBOW, gradient, outlined_text  # noqa: E402

OUT = pathlib.Path(__file__).parent / "passes"
SIZE = 512

# key: (top word, bottom word, background top/bottom colours, egg colour, word gradient)
ICONS = {
    "coins2x": ("2X", "COINS", ((40, 190, 90), (10, 110, 50)), (255, 215, 60), MONEY),
    "luck2x": ("2X", "LUCK", ((150, 80, 255), (70, 20, 150)), (120, 255, 150), RAINBOW),
    "train2x": ("2X", "SPEED", ((255, 150, 30), (200, 60, 20)), (255, 255, 255), RAINBOW),
    "hatch1": ("HATCH", "NOW!", ((255, 90, 170), (170, 20, 100)), (255, 245, 200), RAINBOW),
    "hatch5": ("5X", "HATCH", ((255, 90, 170), (170, 20, 100)), (255, 245, 200), RAINBOW),
    "limitedGoose": ("LIMITED", "GOOSE", ((255, 205, 40), (200, 120, 10)), (255, 255, 255), RAINBOW),
    "limitedCat": ("LIMITED", "CAT", ((90, 80, 255), (30, 20, 140)), (200, 150, 255), RAINBOW),
    "limitedLord": ("LIMITED", "LORD", ((235, 40, 60), (120, 10, 30)), (255, 215, 60), RAINBOW),
}


def egg(draw: ImageDraw.ImageDraw, cx: int, cy: int, w: int, h: int, color):
    box = (cx - w // 2, cy - h // 2, cx + w // 2, cy + h // 2)
    draw.ellipse((box[0] - 8, box[1] - 8, box[2] + 8, box[3] + 8), fill=(0, 0, 0))
    draw.ellipse(box, fill=color)
    draw.ellipse((cx - w // 4, cy - h // 3, cx - w // 10, cy - h // 8), fill=(255, 255, 255))  # a shine
    for dx, dy in ((0.15, 0.1), (-0.2, 0.25), (0.25, -0.15), (-0.05, -0.3)):  # gold studs like the thumbnail egg
        r = w // 14
        x, y = cx + int(dx * w), cy + int(dy * h)
        draw.polygon([(x + r * 0.9 * c, y + r * 0.9 * s) for c, s in ((1, 0), (0.5, 0.87), (-0.5, 0.87), (-1, 0), (-0.5, -0.87), (0.5, -0.87))], fill=(255, 170, 20))


def make(key: str):
    top, bottom, (c1, c2), egg_color, stops = ICONS[key]
    img = gradient((SIZE, SIZE), [c1, c2]).convert("RGBA")
    egg(ImageDraw.Draw(img), SIZE // 2, SIZE // 2 + 10, 230, 290, egg_color)
    for word, y, size in ((top, 8, 150), (bottom, 342, 150)):
        probe = Image.new("RGBA", (10, 10))
        w, _ = outlined_text(probe, (0, 0), word, size, stops, outline=12, horizontal=True)
        while w > SIZE - 24 and size > 40:  # shrink long words to fit
            size -= 6
            w, _ = outlined_text(Image.new("RGBA", (10, 10)), (0, 0), word, size, stops, outline=12, horizontal=True)
        outlined_text(img, ((SIZE - w) // 2, y), word, size, stops, outline=12, horizontal=True)
    OUT.mkdir(exist_ok=True)
    img.convert("RGB").save(OUT / f"{key}.png")


for key in ICONS:
    make(key)
print("wrote", len(ICONS), "icons to", OUT)
