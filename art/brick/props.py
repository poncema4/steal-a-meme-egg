"""Terrain scenery as brick models (about 10 studs tall; the server scales each one to its prop size): a tree, cactus, lava rock,
ice pine, crystal cluster and the twig nest the eggs sit in. Same kit as the pets: flat colours in a few shades, no meshes."""
import math
from kit import Grid, rgb, shade

U = 0.5


def banded(lo, hi, bands):
    """A colour function that darkens from the top down in `bands` steps (cheap shading that still merges into big boxes)."""
    def f(p):
        t = min(max((p[1] - lo) / max(hi - lo, 1e-6), 0), 0.999)
        return bands[int(t * len(bands))]
    return f


def tree(g):
    bark = rgb("7a4a28")
    g.cylinder((0, 2.4, 0), 0.95, 4.8, bark)
    g.box((0.95, 0.4, 0.2), (0.9, 0.8, 0.6), bark)  # roots
    g.box((-0.9, 0.4, -0.3), (0.8, 0.8, 0.6), bark)
    dark, mid, light = rgb("2c8a3e"), rgb("3fae4c"), rgb("66cf5e")
    g.ellipsoid((0, 6.0, 0), (3.8, 2.4, 3.8), dark)
    g.ellipsoid((0, 7.7, 0), (3.0, 2.0, 3.0), mid)
    g.ellipsoid((0, 9.1, 0), (2.0, 1.4, 2.0), light)
    for x, y, z in ((2.7, 6.2, -1.9), (-2.4, 7.3, -2.2), (0.6, 8.8, -1.8), (-1.6, 5.6, -3.0)):
        g.box((x, y, z), (0.6, 0.6, 0.6), rgb("e2323a"))  # apples
    return 10.3


def cactus(g):
    body, rib, spine = rgb("2f9e4f"), rgb("56c46a"), rgb("f4efc0")
    g.cylinder((0, 3.6, 0), 1.2, 7.2, body)
    g.ellipsoid((0, 7.2, 0), (1.2, 0.8, 1.2), body)
    for a in range(0, 360, 90):
        x, z = math.cos(math.radians(a)) * 1.05, math.sin(math.radians(a)) * 1.05
        g.box((x, 3.6, z), (0.4, 6.8, 0.4), rib)
    # arms: out, then up
    g.box((-1.9, 4.2, 0), (2.6, 1.0, 1.0), body)
    g.box((-3.0, 5.6, 0), (1.0, 3.0, 1.0), body)
    g.ellipsoid((-3.0, 7.3, 0), (0.5, 0.5, 0.5), body)
    g.box((1.8, 3.0, 0), (2.4, 1.0, 1.0), body)
    g.box((2.8, 4.1, 0), (1.0, 2.6, 1.0), body)
    g.ellipsoid((2.8, 5.4, 0), (0.5, 0.5, 0.5), body)
    for y in (2.0, 4.0, 6.0):
        g.box((0, y, -1.22), (0.3, 0.3, 0.3), spine)
        g.box((0.9, y + 0.6, -0.9), (0.3, 0.3, 0.3), spine)
    g.ellipsoid((0, 8.0, 0), (0.6, 0.45, 0.6), rgb("ff7ab8"))  # the flower
    g.box((0, 8.4, 0), (0.4, 0.4, 0.4), rgb("ffe35a"))
    return 8.6


def lava_rock(g):
    dark, mid, crack, glow = rgb("3a3036"), rgb("4e4249"), rgb("ff7a1c"), rgb("ffc23a")
    g.ellipsoid((0, 2.2, 0), (4.4, 2.4, 3.6), banded(0, 4.6, [mid, mid, dark, dark]) if False else dark)
    g.ellipsoid((-0.4, 4.0, 0.2), (3.0, 1.9, 2.6), mid)
    g.ellipsoid((1.2, 5.4, -0.2), (1.8, 1.4, 1.6), dark)
    # glowing cracks running down the front
    g.box((-0.8, 3.2, -3.4), (0.4, 3.0, 0.4), crack)
    g.box((0.4, 2.2, -3.55), (0.4, 2.2, 0.4), crack)
    g.box((1.8, 3.6, -2.2), (0.4, 2.0, 0.4), crack)
    g.box((0.0, 5.0, -2.6), (1.6, 0.4, 0.4), crack)
    g.box((-0.8, 3.2, -3.5), (0.3, 1.0, 0.3), glow)
    g.box((0.4, 2.0, -3.65), (0.3, 0.8, 0.3), glow)
    for x, z in ((-3.4, -1.8), (3.5, -1.2), (-1.0, 3.2)):
        g.ellipsoid((x, 0.7, z), (0.9, 0.7, 0.9), dark)
    g.ellipsoid((-3.2, 0.2, -2.6), (1.2, 0.3, 0.8), crack)  # a little ember pool
    return 6.4


def ice_pine(g):
    snow, ice, deep = rgb("f4fbff"), rgb("a9dcf5"), rgb("5fb3da")
    g.cylinder((0, 1.2, 0), 0.7, 2.4, rgb("6a5040"))
    g.cone((0, 3.6, 0), 3.4, 0.2, 3.2, deep)
    g.cone((0, 5.8, 0), 2.7, 0.2, 3.0, ice)
    g.cone((0, 7.8, 0), 1.9, 0.2, 2.8, deep)
    g.cone((0, 9.6, 0), 1.1, 0.0, 2.4, snow)
    for y, r in ((3.0, 3.0), (5.2, 2.3), (7.2, 1.5)):  # snow caught on each tier
        g.ellipsoid((0, y, 0), (r, 0.35, r), snow)
    # an ice crystal beside it
    g.cone((3.6, 2.0, 1.4), 0.9, 0.0, 4.2, ice)
    g.cone((4.8, 1.2, 0.6), 0.6, 0.0, 2.6, snow)
    return 11.0


def crystal(g):
    core, edge, glow = rgb("8a52ff"), rgb("b28cff"), rgb("e8dcff")
    g.cone((0, 4.0, 0), 1.9, 0.0, 8.0, core)
    g.cone((0, 3.0, 0), 1.2, 0.0, 6.0, edge)
    g.cone((-2.6, 2.4, 0.8), 1.2, 0.0, 4.8, rgb("6a3adf"))
    g.cone((2.5, 2.0, -0.6), 1.1, 0.0, 4.0, rgb("b28cff"))
    g.cone((0.8, 1.6, 2.6), 0.9, 0.0, 3.2, core)
    g.box((0, 5.4, -0.9), (0.4, 2.6, 0.4), glow)  # a bright facet
    g.box((-2.6, 3.4, 0.2), (0.3, 1.4, 0.3), glow)
    g.ellipsoid((0, 0.3, 0), (3.6, 0.5, 3.4), rgb("2d2260"))  # dark base stone
    return 8.0


def nest(g):
    twig, twig2, straw = rgb("8a5a2c"), rgb("6c4420"), rgb("e8cf7a")
    g.cylinder((0, 0.3, 0), 4.0, 0.6, twig2)
    g.torus((0, 0.8, 0), 3.4, 0.8, twig, axis="y")
    g.torus((0, 1.3, 0), 3.0, 0.5, twig2, axis="y")
    g.cylinder((0, 0.55, 0), 3.0, 0.5, straw)
    for a in range(0, 360, 40):  # twigs poking out around the rim
        x, z = math.cos(math.radians(a)) * 3.9, math.sin(math.radians(a)) * 3.9
        g.box((x, 1.0 + 0.3 * (a % 80 == 0), z), (1.0, 0.4, 0.5), twig)
    return 1.5


def treadmill_topper(g):
    """Sits on the treadmill's console bar (8 wide), facing the runner: a speedometer dial between two flag posts."""
    steel, dark = rgb("9aa2b8"), rgb("2a2c36")
    g.box((0, 0.3, 0), (8.0, 0.6, 1.0), steel)
    for x in (-3.6, 3.6):  # posts with flags
        g.box((x, 2.0, 0), (0.5, 3.4, 0.5), steel)
        g.box((x + (0.9 if x < 0 else -0.9), 3.3, 0), (1.4, 0.9, 0.3), rgb("e8262a") if x < 0 else rgb("2f8cff"))
        g.ellipsoid((x, 3.9, 0), (0.45, 0.45, 0.45), rgb("ffc21a"))
    g.cylinder((0, 2.4, 0.05), 2.2, 1.0, dark, axis="z")  # dial housing
    g.cylinder((0, 2.4, -0.45), 1.9, 0.3, rgb("f6f6fb"), axis="z")  # dial face (toward -Z, the runner)
    for k in range(9):  # ticks from green (slow) to red (fast)
        a = math.radians(210 - k * 30)
        col = rgb("3ddc5a") if k < 3 else (rgb("ffd23a") if k < 6 else rgb("e8262a"))
        g.box((math.cos(a) * 1.55, 2.4 + math.sin(a) * 1.55, -0.7), (0.35, 0.35, 0.3), col)
    a = math.radians(70)
    for r in (0.4, 0.8, 1.2):  # the needle
        g.box((math.cos(a) * r, 2.4 + math.sin(a) * r, -0.7), (0.3, 0.3, 0.3), rgb("16161c"))
    g.ellipsoid((0, 2.4, -0.75), (0.35, 0.35, 0.25), rgb("e8262a"))
    return 4.6


def bear_trap(g):
    """A steel bear trap lying open on the ground: a plate, a spring bar, two jaws ringed with teeth and a red trigger plate."""
    steel, dark, tooth, red = rgb("9aa2b8"), rgb("3a3d4a"), rgb("e8ecf5"), rgb("e8342a")
    g.box((0, 0.25, 0), (6.2, 0.5, 5.0), dark)
    g.box((0, 0.6, 0), (1.0, 0.45, 4.6), steel)
    for sx in (-1, 1):
        g.torus((sx * 1.7, 0.8, 0), 1.9, 0.38, steel, axis="y")
    for sx in (-1, 1):
        for k in range(8):
            a = math.radians(k * 45 + 22)
            x = sx * 1.7 + math.cos(a) * 1.9
            z = math.sin(a) * 1.9
            if abs(x) < 0.7:
                continue
            g.cone((x, 1.5, z), 0.3, 0.0, 1.1, tooth)
    g.cylinder((0, 0.75, 0), 0.5, 0.5, red)
    return 2.4


def swamp_tree(g):
    bark, moss, leaf = rgb("4a3a2a"), rgb("5a8a3a"), rgb("2f5a34")
    g.cylinder((0, 2.6, 0), 0.9, 5.2, bark)
    g.box((1.0, 0.4, 0.3), (1.0, 0.8, 0.7), bark)
    g.box((-1.0, 0.4, -0.2), (0.9, 0.8, 0.7), bark)
    g.ellipsoid((0, 6.4, 0), (3.6, 2.0, 3.6), leaf)
    g.ellipsoid((0.8, 7.6, 0.3), (2.4, 1.4, 2.4), rgb("3e7a42"))
    for x, z, h in ((2.8, 0.6, 3.0), (-2.6, -0.8, 3.6), (0.4, 2.8, 2.6), (-0.6, -2.8, 3.2), (2.0, -2.0, 2.4)):
        g.cylinder((x, 6.0 - h / 2, z), 0.22, h, moss)  # hanging moss
    g.cylinder((2.0, 0.9, -1.8), 0.25, 1.4, rgb("f4efc0"))  # a toadstool
    g.ellipsoid((2.0, 1.7, -1.8), (0.9, 0.5, 0.9), rgb("e2323a"))
    return 8.8


def candy_cane(g):
    red, white = rgb("ff3a5a"), rgb("ffffff")
    for k in range(10):
        g.cylinder((0, 0.35 + k * 0.7, 0), 0.6, 0.7, red if k % 2 == 0 else white)
    for k in range(7):  # the hook: half a circle over the top
        a = math.radians(180 - k * 30)
        g.cylinder((1.4 + math.cos(a) * 1.4, 7.0 + math.sin(a) * 1.4, 0), 0.6, 0.7, red if k % 2 == 0 else white)
    g.ellipsoid((0, 0.3, 0), (1.4, 0.3, 1.4), rgb("ff9ed2"))
    return 8.6


def neon_pylon(g):
    dark, cyan, mag = rgb("22243e"), rgb("38f2ff"), rgb("ff3df0")
    g.box((0, 3.4, 0), (2.2, 6.8, 2.2), dark)
    for k, y in enumerate((1.4, 3.0, 4.6)):
        g.box((0, y, 0), (2.5, 0.35, 2.5), cyan if k % 2 == 0 else mag)
    g.ellipsoid((0, 7.4, 0), (1.1, 1.1, 1.1), mag)
    g.box((0, 0.3, 0), (3.4, 0.6, 3.4), rgb("14143a"))
    return 8.5


def tombstone(g):
    stone, dark = rgb("9a9fb0"), rgb("6a6f80")
    g.box((0, 2.2, 0), (3.4, 4.4, 1.0), stone)
    g.ellipsoid((0, 4.4, 0), (1.7, 1.2, 0.5), stone)
    g.box((0, 3.6, -0.55), (0.35, 1.7, 0.3), dark)
    g.box((0, 4.0, -0.55), (1.1, 0.35, 0.3), dark)
    g.box((0, 0.3, 0.2), (4.4, 0.6, 2.4), rgb("5a4a3a"))
    g.ellipsoid((1.8, 0.6, -0.6), (0.7, 0.4, 0.7), rgb("3e5a36"))
    return 5.6


def cloud_puff(g):
    white, blue = rgb("ffffff"), rgb("cfe6ff")
    for x, y, z, r in ((0, 3.0, 0, 2.6), (2.4, 2.6, 0.4, 2.0), (-2.4, 2.5, -0.3, 2.0), (0.6, 4.2, 0.2, 1.8), (1.4, 2.2, -2.0, 1.7), (-1.2, 2.2, 2.0, 1.7)):
        g.ellipsoid((x, y, z), (r, r * 0.75, r), white)
    g.ellipsoid((0, 1.2, 0), (4.0, 0.5, 3.2), blue)
    return 6.0


RECIPES = {"SwampTree": swamp_tree, "CandyCane": candy_cane, "NeonPylon": neon_pylon, "Tombstone": tombstone, "CloudPuff": cloud_puff, "BearTrap": bear_trap, "Tree": tree, "Cactus": cactus, "LavaRock": lava_rock, "IcePine": ice_pine, "Crystal": crystal, "Nest": nest, "TreadmillTopper": treadmill_topper}


# the big, round props use bigger bricks: far fewer parts (there are about thirty of each in a terrain) and a chunkier toy look
UNITS = {"BearTrap": 0.3, "SwampTree": 0.75, "CloudPuff": 0.6, "CandyCane": 0.5, "Tree": 0.75, "LavaRock": 0.7, "Nest": 0.6, "IcePine": 0.6}


def build(name):
    g = Grid(UNITS.get(name, U))
    RECIPES[name](g)
    return g
