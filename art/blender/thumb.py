"""Store art for Raid a Meme Egg, modelled on trending Roblox thumbnails (bright, saturated, one clear moment, two big
avatars fighting over one huge egg, room for huge text). Renders art/renders/thumb_wide.png (1920x1080) and
art/renders/thumb_icon.png (1024x1024). Text is added afterwards by brand/make_thumb.py.
Usage: scripts/blender.sh art/blender/thumb.py   (Blender 4.5 portable in ~/tools, see docs/WORKFLOW.md)"""
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


def egg(loc, scale, color, emit=None, rough=0.25):
    m = mat("egg", color, rough, emit=emit)
    bpy.ops.mesh.primitive_uv_sphere_add(radius=1, location=loc, segments=48, ring_count=32)
    o = bpy.context.object
    o.scale = (scale, scale, scale * 1.28)
    o.data.materials.append(m)
    bpy.ops.object.shade_smooth()
    return o


def spots(center, scale, color, n=9, seed=3):
    random.seed(seed)
    m = mat("spot", color, 0.4)
    for _ in range(n):
        a, b = random.uniform(0, math.tau), random.uniform(-0.6, 0.7)
        r = scale
        p = (center[0] + r * math.cos(a) * math.cos(b) * 0.98, center[1] + r * math.sin(a) * math.cos(b) * 0.98 - 0.1, center[2] + r * 1.28 * math.sin(b))
        bpy.ops.mesh.primitive_uv_sphere_add(radius=random.uniform(0.12, 0.3) * scale, location=p, segments=16, ring_count=10)
        bpy.context.object.data.materials.append(m)


def sparkles(center, spread, n, seed):
    random.seed(seed)
    m = mat("spark", (1, 0.85, 0.2), 0.2, emit=(1.0, 0.75, 0.1))
    m.node_tree.nodes["Principled BSDF"].inputs["Emission Strength"].default_value = 5
    for _ in range(n):
        p = [center[i] + random.uniform(-spread[i], spread[i]) for i in range(3)]
        bpy.ops.mesh.primitive_ico_sphere_add(radius=random.uniform(0.06, 0.2), location=p, subdivisions=1)
        bpy.context.object.data.materials.append(m)


def rays(center, length, n, color, y):
    """A flat sunburst behind the hero egg: wedge-shaped emissive planes."""
    m = mat("ray", color, 0.5, emit=color)
    m.node_tree.nodes["Principled BSDF"].inputs["Emission Strength"].default_value = 2.2
    for k in range(n):
        a = k * math.tau / n
        bpy.ops.mesh.primitive_cone_add(vertices=3, radius1=length * 0.09, depth=length, location=(center[0] + math.cos(a) * length / 2, y, center[2] + math.sin(a) * length / 2))
        o = bpy.context.object
        o.rotation_euler = (math.pi / 2, 0, 0)
        o.rotation_euler = (0, 0, 0)
        o.rotation_mode = "XYZ"
        o.rotation_euler = (math.pi / 2, math.atan2(math.sin(a), math.cos(a)) - math.pi / 2 + math.pi / 2 * 0, 0)
        o.scale = (1, 0.02, 1)
        o.data.materials.append(m)


def world_ground(y_back=40):
    grass = mat("grass", (0.25, 0.8, 0.2), 0.8)
    box("lawn", (200, 120, 1), (0, 0, -0.5), grass, 0, 0)
    belt = mat("belt", (0.12, 0.12, 0.16), 0.7)
    box("belt", (200, 9, 0.6), (0, -2, 0.3), belt, 0.02, 0)
    stripe = mat("stripe", (1.0, 0.85, 0.0), 0.5)
    for k in range(-9, 10):
        box("stripe", (1.4, 9, 0.05), (k * 8, -2, 0.62), stripe, 0, 0)


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


def hexes(center, scale, n, color, seed=4):
    """Gold hexagonal plates studding the egg shell (the 'jewelled egg' look the popular thumbnails use)."""
    random.seed(seed)
    m = mat("plate", color, 0.25, 0.25)
    for _ in range(n):
        a = random.uniform(-2.6, -0.5)  # facing the camera (-y side)
        b = random.uniform(-0.55, 1.1)
        nx, ny, nz = math.cos(b) * math.cos(a), math.cos(b) * math.sin(a), math.sin(b)
        p = (center[0] + nx * scale * 1.0, center[1] + ny * scale * 1.0, center[2] + nz * scale * 1.28)
        bpy.ops.mesh.primitive_cylinder_add(vertices=6, radius=random.uniform(0.35, 0.7), depth=0.3, location=p)
        o = bpy.context.object
        d = Vector((nx, ny, nz * 0.8))
        o.rotation_euler = d.to_track_quat("Z", "Y").to_euler()
        o.data.materials.append(m)
        bpy.ops.object.shade_smooth()


def goose(ox, oy, yaw, s=1.0):
    """A chunky voxel-style angry goose: the pet the thief is stealing from. Front is -y at yaw 0."""
    root = bpy.data.objects.new("goose", None)
    bpy.context.scene.collection.objects.link(root)
    root.location = (ox, oy, 0)
    root.rotation_euler = (0, 0, yaw)
    root.scale = (s, s, s)
    white = mat("goose", (0.97, 0.97, 0.98), 0.5)
    shade = mat("gooseshade", (0.75, 0.82, 0.95), 0.5)
    orange = mat("orange", (1.0, 0.45, 0.02), 0.35)
    black = mat("gblack", (0.01, 0.01, 0.015), 0.3)
    red = mat("gred", (1.0, 0.05, 0.05), 0.3, emit=(1.0, 0.0, 0.0))

    def put(o, loc):
        o.parent = root
        o.location = loc
        return o

    put(box("body", (7, 9, 5.5), (0, 0, 0), white, 0.5, 1), (0, 0.5, 4.6))
    put(box("belly", (6, 7, 3), (0, 0, 0), shade, 0.5, 1), (0, 0.2, 3.1))
    put(box("neck", (2.4, 2.4, 5), (0, 0, 0), white, 0.4, 1), (0, -3.2, 8.4))
    put(box("head", (3.8, 4.2, 3.4), (0, 0, 0), white, 0.5, 1), (0, -3.8, 11.2))
    put(box("beak", (2.6, 3.4, 1.2), (0, 0, 0), orange, 0.2, 1), (0, -6.2, 10.6))
    put(box("beaklow", (2.3, 2.6, 0.6), (0, 0, 0), orange, 0.1, 1), (0, -5.9, 9.8))
    for sx in (-1, 1):
        put(box("eye", (0.9, 0.5, 1.1), (0, 0, 0), black, 0.1, 0), (sx * 1.35, -5.85, 11.9))
        put(box("pupil", (0.35, 0.3, 0.45), (0, 0, 0), red, 0.05, 0), (sx * 1.35, -6.15, 11.9))
        brow = put(box("brow", (1.5, 0.4, 0.45), (0, 0, 0), black, 0.05, 0), (sx * 1.35, -6.0, 12.75))
        brow.rotation_euler = (0, sx * 0.55, 0)
        put(box("wing", (1.2, 6, 3.6), (0, 0, 0), shade, 0.3, 1), (sx * 3.9, 0.8, 5.0))
        put(box("leg", (0.9, 0.9, 2.6), (0, 0, 0), orange, 0.1, 0), (sx * 1.6, -0.2, 1.3))
        put(box("foot", (2.2, 3, 0.45), (0, 0, 0), orange, 0.1, 0), (sx * 1.6, -1.1, 0.25))
    put(box("tail", (3, 2.4, 2.4), (0, 0, 0), white, 0.3, 1), (0, 5.4, 5.6))
    return root


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


def shot_wide():
    setup((1920, 1080))
    gradient_sky()
    desert()
    # the hero egg, lifted overhead by the thief
    hero = (7.5, 0, 13.2)
    egg(hero, 5.4, (0.45, 0.05, 0.9), emit=(0.18, 0.0, 0.4), rough=0.08)
    hexes(hero, 5.4, 26, (1.0, 0.62, 0.05))
    avatar(7.5, -1, 0, (0.1, 0.45, 1.0), (0.05, 0.12, 0.35), (1.0, 0.78, 0.1), yaw=0, arms=(0.1, 0.1), stride=0.5, lean=0.0, scale=1.35)
    goose(-13, -6, math.pi / 2 - 0.55, 1.45)
    sparkles((3, -4, 12), (14, 2, 8), 18, 5)
    light("SUN", (20, -30, 50), 2.6, (1.0, 0.95, 0.85))
    light("AREA", (-10, -30, 14), 1800, (1.0, 0.95, 0.85), size=12, target=(0, 0, 8))
    camera((0, -50, 11.5), (0.0, 0, 11.0), lens=30)
    render(os.path.join(ROOT, "thumb_wide.png"))


def shot_icon():
    setup((1024, 1024))
    gradient_sky()
    desert()
    hero = (0, 0, 13.8)
    egg(hero, 5.6, (0.45, 0.05, 0.9), emit=(0.18, 0.0, 0.4), rough=0.08)
    hexes(hero, 5.6, 28, (1.0, 0.62, 0.05))
    avatar(0, -1, 0, (0.1, 0.45, 1.0), (0.05, 0.12, 0.35), (1.0, 0.78, 0.1), yaw=0, arms=(0.1, 0.1), stride=0.5, scale=1.35)
    sparkles((0, -4, 12), (10, 2, 8), 14, 9)
    light("SUN", (20, -30, 50), 2.6, (1.0, 0.95, 0.85))
    light("AREA", (-10, -30, 14), 1800, (1.0, 0.95, 0.85), size=12, target=(0, 0, 8))
    camera((0, -36, 9.5), (0, 0, 9.6), lens=38)
    render(os.path.join(ROOT, "thumb_icon.png"))


shot_wide()
shot_icon()
print("done")
