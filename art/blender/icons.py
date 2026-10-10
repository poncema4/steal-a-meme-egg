"""HUD icon pack for Steal a Meme Egg: glossy toy-style 3D icons on a transparent background, like the icons in the top
Roblox simulators (chunky, saturated, one clear silhouette each). Renders art/renders/icons/<name>.png at 512x512.
Usage: ~/tools/blender-4.5.14-linux-x64/blender -b -P art/blender/icons.py"""
import sys, os, math, random
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from common import *
from mathutils import Vector

OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "renders", "icons")
os.makedirs(OUT, exist_ok=True)


def scene():
    reset()
    sc = bpy.context.scene
    sc.render.engine = "BLENDER_EEVEE_NEXT"
    sc.render.resolution_x = sc.render.resolution_y = 512
    sc.render.film_transparent = True
    sc.eevee.taa_render_samples = 64
    sc.view_settings.view_transform = "Standard"
    w = bpy.data.worlds.new("w"); sc.world = w; w.use_nodes = True
    w.node_tree.nodes["Background"].inputs[0].default_value = (1, 1, 1, 1)
    w.node_tree.nodes["Background"].inputs[1].default_value = 0.35
    cam = bpy.data.objects.new("cam", bpy.data.cameras.new("cam"))
    sc.collection.objects.link(cam); sc.camera = cam
    cam.data.type = "ORTHO"; cam.data.ortho_scale = 5.6
    cam.location = (0, -10, 2.2)
    cam.rotation_euler = (math.radians(86), 0, 0)
    for loc, e, col in [((-4, -6, 7), 420, (1, 0.97, 0.92)), ((5, -4, 3), 150, (0.8, 0.9, 1.0))]:
        bpy.ops.object.light_add(type="AREA", location=loc)
        L = bpy.context.object; L.data.energy = e; L.data.size = 6; L.data.color = col
        L.rotation_euler = (Vector((0, 0, 1.4)) - Vector(loc)).to_track_quat("-Z", "Y").to_euler()
    return sc


def sph(name, r, loc, m, scale=(1, 1, 1)):
    bpy.ops.mesh.primitive_uv_sphere_add(radius=r, location=loc, segments=48, ring_count=32)
    o = bpy.context.object; o.name = name; o.scale = scale; o.data.materials.append(m)
    bpy.ops.object.shade_smooth()
    return o


def save(name):
    bpy.context.scene.render.filepath = os.path.join(OUT, name + ".png")
    bpy.ops.render.render(write_still=True)


def gloss(name, rgb, rough=0.18):
    return mat(name, rgb, rough)


def egg():
    scene()
    shell = gloss("shell", (0.92, 0.1, 0.7), 0.12)
    sph("egg", 1.25, (0, 0, 1.55), shell, (1, 1, 1.32))
    gold = gloss("gold", (1.0, 0.7, 0.08), 0.2)
    rnd = random.Random(4)
    for a, b, r in [(-1.7, 0.5, .26), (-1.1, 0.0, .22), (-2.3, 0.1, .24), (-1.5, -0.55, .2), (-0.8, 0.9, .18), (-2.1, 0.85, .2), (-1.3, 1.0, .16)]:
        p = (1.2 * math.cos(b) * math.cos(a), 1.2 * math.cos(b) * math.sin(a), 1.55 + 1.6 * math.sin(b))
        sph("dot", r, p, gold, (1, 0.5, 1))
    save("egg")


def paw():
    scene()
    m = gloss("paw", (1.0, 0.55, 0.05), 0.25)
    sph("pad", 1.0, (0, 0, 0.9), m, (1.2, 0.8, 0.9))
    for x, z in [(-1.35, 1.7), (-0.5, 2.25), (0.5, 2.25), (1.35, 1.7)]:
        sph("toe", 0.5, (x, 0, z), m, (0.9, 0.7, 1.15))
    save("paw")


def trophy():
    scene()
    gold = gloss("gold", (1.0, 0.75, 0.05), 0.15)
    dark = gloss("base", (0.35, 0.2, 0.08), 0.4)
    bpy.ops.mesh.primitive_cone_add(vertices=48, radius1=0.75, radius2=1.3, depth=1.7, location=(0, 0, 2.35))
    cup = bpy.context.object; cup.data.materials.append(gold); bpy.ops.object.shade_smooth()
    sph("rim", 1.3, (0, 0, 3.2), gold, (1, 1, 0.12))
    cyl("stem", 0.22, 0.9, (0, 0, 1.2), gold, 32, 0.05)
    box("plate", (1.9, 1.3, 0.35), (0, 0, 0.55), dark, 0.08)
    box("plate2", (1.4, 1.0, 0.3), (0, 0, 0.2), dark, 0.08)
    for s in (-1, 1):
        bpy.ops.mesh.primitive_torus_add(major_radius=0.55, minor_radius=0.13, location=(s * 1.45, 0, 2.7), rotation=(math.pi / 2, 0, 0))
        t = bpy.context.object; t.data.materials.append(gold); bpy.ops.object.shade_smooth()
    star = gloss("star", (1, 1, 1), 0.2)
    sph("shine", 0.18, (-0.5, -1.0, 2.7), star, (1, 0.4, 2))
    save("trophy")


def shoe():
    scene()
    body = gloss("shoe", (0.1, 0.8, 1.0), 0.2)
    white = gloss("white", (1, 1, 1), 0.3)
    red = gloss("red", (1.0, 0.15, 0.2), 0.3)
    box("sole", (3.6, 1.3, 0.5), (0, 0, 0.45), white, 0.2)
    box("toe", (1.6, 1.25, 0.9), (1.0, 0, 1.1), body, 0.3, 1)
    box("heel", (1.9, 1.25, 1.9), (-0.75, 0, 1.45), body, 0.3, 1)
    box("tongue", (0.6, 1.0, 1.1), (0.1, 0, 2.25), white, 0.2)
    for x in (0.15, 0.55, 0.95):
        box("lace", (0.12, 1.3, 0.12), (x, 0, 1.75), red, 0.02)
    sph("swoosh", 0.35, (-0.2, -0.65, 1.4), red, (2.0, 0.3, 0.5))
    save("shoe")


def cash():
    scene()
    g = gloss("bill", (0.2, 0.85, 0.25), 0.4)
    dk = gloss("billdark", (0.08, 0.5, 0.15), 0.4)
    wh = gloss("billwhite", (0.95, 1.0, 0.9), 0.5)
    for i, (dz, rot) in enumerate([(0.0, 0.0), (0.3, 0.12), (0.6, -0.1)]):
        o = box(f"bill{i}", (3.4, 1.8, 0.22), (0, 0, 0.5 + dz), g, 0.05)
        o.rotation_euler = (0, 0, rot)
        box(f"edge{i}", (3.0, 1.5, 0.05), (0, 0, 0.63 + dz), dk, 0.0).rotation_euler = (0, 0, rot)
    sph("coin", 0.55, (0, -0.1, 1.5), wh, (1, 0.3, 1))
    bpy.ops.object.text_add(location=(-0.17, -0.45, 1.25), rotation=(math.pi / 2, 0, 0))
    t = bpy.context.object; t.data.body = "$"; t.data.size = 0.85; t.data.extrude = 0.05; t.data.materials.append(dk)
    save("cash")


def cart():
    scene()
    red = gloss("cart", (0.95, 0.12, 0.12), 0.2)
    wh = gloss("white", (1, 1, 1), 0.3)
    dk = gloss("dark", (0.15, 0.15, 0.2), 0.4)
    box("basket", (2.9, 1.8, 1.4), (0.2, 0, 1.8), red, 0.2, 1)
    box("stripe", (2.95, 1.85, 0.3), (0.2, 0, 1.8), wh, 0.1)
    box("floor", (3.2, 1.9, 0.18), (0.2, 0, 1.0), dk, 0.05)
    bpy.ops.mesh.primitive_cylinder_add(radius=0.12, depth=1.8, location=(-1.55, 0, 2.55), rotation=(0, math.radians(50), 0))
    h = bpy.context.object; h.data.materials.append(dk)
    box("grip", (0.3, 1.9, 0.3), (-2.15, 0, 3.2), dk, 0.1)
    for x in (-0.7, 1.3):
        cyl("wheel", 0.38, 0.3, (x, -0.85, 0.5), dk, 32, 0.04).rotation_euler = (math.pi / 2, 0, 0)
        cyl("wheel", 0.38, 0.3, (x, 0.85, 0.5), dk, 32, 0.04).rotation_euler = (math.pi / 2, 0, 0)
    save("cart")


def book():
    scene()
    cover = gloss("cover", (0.1, 0.5, 1.0), 0.25)
    page = gloss("page", (1, 0.98, 0.9), 0.6)
    gold = gloss("gold", (1.0, 0.8, 0.1), 0.2)
    red = gloss("ribbon", (1.0, 0.15, 0.2), 0.3)
    box("back", (2.7, 0.55, 3.4), (0, 0, 1.75), cover, 0.12)
    box("pages", (2.5, 0.4, 3.2), (0.1, -0.52, 1.75), page, 0.04)
    box("front", (2.7, 0.2, 3.4), (0, -0.85, 1.75), cover, 0.12)
    box("spine", (0.3, 1.2, 3.4), (-1.3, -0.35, 1.75), cover, 0.12)
    box("band", (1.7, 0.05, 0.5), (0.2, -0.97, 2.4), gold, 0.02)
    sph("star", 0.34, (0.2, -0.99, 1.4), gold, (1, 0.2, 1))
    box("ribbon", (0.3, 0.2, 1.3), (0.9, -0.5, 0.45), red, 0.03)
    save("book")


def potion():
    scene()
    glass = gloss("liquid", (0.2, 0.95, 0.3), 0.1)
    cork = gloss("cork", (0.7, 0.45, 0.2), 0.7)
    sph("flask", 1.2, (0, 0, 1.4), glass, (1, 1, 1))
    cyl("neck", 0.45, 1.3, (0, 0, 2.7), glass, 32, 0.04)
    cyl("cork", 0.5, 0.55, (0, 0, 3.5), cork, 32, 0.05)
    wh = gloss("shine", (1, 1, 1), 0.2)
    sph("shine", 0.2, (-0.55, -1.0, 1.9), wh, (1, 0.3, 1.8))
    save("potion")


def trap():
    scene()
    cam = bpy.context.scene.camera
    cam.location = (0, -7.5, 6.2)
    cam.rotation_euler = (math.radians(50), 0, 0)
    cam.data.ortho_scale = 6.2
    steel = gloss("steel", (0.66, 0.7, 0.8), 0.22)
    dark = gloss("plate", (0.2, 0.22, 0.28), 0.35)
    red = gloss("pad", (0.95, 0.12, 0.12), 0.2)
    box("plate", (3.9, 2.9, 0.35), (0, 0, 0.2), dark, 0.12)
    # two open jaws: a flat steel ring each, ringed with teeth that point up
    for s_ in (-1, 1):
        bpy.ops.mesh.primitive_torus_add(major_radius=1.0, minor_radius=0.16, location=(s_ * 1.0, 0, 0.55))
        ring = bpy.context.object; ring.data.materials.append(steel); bpy.ops.object.shade_smooth()
        for k in range(9):
            a = math.pi * (k + 0.5) / 9 + (math.pi / 2 if s_ > 0 else -math.pi / 2) - math.pi / 2
            bpy.ops.mesh.primitive_cone_add(vertices=12, radius1=0.17, depth=0.6, location=(s_ * 1.0 + math.cos(a) * -s_ * 1.0 * -1, math.sin(a) * 1.0, 0.95))
            bpy.context.object.data.materials.append(steel)
    box("pad", (0.8, 0.8, 0.14), (0, 0, 0.42), red, 0.05)
    save("trap")


for fn in (egg, paw, trophy, shoe, cash, cart, book, potion, trap):
    fn()
print("icons done")
