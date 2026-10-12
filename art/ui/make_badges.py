"""Round medallion art for the badges (Roblox wants 512x512): a coloured disc with a bold rim and a sticker icon in the middle.
Usage: python3 art/ui/make_badges.py     (writes brand/badges/*.png; needs art/ui from make_all.sh)"""
import pathlib

from PIL import Image, ImageDraw, ImageFilter

import sys

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
from emoji_art import emoji  # noqa: E402

ROOT = pathlib.Path(__file__).resolve().parents[2]
OUT = ROOT / "brand" / "badges"
SIZE = 512

# key: (sticker, disc top colour, disc bottom colour)
BADGES = {
    "welcome": ("emoji:\U0001F44B", (80, 210, 120), (20, 130, 70)),
    "firstSteal": ("emoji:\U0001F95A", (255, 170, 60), (200, 90, 20)),
    "firstHatch": ("emoji:\U0001F423", (255, 120, 190), (170, 30, 110)),
    "homeSafe": ("emoji:\U0001F3E0", (90, 170, 255), (30, 80, 190)),
    "speedDemon": ("emoji:⚡", (255, 90, 80), (170, 20, 40)),
    "reborn": ("emoji:\U0001F31F", (255, 215, 70), (210, 140, 10)),
    "collector": ("emoji:\U0001F4D6", (110, 140, 255), (50, 50, 170)),
    "bossEscape": ("emoji:\U0001F3C3", (230, 60, 70), (110, 10, 30)),
    "deepDiver": ("emoji:☁", (140, 210, 255), (60, 120, 220)),
    "trapSpringer": ("item:trap", (150, 160, 190), (60, 70, 100)),
}


def disc(top, bottom) -> Image.Image:
    img = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    grad = Image.new("RGB", (SIZE, SIZE))
    px = grad.load()
    for y in range(SIZE):
        f = y / (SIZE - 1)
        c = tuple(int(top[i] * (1 - f) + bottom[i] * f) for i in range(3))
        for x in range(SIZE):
            px[x, y] = c
    mask = Image.new("L", (SIZE, SIZE), 0)
    m = ImageDraw.Draw(mask)
    pad = 14
    m.ellipse((pad, pad, SIZE - pad, SIZE - pad), fill=255)
    img.paste(grad, (0, 0), mask)
    d = ImageDraw.Draw(img)
    d.ellipse((pad, pad, SIZE - pad, SIZE - pad), outline=(24, 22, 34), width=14)  # a bold rim
    d.ellipse((pad + 22, pad + 22, SIZE - pad - 22, SIZE - pad - 22), outline=(255, 255, 255, 150), width=6)
    shine = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    ImageDraw.Draw(shine).ellipse((90, 50, SIZE - 150, 210), fill=(255, 255, 255, 60))
    img.alpha_composite(shine.filter(ImageFilter.GaussianBlur(10)))
    return img


def picture(art: str) -> Image.Image:
    """emoji:<char> = Google's Noto emoji art (Apache 2.0); item:<name> = the Blender-rendered item. Square, centred."""
    if art.startswith("emoji:"):
        im = emoji(art[6:])
    else:
        im = Image.open(ROOT / "art" / "items" / "icons" / f"{art[5:]}.png").convert("RGBA")
        im = im.crop(im.getbbox())
    side = int(max(im.size) * 1.1)
    sq = Image.new("RGBA", (side, side), (0, 0, 0, 0))
    sq.alpha_composite(im, ((side - im.width) // 2, (side - im.height) // 2))
    return sq


def make(key: str):
    art, top, bottom = BADGES[key]
    img = disc(top, bottom)
    sticker = picture(art).resize((300, 300), Image.LANCZOS)
    img.alpha_composite(sticker, ((SIZE - 300) // 2, (SIZE - 300) // 2 + 6))
    OUT.mkdir(parents=True, exist_ok=True)
    img.save(OUT / f"{key}.png")


if __name__ == "__main__":
    for k in BADGES:
        make(k)
    sheet = Image.new("RGB", (256 * 5, 256 * 2), (40, 40, 50))
    for i, k in enumerate(BADGES):
        sheet.paste(Image.open(OUT / f"{k}.png").convert("RGBA").resize((256, 256)), ((i % 5) * 256, (i // 5) * 256), Image.open(OUT / f"{k}.png").convert("RGBA").resize((256, 256)))
    sheet.save("/home/poncema4/testflight/screenshots/badges_sheet.png")
    print("wrote", len(BADGES), "badges")
