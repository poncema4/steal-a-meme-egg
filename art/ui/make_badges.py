"""Round medallion art for the badges (Roblox wants 512x512): a coloured disc with a bold rim and a sticker icon in the middle.
Usage: python3 art/ui/make_badges.py     (writes brand/badges/*.png; needs art/ui from make_all.sh)"""
import pathlib

from PIL import Image, ImageDraw, ImageFilter

ROOT = pathlib.Path(__file__).resolve().parents[2]
OUT = ROOT / "brand" / "badges"
SIZE = 512

# key: (sticker, disc top colour, disc bottom colour)
BADGES = {
    "welcome": ("Cartoon/egg", (80, 210, 120), (20, 130, 70)),
    "firstSteal": ("Pets/SoggyToast", (255, 170, 60), (200, 90, 20)),
    "firstHatch": ("Eggs/Golden", (255, 120, 190), (170, 30, 110)),
    "homeSafe": ("Cartoon/cart", (90, 170, 255), (30, 80, 190)),
    "speedDemon": ("Cartoon/shoe", (255, 90, 80), (170, 20, 40)),
    "reborn": ("Pets/TaxAngel", (255, 215, 70), (210, 140, 10)),
    "collector": ("Cartoon/book", (110, 140, 255), (50, 50, 170)),
    "bossEscape": ("Pets/FinalBossHamster", (230, 60, 70), (110, 10, 30)),
    "deepDiver": ("Pets/ZeusZucchini", (140, 210, 255), (60, 120, 220)),
    "trapSpringer": ("Cartoon/trap", (150, 160, 190), (60, 70, 100)),
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


def make(key: str):
    art, top, bottom = BADGES[key]
    img = disc(top, bottom)
    sticker = Image.open(ROOT / "art" / "ui" / f"{art}.png").convert("RGBA").resize((330, 330), Image.LANCZOS)
    img.alpha_composite(sticker, ((SIZE - 330) // 2, (SIZE - 330) // 2 + 6))
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
