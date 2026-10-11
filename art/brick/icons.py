"""HUD icons as brick models (Shop cart, Index book, speed shoe, cash, egg, paw, trophy, potion, trap): the same chunky toy look as
the rest of the game, shown in the UI through ViewportFrames, so they need no upload and no moderation. About 6 studs tall,
fronts toward -Z (the camera looks from the front, a little from the side and above)."""
import math
from kit import Grid, rgb, shade

U = 0.25
BLACK, WHITE = rgb("16161c"), rgb("ffffff")


def normalise(g):
    """Slides a turned model back so it stands on y = 0 and sits centred over x = 0, z = 0 (voxel units)."""
    if not g.v:
        return
    ks = list(g.v)
    mi, ma = min(k[0] for k in ks), max(k[0] for k in ks)
    mj = min(k[1] for k in ks)
    mk, Mk = min(k[2] for k in ks), max(k[2] for k in ks)
    di, dj, dk = -(mi + ma + 1) // 2, -mj, -(mk + Mk + 1) // 2
    g.v = {(i + di, j + dj, k + dk): c for (i, j, k), c in g.v.items()}


def turn_y(g):
    """A quarter turn about the vertical axis: what pointed to -Z now points to -X (so a long model shows its side)."""
    g.v = {(k, j, -i - 1): c for (i, j, k), c in g.v.items()}
    normalise(g)


def stand_up(g):
    """Tips a flat model up onto its back so its top faces the viewer (-Z)."""
    g.v = {(i, k, -j - 1): c for (i, j, k), c in g.v.items()}
    normalise(g)


def cart(g):
    red, chrome, dark = rgb("e8342a"), rgb("d8dde8"), rgb("22222a")
    g.box((0, 2.6, 0), (5.0, 0.5, 3.4), red)  # basket floor
    for sx in (-2.5, 2.5):
        g.box((sx, 3.5, 0), (0.4, 2.0, 3.4), red)
    for sz in (-1.7, 1.7):
        g.box((0, 3.5, sz), (5.0, 2.0, 0.4), red)
    for i in range(-2, 3):  # wire bars on the front
        g.box((i * 1.0, 3.5, -1.75), (0.18, 1.8, 0.18), chrome)
    g.box((0, 4.5, -1.75), (5.2, 0.3, 0.3), chrome)
    g.box((-2.9, 4.4, 1.7), (0.45, 3.2, 0.45), chrome)  # the handle, behind
    g.box((-2.9, 5.9, 1.7), (1.4, 0.45, 0.45), chrome)
    g.box((-2.4, 2.3, 0), (0.4, 0.5, 3.0), dark)  # axle bracket
    for sx in (-1.8, 1.8):
        for sz in (-1.5, 1.5):
            g.cylinder((sx, 1.05, sz), 0.95, 0.5, dark, axis="z")
            g.cylinder((sx, 1.05, sz), 0.4, 0.55, chrome, axis="z")
    g.box((0, 1.9, 0), (4.4, 0.35, 0.4), dark)
    g.box((0, 3.3, -1.78), (1.8, 1.0, 0.1), WHITE)  # a price tag
    return 6.4


def book(g):
    cover, page, gold = rgb("3d8dff"), rgb("fbf7e6"), rgb("ffc21a")
    g.box((0, 3.0, 0), (4.4, 5.6, 1.5), cover)  # the cover (spine on the left)
    g.box((0.35, 3.0, 0.05), (3.9, 5.2, 1.2), page)  # the pages, inset on three sides
    g.box((0.35, 3.0, -0.62), (4.0, 5.4, 0.25), cover)  # front cover
    g.box((-2.05, 3.0, -0.2), (0.4, 5.6, 1.7), shade(cover, 0.78))  # spine
    for y in (1.5, 2.6, 3.7, 4.8):
        g.box((-2.05, y, -1.0), (0.45, 0.25, 0.1), gold)
    g.ellipsoid((0.4, 3.6, -0.85), (1.2, 1.2, 0.25), gold)  # a gold emblem
    g.ellipsoid((0.4, 3.6, -0.95), (0.7, 0.7, 0.15), shade(gold, 1.12))
    g.box((1.6, 0.55, -0.2), (0.45, 1.0, 0.1), rgb("e8342a"))  # bookmark
    return 6.0


def shoe(g):
    sole, upper, toe, tongue, swoosh = rgb("f6f6fb"), rgb("2f8cff"), rgb("8ec6ff"), rgb("ffffff"), rgb("ff3a2e")
    dark = shade(upper, 0.62)
    g.box((0, 0.5, -0.2), (2.8, 1.0, 7.6), sole)  # the sole
    g.ellipsoid((0, 0.8, -3.9), (1.4, 0.8, 1.2), sole)  # its rounded toe
    g.ellipsoid((0, 2.0, -2.5), (1.3, 1.25, 1.9), upper)  # toe box
    g.box((0, 2.4, -0.1), (2.5, 2.8, 2.8), upper)  # the middle of the shoe
    g.box((0, 3.2, 2.0), (2.5, 4.4, 2.8), upper)  # the high heel and ankle
    g.ellipsoid((0, 1.9, -3.6), (1.15, 0.9, 0.9), toe)  # toe cap
    g.box((0, 5.45, 2.0), (2.6, 0.5, 2.9), dark)  # padded collar
    g.box((0, 5.62, 2.0), (1.7, 0.2, 2.0), rgb("16161c"))  # the opening
    g.box((0, 4.3, 0.15), (1.7, 2.6, 0.7), tongue)  # tongue standing up
    for i in range(4):  # laces down the slope
        g.box((0, 4.6 - i * 0.55, 0.1 - i * 0.65), (2.2, 0.22, 0.3), tongue)
    for sx in (-1.28, 1.28):  # a big side swoosh and the heel patch
        g.box((sx, 2.3, 0.4), (0.15, 0.5, 3.0), swoosh)
        g.box((sx, 2.7, -1.5), (0.15, 0.5, 1.6), swoosh)
        g.box((sx, 3.4, 2.4), (0.15, 1.8, 1.2), dark)
    turn_y(g)  # side on: the toe points sideways, the way every sneaker icon shows it
    return 5.6


def cash(g):
    green, dark, band = rgb("55c957"), rgb("2e8f3a"), rgb("ffd24a")
    for i, (dx, dz, yaw) in enumerate(((0.0, 0.0, 0), (0.25, -0.2, 0), (-0.2, 0.25, 0))):
        y = 0.35 + i * 0.7
        g.box((dx, y, dz), (5.6, 0.6, 3.0), green)
        g.box((dx, y + 0.31, dz), (5.2, 0.08, 2.6), dark)
        g.box((dx, y + 0.32, dz - 0.0), (4.6, 0.05, 2.0), green)
    top = 0.35 + 2 * 0.7 + 0.35
    g.ellipsoid((0, top, -0.2), (0.95, 0.08, 0.95), rgb("e8f9e6"))  # a seal
    g.box((0, top + 0.1, -0.2), (0.3, 0.1, 1.3), dark)  # the $ (stroke and bars)
    g.box((-0.3, top + 0.1, -0.55), (0.7, 0.1, 0.25), dark)
    g.box((0.3, top + 0.1, -0.2), (0.7, 0.1, 0.25), dark)
    g.box((-0.3, top + 0.1, 0.15), (0.7, 0.1, 0.25), dark)
    g.box((0, 1.0, 0), (1.2, 2.2, 3.3), band)  # the paper band
    g.box((0, 1.0, 0), (1.3, 2.0, 0.1), shade(band, 0.8))
    return 2.6


def egg(g):
    base, spot = rgb("ff5ac8"), rgb("ffe14a")
    g.egg((0, 3.0, 0), 2.1, 5.8, base)
    for x, y, z, r in ((-0.8, 4.4, -1.4, 0.45), (0.9, 3.4, -1.6, 0.55), (-1.1, 2.2, -1.5, 0.5), (0.5, 1.5, -1.6, 0.4), (0.1, 4.9, -0.9, 0.3)):
        g.ellipsoid((x, y, z), (r, r, 0.3), spot)
    g.ellipsoid((-0.9, 4.1, -1.9), (0.35, 0.7, 0.15), rgb("ffd0f0"))  # a shine
    return 5.8


def paw(g):
    pad, toe, shine = rgb("f59a1e"), rgb("ffb540"), rgb("ffd98a")
    g.ellipsoid((0, 1.9, 0), (2.0, 1.6, 0.9), pad)
    for x, y, r in ((-2.1, 3.6, 0.8), (-0.8, 4.6, 0.85), (0.8, 4.6, 0.85), (2.1, 3.6, 0.8)):
        g.ellipsoid((x, y, 0), (r, r * 1.15, 0.8), toe)
    g.ellipsoid((-0.7, 2.6, -0.9), (0.9, 0.45, 0.15), shine)
    return 5.6


def trophy(g):
    gold, dark, base = rgb("ffc21a"), rgb("e39a0a"), rgb("8a5a2c")
    g.cylinder((0, 0.4, 0), 1.9, 0.8, base)
    g.cylinder((0, 1.0, 0), 1.4, 0.5, shade(base, 1.2))
    g.cylinder((0, 1.9, 0), 0.5, 1.6, gold)
    g.cone((0, 4.0, 0), 1.0, 2.4, 2.6, gold)  # the cup flares out
    g.cylinder((0, 5.5, 0), 2.45, 0.5, dark)  # rim
    for sx in (-1, 1):
        g.torus((sx * 2.6, 4.3, 0), 0.9, 0.28, gold, axis="z")
    g.box((-0.9, 3.9, -1.7), (0.35, 1.4, 0.2), rgb("fff2b0"))  # shine
    g.ellipsoid((0, 4.0, -2.0), (0.55, 0.55, 0.15), rgb("ff6a3a"))  # a star badge
    return 5.8


def potion(g):
    glass, liquid, cork = rgb("c9f2ff"), rgb("3fdc66"), rgb("c88a4a")
    g.ellipsoid((0, 2.2, 0), (2.2, 2.2, 2.2), liquid)  # the flask is full of green
    g.ellipsoid((0, 3.7, 0), (1.9, 0.5, 1.9), shade(liquid, 1.15))  # a brighter surface
    g.cylinder((0, 4.6, 0), 0.8, 1.6, glass)  # the neck
    g.cylinder((0, 5.0, 0), 0.55, 0.9, liquid)
    g.cylinder((0, 5.7, 0), 0.95, 0.9, cork)
    g.ellipsoid((-1.0, 2.9, -1.95), (0.4, 0.8, 0.15), rgb("eafff0"))  # a shine
    for x, y in ((0.8, 2.2), (-0.1, 1.2), (0.5, 3.0)):
        g.ellipsoid((x, y, -2.0), (0.3, 0.3, 0.15), rgb("b8ffd0"))  # bubbles
    return 6.2


def trap(g):
    steel, dark, tooth = rgb("9aa2b8"), rgb("3a3d4a"), rgb("e8ecf5")
    g.box((0, 0.3, 0), (6.2, 0.6, 5.0), dark)  # the plate
    g.box((0, 0.7, 0), (1.0, 0.5, 4.6), steel)  # the spring bar
    for sx in (-1, 1):
        g.torus((sx * 1.7, 1.1, 0), 1.9, 0.38, steel, axis="y")  # the two jaws, lying open
    for sx in (-1, 1):
        for k in range(8):
            a = math.radians(k * 45 + 22)
            x = sx * 1.7 + math.cos(a) * 1.9
            z = math.sin(a) * 1.9
            if abs(x) < 0.7:
                continue
            g.cone((x, 1.8, z), 0.3, 0.0, 1.1, tooth)  # teeth
    g.cylinder((0, 0.9, 0), 0.5, 0.6, rgb("e8342a"))  # the trigger plate
    stand_up(g)  # seen from above, like the hotbar slot shows it
    return 6.0


def clock(g):
    """An alarm clock for the event countdown: red bells, a white face with ticks and hands."""
    red, white, dark, gold = rgb("e8342a"), rgb("fbfbff"), rgb("22222a"), rgb("ffc21a")
    g.cylinder((0, 3.0, 0), 2.6, 1.4, red, axis="z")  # the case
    g.cylinder((0, 3.0, -0.3), 2.1, 1.2, white, axis="z")  # the face (toward -Z)
    for k in range(12):
        a = math.radians(k * 30)
        r = 1.7
        big = k % 3 == 0
        g.box((math.sin(a) * r, 3.0 + math.cos(a) * r, -0.95), (0.3 if big else 0.2, 0.3 if big else 0.2, 0.15), dark)
    g.box((0, 3.45, -0.98), (0.26, 1.0, 0.15), dark)  # the long hand, up
    g.box((0.5, 3.0, -0.98), (1.0, 0.26, 0.15), dark)  # the short hand, right
    g.ellipsoid((0, 3.0, -1.0), (0.3, 0.3, 0.15), gold)
    for sx in (-1, 1):
        g.ellipsoid((sx * 1.55, 5.45, 0), (0.85, 0.75, 0.6), gold)  # the bells
        g.box((sx * 1.9, 0.5, 0), (0.45, 1.0, 0.45), dark)  # the feet
    g.box((0, 5.9, 0), (0.35, 0.7, 0.35), dark)
    return 6.4


RECIPES = {"cart": cart, "book": book, "shoe": shoe, "cash": cash, "egg": egg, "paw": paw, "trophy": trophy, "potion": potion, "trap": trap, "clock": clock}


def build(name):
    g = Grid(U)
    RECIPES[name](g)
    return g
