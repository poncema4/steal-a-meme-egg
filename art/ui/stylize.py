"""Turns a plain transparent render into a bold sticker icon like the reference game's: cropped tight to the picture, scaled to fill
the frame, a thick dark outline, a little more colour, and a soft shadow underneath.
Usage: python3 art/ui/stylize.py in.png out.png [size=512]"""
import sys
from PIL import Image, ImageEnhance, ImageFilter, ImageChops

src, dst = sys.argv[1], sys.argv[2]
size = int(sys.argv[3]) if len(sys.argv) > 3 else 512
OUT = (24, 22, 34)

im = Image.open(src).convert("RGBA")
box = im.getchannel("A").point(lambda a: 255 if a > 8 else 0).getbbox()
im = im.crop(box)
margin = int(size * 0.09)
outline = max(6, size // 48)
inner = size - 2 * margin - 2 * outline
scale = inner / max(im.size)
im = im.resize((max(1, round(im.width * scale)), max(1, round(im.height * scale))), Image.LANCZOS)
rgb = ImageEnhance.Color(im.convert("RGB")).enhance(1.18)
rgb = ImageEnhance.Contrast(rgb).enhance(1.06)
alpha = im.getchannel("A")
sticker = Image.merge("RGBA", (*rgb.split(), alpha))

canvas = Image.new("RGBA", (size, size), (0, 0, 0, 0))
ox, oy = (size - sticker.width) // 2, (size - sticker.height) // 2 + margin // 3
# the outline: the alpha grown by `outline` pixels, filled dark
grown = alpha.filter(ImageFilter.MaxFilter(outline * 2 + 1))
ring = Image.new("RGBA", sticker.size, OUT + (0,))
ring.putalpha(grown)
pad = outline
wide = Image.new("RGBA", (sticker.width + 2 * pad, sticker.height + 2 * pad), (0, 0, 0, 0))
ring_big = Image.new("RGBA", wide.size, OUT + (0,))
mask = Image.new("L", wide.size, 0)
mask.paste(alpha, (pad, pad))
mask = mask.filter(ImageFilter.MaxFilter(outline * 2 + 1)).filter(ImageFilter.GaussianBlur(0.8))
ring_big.putalpha(mask)
# a soft shadow
shadow = Image.new("RGBA", wide.size, (0, 0, 0, 0))
shadow.putalpha(mask.point(lambda a: a // 3))
shadow = shadow.filter(ImageFilter.GaussianBlur(outline))
canvas.alpha_composite(shadow, (ox - pad, oy - pad + outline))
canvas.alpha_composite(ring_big, (ox - pad, oy - pad))
canvas.alpha_composite(sticker, (ox, oy))
canvas.save(dst)
