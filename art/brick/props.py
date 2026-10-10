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


RECIPES = {"Tree": tree, "Cactus": cactus, "LavaRock": lava_rock, "IcePine": ice_pine, "Crystal": crystal, "Nest": nest}


def build(name):
    g = Grid(U)
    RECIPES[name](g)
    return g
