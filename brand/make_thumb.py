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
    arrow(img, (900, 60), (1150, -10), (1130, 190))  # from the name to the egg
    bang(img, 330, 330, 70, 12)  # the guardian is not happy
    bang(img, 405, 322, 70, 12)
    outlined_text(img, (1355, 560), "YOU", 96, [(255, 255, 255), (255, 235, 80)], outline=12, horizontal=True)
    arrow(img, (1400, 690), (1380, 760), (1300, 735), width=22)  # YOU -> the avatar
    out = ROOT / "brand/thumb_1920x1080.png"
    img.convert("RGB").save(out)
    print("wrote", out)


def icon():
    img = punch(Image.open(ROOT / "art/renders/thumb_icon.png").convert("RGB")).convert("RGBA")
    outlined_text(img, (60, 835), "MEME EGG", 165, RAINBOW, outline=18, horizontal=True)
    out = ROOT / "brand/icon_512.png"
    img.convert("RGB").resize((512, 512), Image.Resampling.LANCZOS).save(out)
    print("wrote", out)


wide()
icon()
