"""Drawing helpers shared by make_thumb.py and make_pass_icons.py (gradient text with outline, arrow, exclamation marks).
Originally: adds the trending-thumbnail text layer to the Blender render: a rainbow egg name with a heavy black outline, a green
income line, a red curved arrow and red '!!' marks (the grammar the top Roblox egg games share). Our own art; only the
layout idea is borrowed. Run: scripts/blender.sh art/blender/thumb.py && python3 brand/make_thumb.py
Outputs: brand/thumb_1920x1080.png (game thumbnail), brand/icon_512.png (game icon)."""
import math
import pathlib

from PIL import Image, ImageDraw, ImageEnhance, ImageFont

ROOT = pathlib.Path(__file__).parent.parent
FONT = "/usr/share/fonts/truetype/lato/Lato-Black.ttf"


def punch(img):
    img = ImageEnhance.Color(img).enhance(1.45)
    img = ImageEnhance.Contrast(img).enhance(1.12)
    return ImageEnhance.Brightness(img).enhance(0.96)


def gradient(size, stops, horizontal=False):
    """A gradient across a list of (r, g, b) stops: top-to-bottom, or left-to-right if horizontal."""
    w, h = size
    g = Image.new("RGB", size)
    px = g.load()
    n = len(stops) - 1
    length = w if horizontal else h
    for i in range(length):
        t = i / max(length - 1, 1) * n
        k = min(int(t), n - 1)
        f = t - k
        c = tuple(int(stops[k][j] * (1 - f) + stops[k + 1][j] * f) for j in range(3))
        for o in range(h if horizontal else w):
            if horizontal:
                px[i, o] = c
            else:
                px[o, i] = c
    return g


def outlined_text(img, xy, text, size, stops, outline=16, horizontal=False, shadow=10):
    font = ImageFont.truetype(FONT, size)
    box = ImageDraw.Draw(img).textbbox((0, 0), text, font=font, stroke_width=outline)
    w, h = box[2] - box[0] + 4, box[3] - box[1] + 4
    layer = Image.new("RGBA", (w + shadow, h + shadow), (0, 0, 0, 0))
    ld = ImageDraw.Draw(layer)
    ox, oy = outline - box[0], outline - box[1]
    ld.text((ox + shadow, oy + shadow), text, font=font, fill=(0, 0, 0, 150), stroke_width=outline, stroke_fill=(0, 0, 0, 150))
    ld.text((ox, oy), text, font=font, fill=(0, 0, 0, 255), stroke_width=outline, stroke_fill=(0, 0, 0, 255))
    mask = Image.new("L", layer.size, 0)
    ImageDraw.Draw(mask).text((ox, oy), text, font=font, fill=255)
    layer.paste(gradient(layer.size, stops, horizontal), (0, 0), mask)
    img.alpha_composite(layer, (int(xy[0]), int(xy[1])))
    return w, h


def bezier(p0, p1, p2, n=40):
    pts = []
    for i in range(n + 1):
        t = i / n
        pts.append(tuple((1 - t) ** 2 * p0[k] + 2 * (1 - t) * t * p1[k] + t * t * p2[k] for k in range(2)))
    return pts


def arrow(img, p0, p1, p2, width=34):
    d = ImageDraw.Draw(img)
    pts = bezier(p0, p1, p2)
    d.line(pts, fill=(0, 0, 0, 255), width=width + 18, joint="curve")
    d.line(pts, fill=(235, 30, 30, 255), width=width, joint="curve")
    (x1, y1), (x2, y2) = pts[-4], pts[-1]
    a = math.atan2(y2 - y1, x2 - x1)
    tip = (x2 + 38 * math.cos(a), y2 + 38 * math.sin(a))
    left = (x2 + 60 * math.cos(a + 2.4), y2 + 60 * math.sin(a + 2.4))
    right = (x2 + 60 * math.cos(a - 2.4), y2 + 60 * math.sin(a - 2.4))
    d.polygon([tip, left, right], fill=(0, 0, 0, 255))

    def inner(p):
        return (x2 + (p[0] - x2) * 0.72 + 3 * math.cos(a), y2 + (p[1] - y2) * 0.72 + 3 * math.sin(a))

    d.polygon([tip, inner(left), inner(right)], fill=(235, 30, 30, 255))


def bang(img, x, y, h, tilt):
    """A red exclamation mark with a black outline."""
    layer = Image.new("RGBA", (h * 2, h * 2), (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    w = h * 0.34
    cx = h
    for fill, grow in ((0, 12), (1, 0)):
        c = (235, 30, 30, 255) if fill else (0, 0, 0, 255)
        d.polygon([(cx - w / 2 - grow, 14 - grow), (cx + w / 2 + grow, 14 - grow), (cx + w / 4, h * 1.2 + grow), (cx - w / 4, h * 1.2 + grow)], fill=c)
        d.ellipse([cx - w / 2 - grow, h * 1.4 - grow, cx + w / 2 + grow, h * 1.4 + w + grow], fill=c)
    layer = layer.rotate(tilt, expand=True, resample=Image.Resampling.BICUBIC)
    img.alpha_composite(layer, (int(x), int(y)))


RAINBOW = [(255, 40, 60), (255, 150, 0), (255, 230, 0), (60, 220, 60), (0, 190, 255), (150, 80, 255)]
MONEY = [(190, 255, 120), (60, 215, 60), (20, 150, 40)]
