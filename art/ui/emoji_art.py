"""Loads one Noto Color Emoji picture (Google, Apache 2.0) as a cropped RGBA image, so the HUD, gamepass and badge art all use
the same professional artwork. Usage: from emoji_art import emoji; img = emoji("\\U0001F340")"""
from PIL import Image, ImageDraw, ImageFont

FONT = "/usr/share/fonts/truetype/noto/NotoColorEmoji.ttf"


def emoji(ch: str) -> Image.Image:
    font = ImageFont.truetype(FONT, 109)  # the bitmap emoji font only has this size
    im = Image.new("RGBA", (160, 160), (0, 0, 0, 0))
    ImageDraw.Draw(im).text((80, 80), ch, font=font, embedded_color=True, anchor="mm")
    return im.crop(im.getbbox())
