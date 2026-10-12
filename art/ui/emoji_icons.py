"""HUD icons from Google's Noto Color Emoji (Apache License 2.0, free for any use): professional, glossy artwork like the
Steal an Egg HUD, instead of hand-drawn shapes. The Shop and Index icons are white silhouettes with a black outline, exactly like
the reference's cart and book. Usage: python3 art/ui/emoji_icons.py  -> art/ui/Emoji/<name>.png (256 px)"""
import pathlib

from PIL import Image, ImageDraw, ImageFilter, ImageFont

ROOT = pathlib.Path(__file__).resolve().parents[2]
OUT = ROOT / "art" / "ui" / "Emoji"
FONT = "/usr/share/fonts/truetype/noto/NotoColorEmoji.ttf"

# name: (emoji, style) - "color" keeps the artwork, "white" makes a white silhouette with a black outline
ICONS = {
    "egg": ("\U0001F95A", "color"),
    "paw": ("\U0001F43E", "color"),
    "trophy": ("\U0001F3C6", "color"),
    "shoe": ("\U0001F45F", "color"),
    "cash": ("\U0001F4B5", "color"),
    "clock": ("⏰", "color"),
    "potion": ("\U0001F9EA", "color"),
    "cart": ("\U0001F6D2", "white"),
    "book": ("\U0001F4D6", "white"),
}


def glyph(ch: str) -> Image.Image:
    font = ImageFont.truetype(FONT, 109)  # the bitmap emoji font only has this size
    im = Image.new("RGBA", (160, 160), (0, 0, 0, 0))
    ImageDraw.Draw(im).text((80, 80), ch, font=font, embedded_color=True, anchor="mm")
    return im.crop(im.getbbox())


def one_paw(art: Image.Image) -> Image.Image:
    """Noto's paw is two prints; Steal an Egg shows one orange print: keep the lower-right print and turn it orange."""
    w, h = art.size
    art = art.crop((int(w * 0.47), int(h * 0.47), w, h))
    px = art.load()
    for y in range(art.height):
        for x in range(art.width):
            r, g, b, a = px[x, y]
            if a and b > r + 20:  # the blue becomes orange, keeping its shading
                lum = (r + g + b) / 3 / 255
                px[x, y] = (min(255, int(255 * (0.55 + lum))), min(255, int(150 * (0.55 + lum))), int(40 * lum), a)
    return art.crop(art.getbbox())


def outline(mask: Image.Image, width: int) -> Image.Image:
    return mask.filter(ImageFilter.MaxFilter(width * 2 + 1))


def make(name: str, ch: str, style: str):
    art = glyph(ch)
    if name == "paw":
        art = one_paw(art)
    # fit into 224 px, centred on a 256 canvas with room for the outline
    scale = 216 / max(art.size)
    art = art.resize((max(1, int(art.width * scale)), max(1, int(art.height * scale))), Image.LANCZOS)
    canvas = Image.new("RGBA", (256, 256), (0, 0, 0, 0))
    at = ((256 - art.width) // 2, (256 - art.height) // 2)
    alpha = Image.new("L", (256, 256), 0)
    alpha.paste(art.split()[3], at)
    hard = alpha.point(lambda v: 255 if v > 90 else 0)
    ring = outline(hard, 9).filter(ImageFilter.GaussianBlur(1))
    black = Image.new("RGBA", (256, 256), (16, 14, 22, 255))
    canvas.paste(black, (0, 0), ring)
    if style == "white":
        # white like the reference's cart and book, but the artwork's own dark lines stay as black detail inside it
        placed = Image.new("RGBA", (256, 256), (0, 0, 0, 0))
        placed.alpha_composite(art, at)
        gray = placed.convert("L")
        detail = gray.point(lambda v: 255 if v < 120 else 0)
        white = Image.new("RGBA", (256, 256), (255, 255, 255, 255))
        canvas.paste(white, (0, 0), alpha.filter(ImageFilter.GaussianBlur(0.6)))
        canvas.paste(black, (0, 0), Image.composite(detail, Image.new("L", (256, 256), 0), alpha))
    else:
        canvas.alpha_composite(art, at)
    OUT.mkdir(parents=True, exist_ok=True)
    canvas.save(OUT / f"{name}.png")


if __name__ == "__main__":
    for name, (ch, style) in ICONS.items():
        make(name, ch, style)
    names = list(ICONS)
    sheet = Image.new("RGBA", (128 * len(names), 128), (90, 170, 60, 255))
    for i, n in enumerate(names):
        sheet.alpha_composite(Image.open(OUT / f"{n}.png").resize((128, 128), Image.LANCZOS), (128 * i, 0))
    sheet.save("/home/poncema4/testflight/screenshots/emoji_icons.png")
    print("wrote", len(names))
