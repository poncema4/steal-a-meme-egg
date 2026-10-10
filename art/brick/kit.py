"""Brick-model kit: design a creature out of voxels, merge them into as few boxes as possible, and write a Roblox model file.

A model is authored in studs with its front toward -Z (a part's front in Roblox), standing on y = 0 with x = 0 and z = 0 in the
middle of its feet. `Grid` fills shapes (box, ellipsoid, cylinder, cone, torus...) with flat colours; `boxes()` merges equal-coloured
neighbours greedily; `write_rbxmx()` makes a Model of anchored Parts that Rojo syncs into Studio (no script builds it at runtime).
Pure Python, no dependencies."""
import math
import os


def rgb(h):
    h = h.lstrip("#")
    return (int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16))


def shade(c, k):
    return tuple(max(0, min(255, int(v * k))) for v in c)


class Grid:
    def __init__(self, unit):
        self.u = unit
        self.v = {}

    # ---- the voxel at a point in studs
    def key(self, x, y, z):
        u = self.u
        return (math.floor(x / u + 1e-9), math.floor(y / u + 1e-9), math.floor(z / u + 1e-9))

    def put(self, x, y, z, c):
        if c is None:
            self.v.pop(self.key(x, y, z), None)
        else:
            self.v[self.key(x, y, z)] = tuple(c)

    def _scan(self, lo, hi, test, c):
        u = self.u
        i0, j0, k0 = (math.floor(lo[a] / u) for a in range(3))
        i1, j1, k1 = (math.ceil(hi[a] / u) for a in range(3))
        for i in range(i0, i1 + 1):
            for j in range(j0, j1 + 1):
                for k in range(k0, k1 + 1):
                    p = ((i + 0.5) * u, (j + 0.5) * u, (k + 0.5) * u)
                    if test(p):
                        col = c(p) if callable(c) else c
                        if col is None:
                            self.v.pop((i, j, k), None)
                        else:
                            self.v[(i, j, k)] = tuple(col)

    def fill(self, lo, hi, test, color):
        """Fill every voxel inside [lo, hi] for which test(point) is true. `color` is a colour, None to erase, or a function of
        the point (for spots, stripes and stars)."""
        self._scan(lo, hi, test, color)

    def egg(self, c, radius, height, color):
        """An egg standing on c: widest a third of the way up, narrower toward the top."""
        cx, cy, cz = c
        def test(p):
            t = (p[1] - cy) / (height / 2)
            if abs(t) > 1:
                return False
            r = radius * math.sqrt(max(0.0, 1 - t * t)) * (1 - 0.16 * t)
            return (p[0] - cx) ** 2 + (p[2] - cz) ** 2 <= r * r
        self._scan((cx - radius, cy - height / 2, cz - radius), (cx + radius, cy + height / 2, cz + radius), test, color)

    # ---- shapes: centre c = (x, y, z) in studs; colour None erases
    def box(self, c, size, color):
        # a feature thinner than one voxel would fall between voxel centres and vanish: every box is at least one voxel thick
        hx, hy, hz = (max(s, self.u) / 2 for s in size)
        self._scan((c[0] - hx, c[1] - hy, c[2] - hz), (c[0] + hx, c[1] + hy, c[2] + hz),
                   lambda p: abs(p[0] - c[0]) <= hx and abs(p[1] - c[1]) <= hy and abs(p[2] - c[2]) <= hz, color)

    def ellipsoid(self, c, radii, color):
        rx, ry, rz = (max(r, self.u * 0.6) for r in radii)
        self._scan((c[0] - rx, c[1] - ry, c[2] - rz), (c[0] + rx, c[1] + ry, c[2] + rz),
                   lambda p: ((p[0] - c[0]) / rx) ** 2 + ((p[1] - c[1]) / ry) ** 2 + ((p[2] - c[2]) / rz) ** 2 <= 1.0, color)

    def cylinder(self, c, radius, height, color, axis="y"):
        a = {"x": 0, "y": 1, "z": 2}[axis]
        o = [i for i in range(3) if i != a]
        radius = max(radius, self.u * 0.6)
        half = max(height, self.u) / 2
        lo = [c[i] - radius for i in range(3)]
        hi = [c[i] + radius for i in range(3)]
        lo[a], hi[a] = c[a] - half, c[a] + half
        self._scan(lo, hi, lambda p: abs(p[a] - c[a]) <= half and (p[o[0]] - c[o[0]]) ** 2 + (p[o[1]] - c[o[1]]) ** 2 <= radius ** 2, color)

    def cone(self, c, r_base, r_top, height, color, axis="y"):
        a = {"x": 0, "y": 1, "z": 2}[axis]
        o = [i for i in range(3) if i != a]
        half = max(height, self.u) / 2
        height = half * 2
        r_base, r_top = max(r_base, self.u * 0.6), (max(r_top, 0.0) if r_top == 0 else max(r_top, self.u * 0.6))
        lo = [c[i] - max(r_base, r_top) for i in range(3)]
        hi = [c[i] + max(r_base, r_top) for i in range(3)]
        lo[a], hi[a] = c[a] - half, c[a] + half

        def test(p):
            t = (p[a] - (c[a] - half)) / height
            if t < 0 or t > 1:
                return False
            r = r_base + (r_top - r_base) * t
            return (p[o[0]] - c[o[0]]) ** 2 + (p[o[1]] - c[o[1]]) ** 2 <= r * r
        self._scan(lo, hi, test, color)

    def torus(self, c, major, minor, color, axis="z"):
        """A ring around `axis` (z faces the viewer when the model looks toward -z... a ring seen from the front is axis z)."""
        a = {"x": 0, "y": 1, "z": 2}[axis]
        o = [i for i in range(3) if i != a]
        minor = max(minor, self.u * 0.6)
        r = major + minor
        lo = [c[i] - r for i in range(3)]
        hi = [c[i] + r for i in range(3)]
        lo[a], hi[a] = c[a] - minor, c[a] + minor

        def test(p):
            d = math.sqrt((p[o[0]] - c[o[0]]) ** 2 + (p[o[1]] - c[o[1]]) ** 2)
            return (d - major) ** 2 + (p[a] - c[a]) ** 2 <= minor * minor
        self._scan(lo, hi, test, color)

    def mirror_x(self):
        """Copy everything on the x > 0 side to x < 0 (so a left half is enough to build a symmetric creature)."""
        add = {}
        for (i, j, k), c in self.v.items():
            add[(-i - 1, j, k)] = c
        for key, c in add.items():
            self.v.setdefault(key, c)

    # ---- merge into boxes
    def boxes(self):
        """Greedy merge: for each colour grow maximal boxes along x, then y, then z. Returns [(x, y, z, sx, sy, sz, colour)] in studs
        (centre and size); the union is exactly the voxel set."""
        u = self.u
        left = dict(self.v)
        out = []
        for key in sorted(left, key=lambda k: (k[1], k[2], k[0])):
            if key not in left:
                continue
            c = left[key]
            i, j, k = key
            i1 = i
            while left.get((i1 + 1, j, k)) == c:
                i1 += 1
            j1 = j
            while all(left.get((a, j1 + 1, k)) == c for a in range(i, i1 + 1)):
                j1 += 1
            k1 = k
            while all(left.get((a, b, k1 + 1)) == c for a in range(i, i1 + 1) for b in range(j, j1 + 1)):
                k1 += 1
            for a in range(i, i1 + 1):
                for b in range(j, j1 + 1):
                    for d in range(k, k1 + 1):
                        del left[(a, b, d)]
            out.append(((i + i1 + 1) / 2 * u, (j + j1 + 1) / 2 * u, (k + k1 + 1) / 2 * u, (i1 - i + 1) * u, (j1 - j + 1) * u, (k1 - k + 1) * u, c))
        return out

    def height(self):
        return (max(k[1] for k in self.v) + 1) * self.u if self.v else 0


# ------------------------------------------------------------------ writers
def _packed(c):
    return 0xFF000000 | (c[0] << 16) | (c[1] << 8) | c[2]


def _cframe(x, y, z, yaw=0.0):
    c, s = math.cos(yaw), math.sin(yaw)
    return (f"<CoordinateFrame name=\"CFrame\"><X>{x:.4f}</X><Y>{y:.4f}</Y><Z>{z:.4f}</Z>"
            f"<R00>{c:.6f}</R00><R01>0</R01><R02>{s:.6f}</R02><R10>0</R10><R11>1</R11><R12>0</R12>"
            f"<R20>{-s:.6f}</R20><R21>0</R21><R22>{c:.6f}</R22></CoordinateFrame>")


MATERIAL = {"Plastic": 256, "SmoothPlastic": 272, "Neon": 288, "Metal": 1088, "Glass": 2048}


class Part:
    def __init__(self, name, pos, size, color, material="SmoothPlastic", shape="Block", transparency=0.0, cls="Part", yaw=0.0, collide=False):
        self.name, self.pos, self.size, self.color = name, pos, size, color
        self.material, self.shape, self.transparency, self.cls, self.yaw, self.collide = material, shape, transparency, cls, yaw, collide


def write_rbxmx(path, name, parts, root_height=0.0):
    """A Model of anchored parts with an invisible tiny Root part at the base centre as PrimaryPart, so PivotTo puts the model's
    feet where you want it."""
    refs = {}
    n = [0]

    def ref():
        n[0] += 1
        return f"RBX{n[0]}"

    model_ref, root_ref = ref(), ref()
    xml = ['<roblox xmlns:xmime="http://www.w3.org/2005/05/xmlmime" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" '
           'xsi:noNamespaceSchemaLocation="http://www.roblox.com/roblox.xsd" version="4">',
           f'<Item class="Model" referent="{model_ref}"><Properties><string name="Name">{name}</string>'
           f'<Ref name="PrimaryPart">{root_ref}</Ref></Properties>']

    def item(p, r):
        shape = {"Block": 1, "Ball": 0, "Cylinder": 2}[p.shape]
        props = [f'<string name="Name">{p.name}</string>', '<bool name="Anchored">true</bool>',
                 f'<bool name="CanCollide">{"true" if p.collide else "false"}</bool>',
                 '<bool name="CanTouch">false</bool>', '<bool name="CanQuery">false</bool>', '<bool name="CastShadow">true</bool>',
                 f'<Color3uint8 name="Color3uint8">{_packed(p.color)}</Color3uint8>',
                 _cframe(p.pos[0], p.pos[1], p.pos[2], p.yaw),
                 f'<token name="Material">{MATERIAL[p.material]}</token>',
                 f'<float name="Transparency">{p.transparency}</float>',
                 f'<Vector3 name="size"><X>{p.size[0]:.4f}</X><Y>{p.size[1]:.4f}</Y><Z>{p.size[2]:.4f}</Z></Vector3>',
                 '<token name="TopSurface">0</token>', '<token name="BottomSurface">0</token>']
        if p.cls == "Part":
            props.append(f'<token name="shape">{shape}</token>')
        return f'<Item class="{p.cls}" referent="{r}"><Properties>' + "".join(props) + "</Properties></Item>"

    root = Part("Root", (0, root_height, 0), (0.2, 0.2, 0.2), (255, 255, 255), transparency=1.0)
    xml.append(item(root, root_ref))
    for p in parts:
        xml.append(item(p, ref()))
    xml.append("</Item></roblox>")
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w") as f:
        f.write("\n".join(xml))
    return len(parts) + 1


def preview_json(path, parts):
    """The same parts in the format scripts/preview/blender_view.py reads, so Blender can render the model."""
    import json
    rows = []
    for p in parts:
        rows.append({"name": p.name, "x": p.pos[0], "y": p.pos[1], "z": p.pos[2], "sx": p.size[0], "sy": p.size[1], "sz": p.size[2],
                     "r": p.color[0], "g": p.color[1], "b": p.color[2], "yaw": p.yaw, "rolled": False})
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w") as f:
        json.dump(rows, f)


def grid_parts(grid, name="Brick", material="SmoothPlastic"):
    return [Part(name, (x, y, z), (sx, sy, sz), c, material) for (x, y, z, sx, sy, sz, c) in grid.boxes()]
