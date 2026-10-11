"""The 16 bats as brick models (about 5 studs long, standing upright with the hitting end up). Colours come straight from
src/shared/Game/Bats.luau so the model and the game's data never disagree; each tier adds its own flourish."""
import math
import os
import re

from kit import Grid, rgb, shade

U = 0.2
HERE = os.path.dirname(os.path.abspath(__file__))


def looks():
    text = open(os.path.join(HERE, "..", "..", "src", "shared", "Game", "Bats.luau")).read()
    rows = re.findall(r'name = "(\w+)", head = \{ (\d+), (\d+), (\d+) \}, handle = \{ (\d+), (\d+), (\d+) \}', text)
    return [(n, tuple(int(v) for v in h), tuple(int(v) for v in hd)) for n, *rest in rows for h, hd in [(rest[0:3], rest[3:6])]]


LOOKS = looks()
NAMES = [f"Bat{n}" for n, _, _ in LOOKS]


def col(c):
    return (c[0] / 255, c[1] / 255, c[2] / 255)


def build_bat(index):
    name, head, handle = LOOKS[index]
    h, k = head, handle
    g = Grid(U)
    g.cylinder((0, 1.2, 0), 0.26, 2.4, k)  # the grip
    g.cylinder((0, 0.1, 0), 0.4, 0.3, shade(k, 0.7))  # the knob
    for y in (0.6, 1.0, 1.4):
        g.cylinder((0, y, 0), 0.3, 0.12, shade(k, 0.8))  # tape rings
    g.cone((0, 3.2, 0), 0.3, 0.6, 1.6, h)  # the barrel widens toward the top
    g.cylinder((0, 4.3, 0), 0.62, 1.1, h)
    g.ellipsoid((0, 4.9, 0), (0.62, 0.35, 0.62), h)  # a rounded end
    g.cylinder((0, 3.95, 0), 0.66, 0.16, shade(h, 0.7))  # a band
    # a flourish per tier
    if name == "Foam":
        for y in (3.6, 4.2):
            g.cylinder((0, y, 0), 0.64, 0.14, rgb("ffe478"))
    elif name == "Stone":
        for x, y, z in ((0.6, 4.3, 0.1), (-0.5, 3.9, -0.3), (0.2, 4.8, 0.4)):
            g.box((x, y, z), (0.3, 0.3, 0.3), shade(h, 1.2))
    elif name in ("Iron", "Silver"):
        for a in range(0, 360, 45):
            g.box((math.cos(math.radians(a)) * 0.68, 4.3, math.sin(math.radians(a)) * 0.68), (0.2, 0.2, 0.2), shade(h, 1.25))
    elif name == "Golden":
        g.ellipsoid((0, 5.25, 0), (0.25, 0.25, 0.25), rgb("fff3a0"))
    elif name in ("Ruby", "Emerald"):
        for y in (3.8, 4.5):
            g.ellipsoid((0.6, y, 0), (0.2, 0.2, 0.2), rgb("ffffff"))
        g.ellipsoid((0, 5.3, 0), (0.28, 0.28, 0.28), rgb("ffffff"))
    elif name == "Frost":
        for a in range(0, 360, 60):
            g.cone((math.cos(math.radians(a)) * 0.6, 4.6, math.sin(math.radians(a)) * 0.6), 0.16, 0.0, 0.8, rgb("e8f8ff"))
    elif name == "Lava":
        for a, hgt in ((0, 1.0), (120, 0.8), (240, 1.1)):
            g.cone((math.cos(math.radians(a)) * 0.35, 5.2 + hgt / 2 - 0.2, math.sin(math.radians(a)) * 0.35), 0.22, 0.0, hgt, rgb("ffb21e"))
    elif name == "Neon":
        for y in (3.4, 4.0, 4.6):
            g.torus((0, y, 0), 0.62, 0.07, rgb("ffffff"), axis="y")
    elif name == "Ghost":
        for y, r in ((5.2, 0.3), (5.55, 0.2)):
            g.ellipsoid((0.2, y, 0), (r, r, r), rgb("ffffff"))
    elif name == "Cloud":
        for x, z in ((0.5, 0), (-0.5, 0.1), (0, 0.5), (0.1, -0.5)):
            g.ellipsoid((x, 5.1, z), (0.45, 0.35, 0.45), rgb("ffffff"))
    elif name == "Galaxy":
        for x, y, z in ((0.6, 4.4, 0), (-0.5, 3.8, 0.3), (0.2, 4.9, -0.4), (-0.3, 4.6, 0.5)):
            g.box((x, y, z), (0.18, 0.18, 0.18), rgb("ffe44a"))
    elif name == "Divine":
        g.torus((0, 5.7, 0), 0.7, 0.1, rgb("ffe066"), axis="y")
        for s in (-1, 1):
            g.ellipsoid((s * 0.95, 1.9, 0), (0.12, 0.7, 0.4), rgb("ffffff"))
    return g


RECIPES = {f"Bat{LOOKS[i][0]}": (lambda i=i: build_bat(i)) for i in range(len(LOOKS))}


def build(name):
    return RECIPES[name]()
