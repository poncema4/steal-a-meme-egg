"""The 27 characters as brick models (about 5 to 6 studs tall, fronts toward -Z). Each is a recipe: a body, a face and accessories,
built from flat-coloured voxels with a few shades so it reads as a chunky toy. Designs follow art/blender/pets.py (the portraits)."""
import math
from kit import Grid, rgb, shade

U = 0.3
BLACK, WHITE = rgb("16161c"), rgb("ffffff")
GOLD, RED = rgb("ffc21a"), rgb("e8262a")


# ------------------------------------------------------------------ faces
def eyes(g, y, z, spread=0.7, style="happy", size=0.5):
    for s in (-1, 1):
        x = s * spread
        if style == "sleepy":
            g.box((x, y, z), (size * 1.5, size * 0.3, 0.3), BLACK)
        elif style == "star":
            g.box((x, y, z), (size * 1.2, size * 1.2, 0.3), rgb("ffe44a"))
            g.box((x, y, z - 0.15), (size * 0.5, size * 0.5, 0.3), WHITE)
        elif style == "dizzy":
            g.torus((x, y, z), size * 0.55, size * 0.2, BLACK, axis="z")
        elif style == "shades":
            pass
        else:
            g.box((x, y, z), (size, size * 1.25, 0.3), BLACK)
            g.box((x + s * -0.04, y + size * 0.3, z - 0.15), (size * 0.4, size * 0.4, 0.3), WHITE)
    if style == "shades":
        g.box((0, y, z), (spread * 2 + size * 1.7, size * 1.0, 0.34), BLACK)
        g.box((0, y + size * 0.6, z - 0.1), (spread * 2 + size * 1.9, size * 0.22, 0.3), BLACK)
        for s in (-1, 1):
            g.box((s * spread - 0.05, y + size * 0.2, z - 0.18), (size * 0.5, size * 0.22, 0.2), rgb("6a6a88"))
    if style == "angry":
        for s in (-1, 1):
            g.box((s * spread, y + size * 1.0, z - 0.05), (size * 1.5, size * 0.3, 0.3), BLACK)
            g.box((s * spread + s * size * 0.55, y + size * 0.78, z - 0.05), (size * 0.6, size * 0.3, 0.3), BLACK)


def smile(g, y, z, w=1.1, color=BLACK):
    g.box((0, y, z), (w, 0.2, 0.3), color)
    g.box((-w / 2 - 0.1, y + 0.18, z), (0.2, 0.2, 0.3), color)
    g.box((w / 2 + 0.1, y + 0.18, z), (0.2, 0.2, 0.3), color)


def frown(g, y, z, w=1.0):
    g.box((0, y, z), (w, 0.2, 0.3), BLACK)
    g.box((-w / 2 - 0.1, y - 0.18, z), (0.2, 0.2, 0.3), BLACK)
    g.box((w / 2 + 0.1, y - 0.18, z), (0.2, 0.2, 0.3), BLACK)


# ------------------------------------------------------------------ accessories (top = y of the top of the head)
def crown(g, top, color=GOLD, gem=RED):
    g.cylinder((0, top + 0.15, 0), 1.0, 0.3, color)
    for k in range(5):
        a = k * math.tau / 5
        g.cone((math.cos(a) * 0.85, top + 0.62, math.sin(a) * 0.85), 0.2, 0.0, 0.7, color)
    g.box((0, top + 0.15, -1.0), (0.26, 0.26, 0.2), gem)


def halo(g, top, color=rgb("fff3a0")):
    g.torus((0, top + 0.75, 0), 0.95, 0.14, color, axis="y")


def horns(g, top, spread=0.95, color=rgb("f2efe0")):
    for s in (-1, 1):
        g.cone((s * spread, top + 0.15, 0), 0.32, 0.0, 1.1, color)


def cat_ears(g, top, spread=0.85, color=rgb("e0a060"), inner=rgb("ffb5c0")):
    for s in (-1, 1):
        g.cone((s * spread, top + 0.05, 0.1), 0.52, 0.0, 0.95, color)
        g.cone((s * spread, top + 0.0, -0.05), 0.28, 0.0, 0.6, inner)


def dog_ears(g, top, spread=1.5, color=rgb("a8743a")):
    for s in (-1, 1):
        g.ellipsoid((s * spread, top - 0.7, 0), (0.35, 0.8, 0.5), color)


def antennae(g, top, color=BLACK, tip=rgb("ffdd55")):
    for s in (-1, 1):
        g.cylinder((s * 0.45, top + 0.55, 0), 0.07, 1.1, color)
        g.ellipsoid((s * 0.6, top + 1.15, 0), (0.18, 0.18, 0.18), tip)


def stars_around(g, y, radius=1.9, n=6):
    for k in range(n):
        a = k * math.tau / n
        g.ellipsoid((math.cos(a) * radius, y + math.sin(a) * 0.45, math.sin(a) * radius * 0.6), (0.2, 0.2, 0.2), rgb("ffe44a"))


def flame(g, top, scale=1.0):
    for k, (dx, h, c) in enumerate(((-0.45, 1.0, rgb("ff7a1a")), (0.0, 1.45, rgb("ffb21e")), (0.45, 0.85, rgb("ff5a14")))):
        g.cone((dx, top + h * scale / 2, 0), 0.38, 0.0, h * scale, c)


def disco(g, top):
    g.ellipsoid((0, top + 0.65, 0), (0.7, 0.7, 0.7), rgb("cfd8e8"))
    for k in range(10):
        a = k * math.tau / 10
        g.box((math.cos(a) * 0.65, top + 0.65 + 0.25 * math.sin(k * 1.7), math.sin(a) * 0.65), (0.2, 0.2, 0.2), rgb("ff5fcf") if k % 2 else rgb("5fd8ff"))
    g.cylinder((0, top + 0.1, 0), 0.12, 0.3, rgb("8a8a99"))


def steam(g, top):
    for k in range(3):
        g.ellipsoid((math.sin(k * 2) * 0.35, top + 0.5 + k * 0.5, 0), (0.22 + 0.05 * k,) * 3, rgb("f1f4ff"))


def wings_side(g, y, spread, color, w=0.45, h=1.8, d=1.3):
    for s in (-1, 1):
        g.ellipsoid((s * spread, y, 0.15), (w, h / 2, d / 2), color)


def blob_body(g, c, r, color, belly=None):
    g.ellipsoid(c, r, color)
    if belly:
        g.ellipsoid((c[0], c[1] - r[1] * 0.25, c[2] - r[2] * 0.45), (r[0] * 0.62, r[1] * 0.55, r[2] * 0.4), belly)


def feet(g, spread=0.9, color=rgb("ff8a1e"), z=-0.2, y=0.15):
    for s in (-1, 1):
        g.box((s * spread, y, z), (0.8, 0.3, 1.1), color)


# ------------------------------------------------------------------ the recipes
def soggy_toast(g):
    crust, face = rgb("a86a2c"), rgb("f3dfaa")
    g.box((0, 1.95, 0), (3.0, 3.3, 0.9), crust)
    g.ellipsoid((-0.9, 3.75, 0), (1.0, 0.65, 0.45), crust)
    g.ellipsoid((0.9, 3.75, 0), (1.0, 0.65, 0.45), crust)
    g.box((0, 1.95, -0.55), (2.5, 2.8, 0.35), face)
    eyes(g, 2.3, -0.8, 0.65, "sleepy")
    frown(g, 1.5, -0.8, 0.8)
    for x in (-0.9, 0.75):
        g.ellipsoid((x, 0.8, -0.82), (0.16, 0.24, 0.1), rgb("6ab8ff"))  # drips
    g.box((0, 0.1, -0.3), (2.6, 0.2, 1.8), rgb("9ed2ff"))  # a puddle
    steam(g, 3.95)
    return 4.6


def bonk_bean(g):
    body, lump = rgb("8a3a22"), rgb("c47a58")
    blob_body(g, (0, 1.5, 0), (1.9, 1.4, 1.5), body)
    g.ellipsoid((0.9, 2.55, -0.2), (0.5, 0.45, 0.4), lump)
    eyes(g, 1.65, -1.45, 0.6, "dizzy")
    frown(g, 0.95, -1.45, 0.5)
    stars_around(g, 3.1, 1.2, 5)
    feet(g, 0.8, rgb("5a2412"), -0.4, 0.15)
    return 3.5


def sleepy_sock(g):
    c, stripe = rgb("f4f4ff"), rgb("8a5ae0")
    g.cylinder((0, 3.0, 0), 1.0, 3.0, c)
    g.ellipsoid((0, 1.35, 0.1), (1.0, 1.1, 1.2), c)
    g.box((0, 0.6, -1.0), (2.0, 1.2, 2.0), c)
    g.ellipsoid((0, 0.8, -1.9), (1.0, 0.7, 0.5), c)
    for y in (4.3, 3.85):
        g.cylinder((0, y, 0), 1.03, 0.28, stripe)
    eyes(g, 3.1, -1.0, 0.45, "sleepy", 0.4)
    g.ellipsoid((0, 2.5, -1.02), (0.18, 0.12, 0.1), rgb("ff9ab0"))
    return 4.6


def disco_pickle(g):
    g1, g2 = rgb("5cb83a"), rgb("3f8f28")
    g.cylinder((0, 2.1, 0), 1.05, 3.4, g1)
    g.ellipsoid((0, 3.8, 0), (1.05, 0.7, 1.05), g1)
    g.ellipsoid((0, 0.7, 0), (1.05, 0.7, 1.05), g1)
    for k, (x, y) in enumerate(((-0.6, 1.3), (0.5, 2.6), (-0.4, 3.3), (0.7, 0.9))):
        g.ellipsoid((x, y, -0.98), (0.12, 0.12, 0.12), g2)
    eyes(g, 2.9, -1.0, 0.5, "shades", 0.42)
    smile(g, 2.0, -1.02, 0.8)
    disco(g, 4.3)
    return 5.7


def gigachad_goose(g, body=rgb("f6f6fb"), beak=rgb("ff8a1e"), style="shades"):
    g.ellipsoid((0, 1.6, 0.2), (1.9, 1.5, 1.7), body)
    g.cylinder((0, 3.4, -0.2), 0.62, 1.7, body)
    g.ellipsoid((0, 4.5, -0.3), (1.0, 0.95, 1.0), body)
    g.cone((0, 4.4, -1.55), 0.55, 0.1, 1.2, beak, axis="z")
    g.box((0, 4.1, -1.25), (0.9, 0.18, 0.7), shade(beak, 0.8))
    eyes(g, 4.75, -1.2, 0.62, style, 0.34)
    for s in (-1, 1):
        g.ellipsoid((s * 1.95, 1.7, 0.2), (0.35, 0.95, 1.2), shade(body, 0.9))
    feet(g, 0.7, beak, -0.2, 0.15)
    return 5.4


def moonwalk_moth(g):
    body, wing, mark = rgb("7a5ad0"), rgb("ffd84a"), rgb("fff2b0")
    g.ellipsoid((0, 2.2, 0), (0.85, 1.9, 0.85), body)
    g.ellipsoid((0, 3.9, -0.1), (0.7, 0.7, 0.7), body)
    for s in (-1, 1):
        g.ellipsoid((s * 2.2, 2.9, 0.1), (1.6, 1.8, 0.22), wing)
        g.ellipsoid((s * 1.7, 1.2, 0.1), (1.2, 1.2, 0.2), shade(wing, 0.9))
        g.ellipsoid((s * 2.4, 3.2, -0.12), (0.45, 0.45, 0.1), mark)
        g.ellipsoid((s * 1.9, 1.3, -0.12), (0.35, 0.35, 0.1), mark)
    eyes(g, 4.0, -0.75, 0.3, "star", 0.34)
    antennae(g, 4.4)
    return 5.8


def chili_chihuahua(g):
    fur, light = rgb("d8a868"), rgb("f2d8ac")
    blob_body(g, (0, 1.75, 0), (1.9, 1.6, 1.7), fur, light)
    dog_ears(g, 3.1, 1.5, rgb("b88848"))
    eyes(g, 2.0, -1.62, 0.75, "angry", 0.4)
    g.ellipsoid((0, 1.35, -1.75), (0.45, 0.35, 0.3), BLACK)
    g.box((0, 0.95, -1.7), (0.7, 0.2, 0.3), rgb("ff8a8a"))
    # a red chili hat
    g.cone((0.1, 3.9, 0), 0.5, 0.0, 1.5, RED)
    g.box((-0.15, 4.65, 0), (0.2, 0.3, 0.2), rgb("3fa83a"))
    feet(g, 0.9, light, -0.5, 0.15)
    return 4.8


def lava_latte(g):
    cup, foam, lava = rgb("7a4a28"), rgb("f2e0c0"), rgb("ff6a1a")
    g.cone((0, 1.4, 0), 1.2, 1.55, 2.8, cup)
    g.cylinder((0, 2.9, 0), 1.55, 0.35, rgb("f0f0f0"))
    g.ellipsoid((0, 3.1, 0), (1.35, 0.35, 1.35), foam)
    g.ellipsoid((0.4, 3.35, -0.2), (0.5, 0.2, 0.4), lava)
    g.torus((1.9, 1.5, 0), 0.62, 0.22, cup, axis="z")
    eyes(g, 1.7, -1.4, 0.55, "happy", 0.4)
    smile(g, 0.95, -1.42, 0.7)
    steam(g, 3.4)
    return 5.0


def volcano_vicar(g):
    rock, lavac = rgb("6a4c40"), rgb("ff6a1a")
    g.cone((0, 1.6, 0), 2.4, 0.9, 3.2, rock)
    g.ellipsoid((0, 3.35, 0), (1.0, 0.5, 1.0), lavac)
    g.box((0, 2.9, -1.25), (1.6, 0.4, 0.5), WHITE)  # a vicar's collar
    g.box((0, 2.9, -1.4), (0.35, 0.45, 0.3), BLACK)
    eyes(g, 1.9, -1.55, 0.7, "angry", 0.42)
    frown(g, 1.0, -1.75, 0.8)
    flame(g, 3.7)
    return 5.5


def pharaoh_pancake(g):
    cake, dark = rgb("e8a848"), rgb("c47e24")
    for i in range(4):
        g.cylinder((0, 0.4 + i * 0.62, 0), 1.9 - 0.04 * i, 0.58, cake if i % 2 == 0 else dark)
    g.cylinder((0, 2.95, 0), 1.7, 0.3, rgb("7a3a14"))  # syrup
    eyes(g, 1.4, -1.9, 0.7, "happy", 0.4)
    smile(g, 0.7, -1.9, 0.7)
    # the striped pharaoh headdress
    for s in (-1, 1):
        g.box((s * 2.0, 1.6, -0.2), (0.6, 2.4, 1.2), rgb("2f6cff"))
        g.box((s * 2.0, 2.0, -0.82), (0.6, 0.3, 0.1), GOLD)
    g.box((0, 3.35, 0), (3.6, 0.6, 2.8), GOLD)
    g.box((0, 3.8, -0.3), (2.6, 0.4, 1.6), rgb("2f6cff"))
    g.box((0, 3.45, -1.45), (0.5, 0.5, 0.3), RED)
    return 4.4


def sphinx_sneaker(g):
    shoe, sole, lace = rgb("e0b24a"), rgb("fafafa"), rgb("2f6cff")
    g.box((0, 0.35, 0), (2.4, 0.6, 3.6), sole)
    g.box((0, 1.3, 0.3), (2.2, 1.5, 2.6), shoe)
    g.ellipsoid((0, 1.0, -1.7), (1.1, 0.8, 0.8), shoe)
    g.box((0, 2.5, 0.8), (1.8, 1.4, 1.2), shoe)
    g.box((0, 2.1, -0.4), (1.5, 0.35, 1.0), lace)
    for z in (-0.8, -0.2, 0.4):
        g.box((0, 2.0, z), (1.6, 0.14, 0.14), WHITE)
    # the sphinx headdress
    g.box((0, 3.4, 0.8), (2.6, 0.5, 1.8), GOLD)
    for s in (-1, 1):
        g.box((s * 1.4, 2.7, 0.8), (0.5, 1.6, 1.2), rgb("2f6cff"))
    eyes(g, 2.55, -1.55, 0.55, "shades", 0.4)
    return 4.0


def cleo_croissant(g):
    c, d = rgb("e8a444"), rgb("c47a28")
    for x, y, r in ((-1.9, 1.0, 0.7), (-1.35, 1.9, 0.95), (-0.35, 2.4, 1.15), (0.75, 2.4, 1.1), (1.55, 1.8, 0.9), (1.95, 0.95, 0.65)):
        g.ellipsoid((x, y, 0), (r, r, r * 0.95), c)
    for x, y in ((-0.9, 2.5), (0.2, 3.0), (1.1, 2.6)):
        g.box((x, y, -1.0), (0.12, 0.7, 0.1), d)
    eyes(g, 2.5, -1.12, 0.45, "happy", 0.38)
    g.box((-0.45, 2.2, -1.12), (0.5, 0.1, 0.1), rgb("2f6cff"))  # eye makeup
    g.box((0.45, 2.2, -1.12), (0.5, 0.1, 0.1), rgb("2f6cff"))
    smile(g, 1.85, -1.12, 0.5)
    crown(g, 3.5, GOLD)
    return 4.5


def nebula_noodle(g):
    n1, n2 = rgb("b86cff"), rgb("ff8ad8")
    g.torus((0, 2.7, 0), 1.8, 0.65, n1, axis="z")
    g.torus((0, 2.7, -0.2), 1.8, 0.2, n2, axis="z")
    eyes(g, 2.7, -0.75, 0.45, "star", 0.4)
    stars_around(g, 2.7, 2.3, 7)
    return 5.1


def quasar_quokka(g):
    fur, light = rgb("b88850"), rgb("f2d8b0")
    blob_body(g, (0, 1.7, 0), (1.9, 1.6, 1.6), fur, light)
    cat_ears(g, 3.1, 1.0, fur, rgb("ffb0b8"))
    eyes(g, 2.0, -1.55, 0.7, "happy", 0.4)
    g.ellipsoid((0, 1.5, -1.6), (0.4, 0.3, 0.3), BLACK)
    smile(g, 1.05, -1.55, 1.0)
    g.torus((0, 2.7, 1.2), 2.2, 0.12, rgb("8fd4ff"), axis="z")
    feet(g, 0.9, light, -0.5, 0.15)
    return 4.7


def black_hole_bagel(g):
    g.torus((0, 2.9, 0), 1.7, 0.8, rgb("17122b"), axis="z")
    g.torus((0, 2.9, -0.3), 1.7, 0.24, rgb("8a4aff"), axis="z")
    g.torus((0, 2.9, 0.2), 2.5, 0.12, rgb("ff6adf"), axis="z")
    eyes(g, 2.9, -0.82, 0.5, "star", 0.4)
    return 5.4


def tax_angel(g):
    body = rgb("f8f8ff")
    g.egg((0, 2.0, 0), 1.7, 3.6, body)
    wings_side(g, 2.3, 2.1, rgb("fff0b0"), 0.45, 2.4, 1.4)
    eyes(g, 2.5, -1.55, 0.6, "happy", 0.4)
    smile(g, 1.6, -1.55, 0.8)
    halo(g, 3.7)
    g.box((1.7, 1.4, -1.0), (1.0, 1.3, 0.12), rgb("fdfdf0"))  # the paperwork
    g.box((1.7, 1.55, -1.08), (0.7, 0.08, 0.05), BLACK)
    g.box((1.7, 1.25, -1.08), (0.7, 0.08, 0.05), BLACK)
    return 4.6


def final_boss_hamster(g):
    fur, light = rgb("e89a3a"), rgb("fff0cc")
    blob_body(g, (0, 1.8, 0), (2.0, 1.7, 1.8), fur, light)
    horns(g, 3.2, 1.1)
    cat_ears(g, 3.1, 1.6, fur, rgb("ffb0b8"))
    eyes(g, 2.1, -1.75, 0.75, "angry", 0.42)
    g.box((0, 1.4, -1.8), (0.4, 0.3, 0.2), rgb("ff8a8a"))
    g.box((0, 0.9, -1.75), (0.3, 0.5, 0.2), WHITE)
    g.box((0, 0.2, 0.8), (2.6, 0.2, 0.2), rgb("7a1018"))
    return 5.0


def omega_meme(g):
    body = rgb("7a2ad0")
    g.egg((0, 2.1, 0), 1.9, 4.0, body)
    eyes(g, 2.7, -1.75, 0.7, "shades", 0.45)
    smile(g, 1.7, -1.75, 0.9, rgb("ffd84a"))
    crown(g, 4.0, GOLD)
    g.torus((0, 2.9, 1.0), 2.4, 0.14, rgb("ff5ad8"), axis="z")
    return 5.0


def goose_variant(body, beak, style, extras):
    def f(g):
        top = gigachad_goose(g, body, beak, style)
        extras(g, top)
        return top
    return f


def golden_goose(g):
    return goose_variant(rgb("ffc828"), rgb("ff7a1a"), "happy", lambda g, t: g.box((-0.45, 4.9, -1.2), (0.25, 0.7, 0.2), rgb("fff2a0")))(g)


def platinum_goose(g):
    return goose_variant(rgb("c4d2e8"), rgb("8aa0c0"), "shades", lambda g, t: crown(g, t - 0.3, rgb("e8eef8"), rgb("62a8ff")))(g)


def mythic_goose(g):
    def extra(g, t):
        halo(g, t - 0.3)
        wings_side(g, 2.7, 2.8, rgb("ffe066"), 0.4, 2.6, 1.4)
    return goose_variant(rgb("ff6ad8"), rgb("ffd84a"), "star", extra)(g)


def cat_base(g, fur, belly, style, ears_inner=rgb("ffb0b8")):
    blob_body(g, (0, 1.75, 0), (1.9, 1.6, 1.6), fur, belly)
    cat_ears(g, 3.1, 1.0, fur, ears_inner)
    eyes(g, 2.05, -1.55, 0.7, style, 0.4)
    g.box((0, 1.5, -1.62), (0.3, 0.22, 0.2), rgb("ff8a9a"))
    g.box((-0.3, 1.2, -1.6), (0.6, 0.1, 0.2), BLACK)
    g.box((0.3, 1.2, -1.6), (0.6, 0.1, 0.2), BLACK)
    for s in (-1, 1):
        for k in (0, 1):
            g.box((s * 1.9, 1.4 - k * 0.3, -1.1), (0.7, 0.07, 0.07), WHITE)
    feet(g, 0.9, belly, -0.5, 0.15)
    return 4.9


def cosmic_kitten(g):
    t = cat_base(g, rgb("6a74f0"), rgb("d8dcff"), "happy")
    stars_around(g, 3.2, 1.8, 6)
    return t


def nebula_cat(g):
    t = cat_base(g, rgb("b04ad8"), rgb("ffc0f0"), "shades")
    g.torus((0, 2.7, 1.2), 2.2, 0.12, rgb("5fd8ff"), axis="z")
    return t


def galaxy_tiger(g):
    t = cat_base(g, rgb("ff8a1e"), rgb("fff0d8"), "angry")
    for x in (-1.2, 1.2):
        g.box((x, 2.5, -1.62), (0.2, 0.9, 0.15), rgb("2a1840"))
    for y in (1.5, 2.2):
        for s in (-1, 1):
            g.box((s * 1.7, y, -1.0), (0.2, 0.7, 0.4), rgb("2a1840"))
    crown(g, 3.6, rgb("a86aff"), rgb("5fd8ff"))
    stars_around(g, 3.0, 2.0, 5)
    return t


def meme_lord(color, jewel, big):
    def f(g):
        g.egg((0, 2.1, 0), 1.8, 4.1, color)
        eyes(g, 2.7, -1.7, 0.7, "shades", 0.45)
        smile(g, 1.7, -1.72, 0.85)
        crown(g, 3.9, GOLD, jewel)
        if big >= 1:
            g.box((0, 2.1, 1.8), (3.4, 3.2, 0.3), rgb("7a1018"))
            halo(g, 4.4)
        if big >= 2:
            flame(g, 4.9, 1.0)
            g.torus((0, 2.9, 1.6), 2.3, 0.14, rgb("ffd84a"), axis="z")
        return 5.0
    return f


RECIPES = {
    "SoggyToast": soggy_toast, "BonkBean": bonk_bean, "SleepySock": sleepy_sock, "DiscoPickle": disco_pickle,
    "GigachadGoose": gigachad_goose, "MoonwalkMoth": moonwalk_moth, "ChiliChihuahua": chili_chihuahua, "LavaLatte": lava_latte,
    "VolcanoVicar": volcano_vicar, "PharaohPancake": pharaoh_pancake, "SphinxSneaker": sphinx_sneaker, "CleoCroissant": cleo_croissant,
    "NebulaNoodle": nebula_noodle, "QuasarQuokka": quasar_quokka, "BlackHoleBagel": black_hole_bagel, "TaxAngel": tax_angel,
    "FinalBossHamster": final_boss_hamster, "OmegaMeme": omega_meme, "GoldenGoose": golden_goose, "PlatinumGoose": platinum_goose,
    "MythicGoose": mythic_goose, "CosmicKitten": cosmic_kitten, "NebulaCat": nebula_cat, "GalaxyTiger": galaxy_tiger,
    "MemeLordJr": meme_lord(rgb("38c878"), rgb("ff4a4a"), 0), "MemeLordPrime": meme_lord(rgb("3a82ff"), rgb("ffd84a"), 1),
    "MemeLordOmega": meme_lord(rgb("e8344e"), rgb("62e0ff"), 2),
}


def build(name):
    g = Grid(U)
    RECIPES[name](g)
    return g
