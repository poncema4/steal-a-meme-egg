"""The six egg tiers as brick models, like the big voxel eggs in the reference: each a brick-built egg with its own pattern."""
import math
from kit import Grid, rgb, shade

U = 0.45
H, R = 5.4, 2.1  # an egg stands 5.4 studs tall, 4.2 wide


def hash01(i, j, k, seed=1):
    n = (i * 73856093) ^ (j * 19349663) ^ (k * 83492791) ^ (seed * 2654435761)
    n = (n ^ (n >> 13)) * 1274126177
    return ((n ^ (n >> 16)) & 0xFFFF) / 65535.0


def spots(base, spot, density=0.07, size=0.5, seed=1):
    def f(p):
        # blobs on a coarse grid: a cell is spotted if its hash is low and the point is near the cell's centre
        gx, gy, gz = (math.floor(p[0] / 0.9), math.floor(p[1] / 0.9), math.floor(p[2] / 0.9))
        if hash01(gx, gy, gz, seed) < density * 4:
            cx, cy, cz = ((gx + 0.5) * 0.9, (gy + 0.5) * 0.9, (gz + 0.5) * 0.9)
            if (p[0] - cx) ** 2 + (p[1] - cy) ** 2 + (p[2] - cz) ** 2 <= size * size:
                return spot
        return base
    return f


def band(base, stripe, y0, y1, extra=None):
    def f(p):
        if y0 <= p[1] <= y1:
            return stripe
        return extra(p) if extra else base
    return f


def stars(base, star, seed=3):
    def f(p):
        gx, gy, gz = (math.floor(p[0] / 0.75), math.floor(p[1] / 0.75), math.floor(p[2] / 0.75))
        if hash01(gx, gy, gz, seed) < 0.16:
            return star
        return base
    return f


def tiles(a, b, hi):
    def f(p):
        i, j, k = (math.floor(p[0] / 0.6), math.floor(p[1] / 0.6), math.floor(p[2] / 0.6))
        if (i + j + k) % 2 == 0:
            return a
        return hi if hash01(i, j, k, 9) < 0.12 else b
    return f


def flames(base, hot, tip):
    def f(p):
        a = math.atan2(p[0], p[2])
        wave = 0.5 + 0.5 * math.sin(a * 5)
        h = p[1] / H  # 0 at the bottom of the egg
        if h < 0.18 + 0.32 * wave:
            return hot if h < 0.1 + 0.2 * wave else tip
        return base
    return f


def build(tier):
    g = Grid(U)
    cy = H / 2
    if tier == "Soggy":
        f = spots(rgb("f2e4b8"), rgb("a8794a"), 0.07, 0.5, 1)
    elif tier == "Disco":
        f = tiles(rgb("ff6fd8"), rgb("d93fb2"), rgb("fff2fb"))
    elif tier == "Spicy":
        f = flames(rgb("ff5a28"), rgb("ffcc2e"), rgb("ff8a1e"))
    elif tier == "Golden":
        f = band(rgb("ffd23a"), rgb("fff3b0"), 2.2, 3.0, spots(rgb("ffd23a"), rgb("f2a900"), 0.06, 0.45, 5))
    elif tier == "Cosmic":
        f = stars(rgb("3b2f9e"), rgb("ffe27a"))
    else:  # Divine
        f = band(rgb("fffbe8"), rgb("ffd54a"), 2.4, 3.0, spots(rgb("fffbe8"), rgb("ffeaa8"), 0.05, 0.4, 7))
    g.egg((0, cy, 0), R, H, f)
    if tier == "Divine":
        g.torus((0, H + 0.55, 0), 1.0, 0.18, rgb("ffe066"), axis="y")
    if tier == "Cosmic":
        g.torus((0, cy, 0), R + 0.45, 0.14, rgb("8fd4ff"), axis="z")
    return g


TIERS = ["Soggy", "Disco", "Spicy", "Golden", "Cosmic", "Divine"]
