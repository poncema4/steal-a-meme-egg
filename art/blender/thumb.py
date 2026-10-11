"""Store art for Steal a Meme Egg, modelled on the top Steal-an-Egg thumbnails: a tiny avatar lifting a huge jewelled egg, an
angry guardian beside it, bright saturated desert, room for the rainbow title. The egg and the guardian are built from
merged voxel cubes (like the in-game parts) with a small colour jitter per cube. Renders art/renders/thumb_wide.png
(1920x1080) and art/renders/thumb_icon.png (1024x1024); brand/make_thumb.py adds the text layer afterwards.
Usage: ~/tools/blender-4.5.14-linux-x64/blender -b -P art/blender/thumb.py"""
import sys, os, math, random
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from common import *
from mathutils import Vector

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "renders")


def setup(res, sky=(0.25, 0.55, 1.0), strength=1.0):
    reset()
    sc = bpy.context.scene
    sc.render.engine = "BLENDER_EEVEE_NEXT"
    sc.render.resolution_x, sc.render.resolution_y = res
    sc.eevee.taa_render_samples = 96
    w = bpy.data.worlds.new("w"); sc.world = w; w.use_nodes = True
    w.node_tree.nodes["Background"].inputs[0].default_value = (*sky, 1)
    w.node_tree.nodes["Background"].inputs[1].default_value = strength
    sc.view_settings.view_transform = "Standard"
    sc.view_settings.exposure = 0.0
    return sc


def light(kind, loc, energy, color, size=1.0, target=None):
    bpy.ops.object.light_add(type=kind, location=loc)
    L = bpy.context.object
    L.data.energy = energy
    L.data.color = color
    if kind == "AREA":
        L.data.size = size
    if kind == "SUN":
        L.data.angle = math.radians(5)
    if target:
        d = Vector(target) - Vector(loc)
        L.rotation_euler = d.to_track_quat("-Z", "Y").to_euler()
    return L


def camera(loc, target, lens=30, roll=0.0):
    sc = bpy.context.scene
    cam = bpy.data.objects.new("cam", bpy.data.cameras.new("cam"))
    sc.collection.objects.link(cam); sc.camera = cam
    cam.location = loc
    cam.data.lens = lens
    d = Vector(target) - Vector(loc)
    cam.rotation_euler = d.to_track_quat("-Z", "Y").to_euler()
    cam.rotation_euler.rotate_axis("Z", roll)


def avatar(ox, oy, oz, shirt, pants, skin, yaw, arms=(2.4, 2.4), stride=0.5, lean=0.0, scale=1.0):
    """Blocky Roblox-style avatar (R6 proportions). Front is -y at yaw 0."""
    root = bpy.data.objects.new("av", None)
    bpy.context.scene.collection.objects.link(root)
    root.location = (ox, oy, oz)
    root.rotation_euler = (lean, 0, yaw)
    root.scale = (scale, scale, scale)
    ms, mp, mk = mat("shirt", shirt, 0.45), mat("pants", pants, 0.5), mat("skin", skin, 0.4)
    black = mat("black", (0.01, 0.01, 0.012), 0.4)
    white = mat("white", (1, 1, 1), 0.3, emit=(1, 1, 1))

    def put(o, loc, parent=root):
        o.parent = parent
        o.location = loc
        return o

    put(box("torso", (2, 1, 2), (0, 0, 0), ms, 0.08), (0, 0, 3.0))
    put(box("head", (1.3, 1.2, 1.2), (0, 0, 0), mk, 0.3, 1), (0, 0, 4.7))
    for s_ in (-1, 1):
        put(box("eye", (0.22, 0.05, 0.5), (0, 0, 0), black, 0.02), (s_ * 0.3, -0.62, 4.85))
        put(box("shine", (0.08, 0.03, 0.14), (0, 0, 0), white, 0.0), (s_ * 0.3 + 0.03, -0.655, 5.0))
    put(box("mouth", (0.7, 0.05, 0.55), (0, 0, 0), black, 0.1), (0, -0.62, 4.3))
    for i, s_ in enumerate((-1, 1)):
        hip = bpy.data.objects.new("hip", None); bpy.context.scene.collection.objects.link(hip)
        put(hip, (s_ * 0.5, 0, 2.0))
        hip.rotation_euler = (s_ * stride, 0, 0)
        put(box("leg", (0.95, 1, 2), (0, 0, 0), mp, 0.06), (0, 0, -1.0), hip)
        sh = bpy.data.objects.new("sh", None); bpy.context.scene.collection.objects.link(sh)
        put(sh, (s_ * 1.5, 0, 3.9))
        sh.rotation_euler = (math.pi - arms[i], 0, s_ * 0.25)
        put(box("arm", (1, 1, 2), (0, 0, 0), mk, 0.06), (0, 0, -1.0), sh)
        put(box("sleeve", (1.04, 1.04, 0.8), (0, 0, 0), ms, 0.06), (0, 0, -0.3), sh)
    return root


def sparkles(center, spread, n, seed):
    random.seed(seed)
    m = mat("spark", (1, 0.85, 0.2), 0.2, emit=(1.0, 0.75, 0.1))
    m.node_tree.nodes["Principled BSDF"].inputs["Emission Strength"].default_value = 5
    for _ in range(n):
        p = [center[i] + random.uniform(-spread[i], spread[i]) for i in range(3)]
        bpy.ops.mesh.primitive_ico_sphere_add(radius=random.uniform(0.06, 0.2), location=p, subdivisions=1)
        bpy.context.object.data.materials.append(m)


def gradient_sky(top=(0.10, 0.42, 1.0), bottom=(0.62, 0.9, 1.0)):
    """A cartoon sky: deep blue overhead fading to pale cyan at the horizon (world shader, camera-space gradient)."""
    nt = bpy.context.scene.world.node_tree
    for n in list(nt.nodes):
        if n.name not in ("World Output",):
            nt.nodes.remove(n)
    out = nt.nodes["World Output"]
    coord = nt.nodes.new("ShaderNodeTexCoord")
    sep = nt.nodes.new("ShaderNodeSeparateXYZ")
    ramp = nt.nodes.new("ShaderNodeValToRGB")
    bg = nt.nodes.new("ShaderNodeBackground")
    nt.links.new(coord.outputs["Window"], sep.inputs[0])
    nt.links.new(sep.outputs["Y"], ramp.inputs[0])
    ramp.color_ramp.elements[0].position = 0.35
    ramp.color_ramp.elements[0].color = (*bottom, 1)
    ramp.color_ramp.elements[1].position = 1.0
    ramp.color_ramp.elements[1].color = (*top, 1)
    nt.links.new(ramp.outputs["Color"], bg.inputs[0])
    bg.inputs[1].default_value = 1.0
    nt.links.new(bg.outputs[0], out.inputs[0])


def desert(seed=2):
    """The Dune terrain: sand floor, orange mesas on the horizon, voxel cacti. Each Wild in the game has its own look."""
    sand = mat("sand", (0.95, 0.62, 0.18), 0.9)
    box("sandfloor", (400, 260, 1), (0, 60, -0.5), sand, 0, 0)
    for k in range(-5, 6):
        box("dune", (9, 260, 0.03), (k * 16 + 4, 60, 0.02), mat(f"dune{k}", (1.0, 0.72, 0.28), 0.9), 0, 0)
    rock = mat("mesa", (0.85, 0.32, 0.1), 0.85)
    rock2 = mat("mesa2", (0.95, 0.5, 0.18), 0.85)
    random.seed(seed)
    for x, w, h, d in [(-70, 26, 22, 14), (-38, 16, 14, 10), (-110, 30, 30, 16), (52, 24, 20, 14), (86, 30, 28, 16), (30, 12, 11, 8), (125, 26, 24, 14)]:
        box("mesa", (w, d, h), (x, 85 + random.uniform(-5, 15), h / 2), rock, 0.8, 0)
        box("mesatop", (w - 3, d - 2, 2.5), (x, 85, h + 1), rock2, 0.5, 0)
    cactus = mat("cactus", (0.1, 0.62, 0.15), 0.6)
    for x, y, h in [(-22, 24, 9), (30, 34, 7), (-52, 40, 8), (58, 22, 10)]:
        box("cactus", (1.8, 1.8, h), (x, y, h / 2), cactus, 0.3, 0)
        box("arm", (3.4, 1.4, 1.4), (x, y, h * 0.6), cactus, 0.3, 0)
        box("armup", (1.4, 1.4, 3), (x + 1.7, y, h * 0.6 + 1.5), cactus, 0.3, 0)




# ---------------------------------------------------------------- voxel building
CUBE = 0.5


def voxel_object(name, cubes, bevel=0.07, glow=0.0):
    """One merged mesh per colour: cubes is {(r, g, b): [(x, y, z), ...]} in world units. Each cube gets a rounded edge,
    which is what makes it read as a Roblox part rather than a Minecraft block."""
    import bmesh
    objs = []
    for i, (rgb, centers) in enumerate(cubes.items()):
        mesh = bpy.data.meshes.new(f"{name}{i}")
        bm = bmesh.new()
        for (x, y, z) in centers:
            bmesh.ops.create_cube(bm, size=CUBE * 0.98, matrix=__import__("mathutils").Matrix.Translation((x, y, z)))
        bm.to_mesh(mesh)
        bm.free()
        o = bpy.data.objects.new(f"{name}{i}", mesh)
        bpy.context.scene.collection.objects.link(o)
        o.data.materials.append(mat(f"{name}m{i}", rgb, 0.35, emit=rgb if glow else None))
        if glow:
            o.data.materials[0].node_tree.nodes["Principled BSDF"].inputs["Emission Strength"].default_value = glow
        mod = o.modifiers.new("bevel", "BEVEL")
        mod.width = CUBE * bevel
        mod.segments = 2
        for p in mesh.polygons:
            p.use_smooth = True
        objs.append(o)
    return objs


def jitter(rgb, rnd, amount=0.045):
    k = 1 + rnd.uniform(-amount, amount)
    return tuple(min(1.0, max(0.0, c * k)) for c in rgb)


def quantise(rgb):
    return tuple(round(c * 24) / 24 for c in rgb)


def add(groups, rgb, p):
    groups.setdefault(quantise(rgb), []).append(p)


def voxel_egg(center, rx, rz, seed=11):
    """A jewelled egg: a hollow ellipsoid shell, pointier at the top, magenta with darker speckles, studded with gold crystal
    clusters that stick out of the shell."""
    rnd = random.Random(seed)
    groups = {}
    nx, nz = int(rx / CUBE) + 2, int(rz / CUBE) + 2
    surface = []
    for i in range(-nx, nx + 1):
        for j in range(-nx, nx + 1):
            for k in range(-nz, nz + 1):
                x, y, z = i * CUBE, j * CUBE, k * CUBE
                taper = 1 - 0.20 * max(0.0, z / rz)  # narrower toward the top
                d = math.sqrt((x / (rx * taper)) ** 2 + (y / (rx * taper)) ** 2 + (z / rz) ** 2)
                if d <= 1.0 and d > 1.0 - (CUBE * 2.2) / rx:
                    surface.append((x, y, z, d))
    # crystal clusters on the camera side
    spots = []
    for _ in range(30):
        a = rnd.uniform(-2.7, -0.45)
        b = rnd.uniform(-0.7, 1.15)
        spots.append((a, b, rnd.uniform(0.9, 1.6)))
    for (x, y, z, d) in surface:
        base = (0.93, 0.12, 0.72) if (z / rz) > -0.2 else (0.62, 0.08, 0.86)
        near = None
        for (a, b, r) in spots:
            px = rx * math.cos(b) * math.cos(a)
            py = rx * math.cos(b) * math.sin(a)
            pz = rz * math.sin(b)
            dist = math.sqrt((x - px) ** 2 + (y - py) ** 2 + (z - pz) ** 2)
            if dist < r:
                near = (dist, r)
        if near:
            gold = (1.0, 0.72, 0.1) if near[0] < near[1] * 0.6 else (1.0, 0.55, 0.05)
            add(groups, jitter(gold, rnd, 0.06), (center[0] + x, center[1] + y, center[2] + z))
        else:
            if rnd.random() < 0.10:
                base = (0.45, 0.04, 0.55)  # dark speckle
            add(groups, jitter(base, rnd), (center[0] + x, center[1] + y, center[2] + z))
    # crystals standing on the shell at the cluster centres
    for (a, b, r) in spots:
        taper = 1 - 0.20 * max(0.0, math.sin(b))
        p = (rx * taper * math.cos(b) * math.cos(a), rx * taper * math.cos(b) * math.sin(a), rz * math.sin(b))
        n = Vector((p[0] / rx, p[1] / rx, p[2] / rz)).normalized()
        for h in range(1, int(r * 2.2) + 1):
            q = (center[0] + p[0] + n.x * h * CUBE, center[1] + p[1] + n.y * h * CUBE, center[2] + p[2] + n.z * h * CUBE)
            add(groups, jitter((1.0, 0.82 - 0.05 * h, 0.2), rnd, 0.04), q)
    return voxel_object("egg", groups, glow=0.55)


def vox_fill(groups, rgb, rnd, region, center, kind="box", amount=0.04):
    """Fill a region of voxels. region = half sizes (hx, hy, hz); kind box or ellipsoid; center in world units."""
    hx, hy, hz = region
    for i in range(-int(hx / CUBE) - 1, int(hx / CUBE) + 2):
        for j in range(-int(hy / CUBE) - 1, int(hy / CUBE) + 2):
            for k in range(-int(hz / CUBE) - 1, int(hz / CUBE) + 2):
                x, y, z = i * CUBE, j * CUBE, k * CUBE
                if kind == "box":
                    ok = abs(x) <= hx and abs(y) <= hy and abs(z) <= hz
                else:
                    ok = (x / hx) ** 2 + (y / hy) ** 2 + (z / hz) ** 2 <= 1.0
                if ok:
                    add(groups, jitter(rgb, rnd, amount), (center[0] + x, center[1] + y, center[2] + z))


def voxel_duck(origin, yaw, s=1.0, seed=7):
    """The angry guardian: a big voxel duck with a feathered wing, orange beak and feet, red-eyed scowl. Front is -y. The cubes
    are built axis-aligned and the whole object is then turned (turning each cube's position without the cube leaves gaps)."""
    rnd = random.Random(seed)
    local = {}
    white, shade = (0.92, 0.94, 0.98), (0.70, 0.80, 0.95)
    vox_fill(local, white, rnd, (4.2, 5.4, 3.0), (0, 0.6, 5.0), "ellipsoid")
    vox_fill(local, shade, rnd, (3.4, 4.2, 1.6), (0, 0.4, 3.0), "ellipsoid")
    vox_fill(local, white, rnd, (1.3, 1.3, 2.6), (0, -3.6, 8.6), "box")
    vox_fill(local, white, rnd, (2.3, 2.5, 2.0), (0, -4.2, 11.4), "ellipsoid")
    vox_fill(local, white, rnd, (1.6, 1.4, 1.6), (0, 6.0, 6.0), "ellipsoid")
    orange = (1.0, 0.45, 0.03)
    for sx in (-1, 1):
        vox_fill(local, shade, rnd, (0.7, 3.4, 2.0), (sx * 4.4, 1.0, 5.4), "ellipsoid", 0.06)
        vox_fill(local, orange, rnd, (0.45, 0.45, 1.3), (sx * 1.7, 0.0, 1.3), "box", 0.03)
        vox_fill(local, orange, rnd, (1.2, 1.7, 0.3), (sx * 1.7, -1.0, 0.3), "box", 0.03)
        vox_fill(local, (0.02, 0.02, 0.03), rnd, (0.55, 0.3, 0.7), (sx * 1.25, -6.1, 12.0), "box", 0.0)
        vox_fill(local, (1.0, 0.05, 0.05), rnd, (0.3, 0.2, 0.35), (sx * 1.25, -6.45, 12.0), "box", 0.0)
        brow = {}
        vox_fill(brow, (0.02, 0.02, 0.03), rnd, (1.0, 0.25, 0.28), (sx * 1.25, -6.2, 13.2 + (0.35 if sx > 0 else -0.0)), "box", 0.0)
        for rgb, pts in brow.items():
            local.setdefault(rgb, []).extend(pts)
    vox_fill(local, orange, rnd, (1.4, 1.8, 0.6), (0, -6.7, 11.0), "box", 0.03)
    vox_fill(local, (1.0, 0.38, 0.03), rnd, (1.2, 1.4, 0.3), (0, -6.4, 10.1), "box", 0.03)
    objs = voxel_object("duck", local)
    root = bpy.data.objects.new("duck", None)
    bpy.context.scene.collection.objects.link(root)
    root.location = origin
    root.rotation_euler = (0, 0, yaw)
    root.scale = (s, s, s)
    for o in objs:
        o.parent = root
    return root


def brick_boss(model, origin, yaw, scale=1.0):
    """A real brick model from art/renders/models (the same data the game's boss is built from), one mesh per colour. The model's
    front (-Z) turns to face the camera (-y) at yaw 0."""
    import bmesh, json
    from mathutils import Matrix
    parts = json.load(open(os.path.join(ROOT, "models", model + ".json")))
    root = bpy.data.objects.new(model, None)
    bpy.context.scene.collection.objects.link(root)
    root.location = origin
    root.rotation_euler = (0, 0, yaw)
    root.scale = (scale, scale, scale)
    buckets = {}
    for p in parts:
        buckets.setdefault((p["r"], p["g"], p["b"]), []).append(p)

    def lin(c):
        c = c / 255
        return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4
    for key, plist in buckets.items():
        mesh = bpy.data.meshes.new(model)
        bm = bmesh.new()
        for p in plist:
            # model (x, y up, z back) -> scene (-x, z, y): a half turn about the vertical, so the front faces -y
            m = (Matrix.Translation((-p["x"], p["z"], p["y"])) @ Matrix.Diagonal((p["sx"] / 2, p["sz"] / 2, p["sy"] / 2, 1)))
            bmesh.ops.create_cube(bm, size=2.0, matrix=m)
        bm.to_mesh(mesh)
        bm.free()
        material = mat("b", (lin(key[0]), lin(key[1]), lin(key[2])), 0.42)
        mesh.materials.append(material)
        o = bpy.data.objects.new(model, mesh)
        bpy.context.scene.collection.objects.link(o)
        o.parent = root
    return root


def shot_wide():
    setup((1920, 1080))
    gradient_sky()
    desert()
    hero = (7.5, 0, 14.5)
    voxel_egg(hero, 5.2, 6.6, seed=3)
    avatar(7.5, -1, 0, (0.1, 0.45, 1.0), (0.2, 0.7, 0.2), (1.0, 0.55, 0.04), yaw=0, arms=(0.1, 0.1), stride=0.5, lean=0.0, scale=1.25)
    brick_boss("BossCosmic", (-12.5, -3, 0), 0.55, 1.55)  # Final Boss Hamster, furious
    sparkles((3, -4, 12), (14, 2, 8), 18, 5)
    light("SUN", (20, -30, 50), 2.6, (1.0, 0.95, 0.85))
    light("AREA", (-10, -30, 14), 1800, (1.0, 0.95, 0.85), size=12, target=(0, 0, 8))
    light("AREA", (8, -45, 6), 2600, (1.0, 0.97, 0.9), size=14, target=(7.5, 0, 4))  # fills the avatar's face
    camera((0, -50, 11.5), (0.0, 0, 11.0), lens=30)
    render(os.path.join(ROOT, "thumb_wide.png"))


def shot_icon():
    setup((1024, 1024))
    gradient_sky()
    desert()
    hero = (0, 0, 15.0)
    voxel_egg(hero, 5.4, 6.8, seed=3)
    avatar(0, -1, 0, (0.1, 0.45, 1.0), (0.2, 0.7, 0.2), (1.0, 0.55, 0.04), yaw=0, arms=(0.1, 0.1), stride=0.5, scale=1.25)
    sparkles((0, -4, 12), (10, 2, 8), 14, 9)
    light("SUN", (20, -30, 50), 2.6, (1.0, 0.95, 0.85))
    light("AREA", (-10, -30, 14), 1800, (1.0, 0.95, 0.85), size=12, target=(0, 0, 8))
    camera((0, -36, 7.0), (0, 0, 7.3), lens=38)
    render(os.path.join(ROOT, "thumb_icon.png"))


shot_wide()
shot_icon()
print("done")
