"""Smooth cartoon HUD icons in the Steal an Egg style (thick black outline, bright glossy fills, a white shine), drawn as vector
shapes at 4x and scaled down so the edges are clean. Usage: python3 art/ui/cartoon_icons.py [names]  -> art/ui/Cartoon/<name>.png
These replace the voxel sticker renders for the HUD and shop icons; the meme characters keep their own pictures."""
import math
import pathlib
import sys

from PIL import Image, ImageDraw, ImageFilter

ROOT = pathlib.Path(__file__).resolve().parents[2]
OUT = ROOT / "art" / "ui" / "Cartoon"
S = 4  # supersampling
SIZE = 256
INK = (20, 18, 28, 255)
LINE = 14 * S  # outline width


def canvas():
    return Image.new("RGBA", (SIZE * S, SIZE * S), (0, 0, 0, 0))


def P(points):
    return [(x * S, y * S) for x, y in points]


def B(box):
    return tuple(v * S for v in box)


def shade(c, k):
    return tuple(max(0, min(255, int(v * k))) for v in c[:3]) + (255,)


def blob(img, draw_fn, fill, shine=True):
    """Draws a shape twice: a fat black version (the outline) then the coloured version on top, with a soft top shine."""
    ink = Image.new("RGBA", img.size, (0, 0, 0, 0))
    draw_fn(ImageDraw.Draw(ink), INK, LINE)
    img.alpha_composite(ink)
    body = Image.new("RGBA", img.size, (0, 0, 0, 0))
    draw_fn(ImageDraw.Draw(body), fill, 0)
    # vertical gradient: lighter at the top, darker at the bottom
    mask = body.split()[3]
    bbox = mask.getbbox()
    if bbox:
        grad = Image.new("RGBA", img.size, (0, 0, 0, 0))
        gd = ImageDraw.Draw(grad)
        top, bottom = bbox[1], bbox[3]
        for y in range(top, bottom):
            f = (y - top) / max(bottom - top, 1)
            gd.line([(bbox[0], y), (bbox[2], y)], fill=shade(fill, 1.18 - 0.38 * f))
        body = Image.composite(grad, Image.new("RGBA", img.size, (0, 0, 0, 0)), mask)
        img.alpha_composite(body)
        if shine:
            sh = Image.new("RGBA", img.size, (0, 0, 0, 0))
            w, h = bbox[2] - bbox[0], bbox[3] - bbox[1]
            ImageDraw.Draw(sh).ellipse(
                (bbox[0] + w * 0.16, bbox[1] + h * 0.08, bbox[0] + w * 0.55, bbox[1] + h * 0.30), fill=(255, 255, 255, 120)
            )
            sh = Image.composite(sh, Image.new("RGBA", img.size, (0, 0, 0, 0)), mask)
            img.alpha_composite(sh.filter(ImageFilter.GaussianBlur(3 * S)))


def poly(points):
    def f(d, fill, w):
        d.polygon(P(points), fill=fill)
        if w:
            d.line(P(points + points[:1]), fill=fill, width=w, joint="curve")
            for x, y in points:
                d.ellipse((x * S - w / 2, y * S - w / 2, x * S + w / 2, y * S + w / 2), fill=fill)
    return f


def ell(box):
    def f(d, fill, w):
        x0, y0, x1, y1 = B(box)
        d.ellipse((x0 - w / 2, y0 - w / 2, x1 + w / 2, y1 + w / 2), fill=fill)
    return f


def rrect(box, r):
    def f(d, fill, w):
        x0, y0, x1, y1 = B(box)
        d.rounded_rectangle((x0 - w / 2, y0 - w / 2, x1 + w / 2, y1 + w / 2), radius=r * S + w / 2, fill=fill)
    return f


def thick(points, width):
    def f(d, fill, w):
        d.line(P(points), fill=fill, width=int(width * S + w), joint="curve")
        for x, y in (points[0], points[-1]):
            r = (width * S + w) / 2
            d.ellipse((x * S - r, y * S - r, x * S + r, y * S + r), fill=fill)
    return f


def egg(img):
    blob(img, ell((58, 30, 198, 226)), (255, 120, 200))
    for (x, y, r, c) in ((100, 90, 14, (255, 230, 90)), (150, 130, 18, (120, 220, 255)), (96, 160, 12, (130, 240, 130)), (150, 190, 10, (255, 230, 90))):
        blob(img, ell((x - r, y - r, x + r, y + r)), c, shine=False)


def paw(img):
    blob(img, ell((62, 112, 194, 222)), (255, 170, 60))
    for (x, y) in ((70, 80), (108, 52), (148, 52), (186, 80)):
        blob(img, ell((x - 24, y - 26, x + 24, y + 26)), (255, 170, 60))


def trophy(img):
    blob(img, thick([(70, 70), (40, 90), (60, 130), (92, 132)], 14), (255, 200, 40), shine=False)
    blob(img, thick([(186, 70), (216, 90), (196, 130), (164, 132)], 14), (255, 200, 40), shine=False)
    blob(img, poly([(68, 46), (188, 46), (176, 130), (150, 160), (106, 160), (80, 130)]), (255, 200, 40))
    blob(img, rrect((112, 158, 144, 192), 6), (230, 160, 30), shine=False)
    blob(img, rrect((74, 190, 182, 222), 10), (150, 90, 50))


def cart(img):
    blob(img, thick([(26, 60), (60, 60), (82, 164), (196, 164)], 12), (90, 95, 115), shine=False)
    blob(img, poly([(64, 78), (222, 78), (204, 150), (82, 150)]), (240, 60, 70))
    for x in (100, 180):
        blob(img, ell((x - 20, 170, x + 20, 210)), (60, 60, 75), shine=False)


def book(img):
    blob(img, rrect((52, 34, 206, 222), 16), (60, 140, 255))
    blob(img, rrect((62, 44, 84, 212), 8), (30, 90, 200), shine=False)
    blob(img, ell((112, 92, 172, 152)), (255, 210, 60), shine=False)


def shoe(img):
    blob(img, poly([(40, 112), (110, 112), (140, 70), (176, 76), (180, 140), (222, 158), (222, 190), (40, 190)]), (70, 140, 255))
    blob(img, rrect((32, 182, 230, 214), 14), (245, 245, 250), shine=False)
    blob(img, thick([(124, 120), (170, 150)], 8), (255, 70, 70), shine=False)


def cash(img):
    blob(img, rrect((30, 92, 226, 196), 14), (60, 190, 90))
    blob(img, rrect((30, 64, 226, 168), 14), (90, 220, 110))
    blob(img, ell((104, 92, 152, 140)), (40, 150, 70), shine=False)
    blob(img, rrect((112, 58, 144, 174), 6), (255, 210, 60), shine=False)


def clock(img):
    for x in (68, 188):
        blob(img, ell((x - 28, 34, x + 28, 90)), (240, 60, 70), shine=False)
    blob(img, ell((36, 52, 220, 236)), (240, 60, 70))
    blob(img, ell((60, 76, 196, 212)), (255, 255, 255), shine=False)
    blob(img, thick([(128, 144), (128, 100)], 10), (30, 30, 40), shine=False)
    blob(img, thick([(128, 144), (160, 144)], 10), (30, 30, 40), shine=False)


def potion(img):
    blob(img, rrect((106, 30, 150, 82), 8), (170, 110, 70), shine=False)
    blob(img, ell((48, 70, 208, 230)), (100, 230, 120))
    blob(img, ell((84, 104, 112, 132)), (200, 255, 210), shine=False)


def trap(img):
    blob(img, ell((26, 112, 230, 214)), (110, 115, 135), shine=False)
    blob(img, ell((54, 124, 202, 202)), (70, 72, 88), shine=False)
    for i in range(9):
        a = math.pi * (0.08 + 0.84 * i / 8)
        x, y = 128 - math.cos(a) * 92, 160 - math.sin(a) * 46
        blob(img, poly([(x - 9, y + 6), (x + 9, y + 6), (x, y - 26)]), (245, 245, 250), shine=False)
    blob(img, ell((102, 146, 154, 178)), (255, 210, 40), shine=False)


def bat(img):
    # a baseball bat: a thin taped handle with a knob, widening into a thick barrel
    blob(img, thick([(58, 204), (112, 150)], 20), (200, 140, 80), shine=False)
    blob(img, poly([(100, 150), (178, 48), (214, 70), (226, 96), (124, 172)]), (215, 150, 85))
    blob(img, ell((176, 44, 230, 98)), (215, 150, 85), shine=False)
    blob(img, thick([(64, 198), (92, 170)], 22), (230, 60, 60), shine=False)
    blob(img, ell((36, 196, 70, 230)), (60, 40, 40), shine=False)


RECIPES = {"egg": egg, "paw": paw, "trophy": trophy, "cart": cart, "book": book, "shoe": shoe, "cash": cash, "clock": clock,
           "potion": potion, "trap": trap, "bat": bat}


def make(name):
    img = canvas()
    RECIPES[name](img)
    OUT.mkdir(parents=True, exist_ok=True)
    img.resize((SIZE, SIZE), Image.LANCZOS).save(OUT / f"{name}.png")


if __name__ == "__main__":
    names = sys.argv[1:] or list(RECIPES)
    for n in names:
        make(n)
    sheet = Image.new("RGBA", (128 * len(names), 128), (60, 60, 70, 255))
    for i, n in enumerate(names):
        sheet.alpha_composite(Image.open(OUT / f"{n}.png").resize((128, 128)), (128 * i, 0))
    sheet.save("/home/poncema4/testflight/screenshots/cartoon_icons.png")
    print("wrote", len(names))
