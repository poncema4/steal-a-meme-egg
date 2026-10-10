"""Adds the trending-thumbnail text layer to the Blender render: a rainbow egg name with a heavy black outline, a green
income line, a red curved arrow and red '!!' marks (the grammar the top Roblox egg games share). Our own art; only the
layout idea is borrowed. Run: scripts/blender.sh art/blender/thumb.py && python3 brand/make_thumb.py
Outputs: brand/thumb_1920x1080.png (game thumbnail), brand/icon_512.png (game icon)."""
import pathlib
import sys

from PIL import Image

sys.path.insert(0, str(pathlib.Path(__file__).parent))
from make_thumb_lib import MONEY, RAINBOW, arrow, bang, outlined_text, punch  # noqa: E402

ROOT = pathlib.Path(__file__).parent.parent



def wide():
    img = punch(Image.open(ROOT / "art/renders/thumb_wide.png").convert("RGB")).convert("RGBA")
    outlined_text(img, (46, 18), "MEME EGG", 150, RAINBOW, outline=14, horizontal=True)
    outlined_text(img, (52, 168), "$12,000,000/s", 84, MONEY, outline=11)
    arrow(img, (880, 70), (1090, 20), (1060, 215))
    bang(img, 120, 300, 70, 12)
    bang(img, 195, 292, 70, 12)
    out = ROOT / "brand/thumb_1920x1080.png"
    img.convert("RGB").save(out)
    print("wrote", out)


def icon():
    img = punch(Image.open(ROOT / "art/renders/thumb_icon.png").convert("RGB")).convert("RGBA")
    outlined_text(img, (60, 24), "MEME", 190, RAINBOW, outline=14, horizontal=True)
    outlined_text(img, (150, 212), "EGG", 190, RAINBOW[::-1], outline=14, horizontal=True)
    out = ROOT / "brand/icon_512.png"
    img.convert("RGB").resize((512, 512), Image.Resampling.LANCZOS).save(out)
    print("wrote", out)


wide()
icon()
