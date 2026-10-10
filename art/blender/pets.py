"""Portraits of every character for the Index and Pets panels: glossy toy-style 3D creatures on a transparent background, one
silhouette each (a toast, a bean, a sock, a pickle, geese, cats, meme lords...). Each character is a recipe: a body shape, its
colours, a face and a few accessories. Renders art/renders/pets/<CharacterId>.png (512x512).
Usage: ~/tools/blender-4.5.14-linux-x64/blender -b -P art/blender/pets.py [-- OnlyCharacterId]"""
import sys, os, math, random
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import kit
from kit import *

OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "renders", "pets")
os.makedirs(OUT, exist_ok=True)
kit.OUT = OUT

BLACK = (0.02, 0.02, 0.03)
WHITE = (1, 1, 1)
GOLD = (1.0, 0.72, 0.08)
RED = (0.95, 0.12, 0.12)


def m(name, rgb, rough=0.25):
    return gloss(name, rgb, rough)


def cone_up(name, r1, r2, depth, loc, material, verts=32, rot=(0, 0, 0)):
    bpy.ops.mesh.primitive_cone_add(vertices=verts, radius1=r1, radius2=r2, depth=depth, location=loc, rotation=rot)
    o = bpy.context.object
    o.name = name
    o.data.materials.append(material)
    bpy.ops.object.shade_smooth()
    return o


def torus(r, minor, loc, material, rot=(0, 0, 0)):
    bpy.ops.mesh.primitive_torus_add(major_radius=r, minor_radius=minor, location=loc, rotation=rot)
    o = bpy.context.object
    o.data.materials.append(material)
    bpy.ops.object.shade_smooth()
    return o


# ------------------------------------------------------------------ bodies (all centred on x=0, facing the camera at -y)
def body(kind, c, accent):
    main, side = m("main", c), m("accent", accent)
    if kind == "egg":
        sph("body", 1.25, (0, 0, 1.75), main, (1, 1, 1.2))
        return 2.9
    if kind == "bean":
        sph("body", 1.1, (0, 0, 1.55), main, (1.3, 0.95, 1.0))
        sph("bump", 0.35, (0.55, -0.6, 2.2), side, (1, 0.8, 0.8))
        return 2.55
    if kind == "slice":  # a slice of toast
        box("crust", (2.9, 0.8, 2.9), (0, 0.1, 1.6), side, 0.35, 1)
        box("front", (2.5, 0.8, 2.5), (0, -0.2, 1.6), main, 0.3, 1)
        sph("top1", 0.95, (-0.85, 0.1, 2.9), side, (1, 0.8, 0.9))
        sph("top2", 0.95, (0.85, 0.1, 2.9), side, (1, 0.8, 0.9))
        return 3.0
    if kind == "tube":  # a sock, a pickle, a noodle
        cyl("tube", 0.95, 2.4, (0, 0, 1.7), main, 40, 0.05)
        sph("cap1", 0.95, (0, 0, 2.9), main)
        sph("cap2", 0.95, (0, 0, 0.5), main)
        return 3.3
    if kind == "sock":
        cyl("leg", 0.85, 2.0, (0, 0, 2.2), main, 40, 0.05)
        box("foot", (1.7, 2.2, 1.0), (0.2, -0.7, 0.85), main, 0.45, 1)
        sph("heel", 0.9, (0, 0.5, 1.0), main)
        for z in (3.0, 2.55):
            cyl("stripe", 0.9, 0.22, (0, 0, z), side, 40, 0.02)
        return 3.2
    if kind == "cup":
        cone_up("cup", 0.85, 1.15, 1.9, (0, 0, 1.25), main)
        sph("foam", 1.15, (0, 0, 2.25), side, (1, 1, 0.45))
        torus(0.5, 0.14, (1.25, 0, 1.3), main, (math.pi / 2, 0, 0))
        return 2.7
    if kind == "cone":  # a volcano
        cone_up("volcano", 1.9, 0.6, 2.4, (0, 0, 1.25), main)
        sph("lava", 0.75, (0, 0, 2.5), side, (1, 1, 0.7))
        return 3.0
    if kind == "ring":  # a bagel
        torus(1.1, 0.62, (0, 0, 1.7), main, (math.pi / 2, 0, 0))
        torus(1.1, 0.15, (0, -0.3, 1.7), side, (math.pi / 2, 0, 0))
        return 2.8
    if kind == "crescent":  # a croissant
        for i, (x, z, r) in enumerate([(-1.45, 1.0, 0.5), (-0.95, 1.65, 0.7), (-0.2, 2.0, 0.9), (0.55, 1.95, 0.8), (1.15, 1.45, 0.62), (1.45, 0.85, 0.45)]):
            sph("seg", r, (x, 0, z), main, (1, 0.9, 1))
        return 2.9
    if kind == "blob":
        sph("body", 1.3, (0, 0, 1.45), main, (1.1, 1, 0.95))
        sph("belly", 0.85, (0, -0.75, 1.1), side, (1, 0.5, 0.9))
        return 2.8
    if kind == "stack":  # pancakes
        for i in range(4):
            cyl("cake", 1.3 - 0.03 * i, 0.5, (0, 0, 0.55 + i * 0.52), main, 48, 0.12)
        cyl("syrup", 1.18, 0.12, (0, 0, 2.7), side, 48, 0.02)
        sph("butter", 0.4, (0, 0, 2.95), m("butter", (1, 0.95, 0.5)), (1, 1, 0.5))
        return 3.1
    if kind == "goose":
        sph("body", 1.25, (0, 0.2, 1.1), main, (1.15, 1, 0.9))
        cyl("neck", 0.45, 1.6, (0, -0.2, 2.2), main, 24, 0.03)
        sph("head", 0.75, (0, -0.35, 3.0), main)
        cone_up("beak", 0.4, 0.1, 0.9, (0, -1.0, 2.9), side, 24, (math.pi / 2, 0, 0))
        return 3.8
    if kind == "sneaker":
        box("sole", (3.2, 1.3, 0.5), (0, 0, 0.5), m("sole", WHITE), 0.2)
        box("toe", (1.5, 1.25, 0.95), (0.85, 0, 1.15), main, 0.3, 1)
        box("heel", (1.7, 1.25, 1.9), (-0.7, 0, 1.5), main, 0.3, 1)
        box("tongue", (0.6, 1.0, 1.0), (0.05, 0, 2.3), side, 0.2)
        return 2.7
    if kind == "moth":
        sph("body", 0.85, (0, 0, 1.6), main, (0.85, 0.9, 1.5))
        return 3.1
    sph("body", 1.25, (0, 0, 1.6), main)
    return 2.8


# ------------------------------------------------------------------ faces
def face(style, z, spread=0.5, y=-1.0):
    dark, hi = m("eye", BLACK, 0.2), m("hi", WHITE, 0.2)
    if style == "sleepy":
        for s in (-1, 1):
            sph("eye", 0.22, (s * spread, y, z), dark, (1.8, 0.4, 0.45))
        return
    if style == "shades":
        box("shades", (spread * 2.8, 0.3, 0.5), (0, y, z), dark, 0.08)
        for s in (-1, 1):
            box("lens", (spread * 1.2, 0.34, 0.42), (s * spread * 0.62, y - 0.04, z), m("lens", (0.1, 0.1, 0.2), 0.05), 0.08)
        return
    if style == "star":
        for s in (-1, 1):
            sph("eye", 0.3, (s * spread, y, z), m("star", (1, 0.9, 0.1)), (1, 0.4, 1))
        return
    if style == "dizzy":
        for s in (-1, 1):
            torus(0.2, 0.05, (s * spread, y, z), dark, (math.pi / 2, 0, 0))
        return
    for s in (-1, 1):
        sph("eye", 0.2, (s * spread, y, z), dark, (1, 0.5, 1.4))
        sph("shine", 0.07, (s * spread + 0.06, y - 0.12, z + 0.12), hi)
    if style == "angry":
        for s in (-1, 1):
            b = box("brow", (0.55, 0.12, 0.14), (s * spread, y - 0.05, z + 0.38), dark, 0.03)
            b.rotation_euler = (0, s * 0.5, 0)
    sph("mouth", 0.18, (0, y, z - 0.38), dark, (1.8, 0.4, 0.9))


# ------------------------------------------------------------------ accessories
def acc(name, top, c=None):
    c = c or GOLD
    mat_ = m("acc", c)
    if name == "crown":
        cyl("band", 0.65, 0.3, (0, 0, top + 0.1), mat_, 24, 0.03)
        for k in range(5):
            a = k * math.tau / 5
            cone_up("tip", 0.16, 0.02, 0.5, (math.cos(a) * 0.55, math.sin(a) * 0.55, top + 0.45), mat_, 12)
        sph("gem", 0.12, (0, -0.65, top + 0.1), m("gem", RED))
    elif name == "halo":
        torus(0.7, 0.07, (0, 0, top + 0.55), m("halo", (1, 0.95, 0.4), 0.1))
    elif name == "horns":
        for s in (-1, 1):
            cone_up("horn", 0.25, 0.02, 0.9, (s * 0.8, 0, top - 0.1), mat_, 16, (0, s * 0.4, 0))
    elif name == "antennae":
        for s in (-1, 1):
            cyl("ant", 0.05, 0.9, (s * 0.35, 0, top + 0.35), m("antenna", BLACK), 8, 0.0)
            sph("ball", 0.14, (s * 0.5, 0, top + 0.8), mat_)
    elif name == "cat_ears":
        for s in (-1, 1):
            cone_up("ear", 0.4, 0.02, 0.7, (s * 0.75, 0, top - 0.05), mat_, 3, (0, s * 0.2, 0))
    elif name == "dog_ears":
        for s in (-1, 1):
            sph("ear", 0.45, (s * 1.25, 0, top - 0.5), mat_, (0.55, 0.5, 1.2))
    elif name == "wings":
        for s in (-1, 1):
            sph("wing", 0.9, (s * 1.7, 0.25, top - 0.9), mat_, (0.35, 0.18, 1.1))
    elif name == "moth_wings":
        for s in (-1, 1):
            sph("wing", 1.2, (s * 1.5, 0.2, 1.9), mat_, (1.0, 0.12, 1.3))
            sph("wing2", 0.8, (s * 1.15, 0.2, 0.9), mat_, (0.9, 0.12, 0.9))
    elif name == "flame":
        for k, h in enumerate((0.9, 0.65, 0.55)):
            cone_up("flame", 0.28, 0.0, h, ((k - 1) * 0.4, 0, top + h / 2), m("flame", (1, 0.45 + 0.2 * k, 0.05)), 12)
    elif name == "disco":
        sph("ball", 0.5, (0, 0, top + 0.45), m("mirror", (0.85, 0.9, 1.0), 0.05))
        for k in range(8):
            a = k * math.tau / 8
            box("facet", (0.16, 0.16, 0.16), (math.cos(a) * 0.45, math.sin(a) * 0.45, top + 0.45 + (k % 3) * 0.14 - 0.14), m("facet", (1, 0.4, 0.9)), 0.02)
    elif name == "chili":
        cone_up("chili", 0.4, 0.05, 1.3, (0.2, 0, top + 0.5), m("chili", RED), 16, (0, 0.5, 0))
        cone_up("stem", 0.1, 0.1, 0.35, (-0.18, 0, top + 1.05), m("stem", (0.2, 0.7, 0.2)), 8)
    elif name == "stars":
        for k in range(7):
            a = k * math.tau / 7
            sph("star", 0.14, (math.cos(a) * 1.35, -0.6, top - 0.6 + math.sin(a) * 0.4), m("star", (1, 0.9, 0.1)), (1, 0.4, 1))
    elif name == "steam":
        for k in range(3):
            sph("steam", 0.2 + 0.05 * k, (math.sin(k) * 0.3, 0, top + 0.35 + k * 0.4), m("steam", (0.95, 0.95, 1.0), 0.6))
    elif name == "headdress":  # the striped pharaoh cloth
        for s in (-1, 1):
            box("flap", (0.5, 0.7, 1.6), (s * 1.15, 0, top - 0.9), m("cloth", (0.15, 0.4, 0.95)), 0.08)
        for k in range(3):
            box("stripe", (2.6, 0.5, 0.18), (0, 0, top + 0.12 + k * 0.01 - 0.3 * k), mat_, 0.03)
    elif name == "aura":
        torus(1.9, 0.07, (0, 0.9, 1.7), m("aura", (1, 0.4, 0.9), 0.1), (math.pi / 2, 0, 0))
        torus(2.2, 0.05, (0, 0.95, 1.7), m("aura2", (0.4, 0.8, 1.0), 0.1), (math.pi / 2, 0, 0))
    elif name == "swirl":
        torus(1.35, 0.1, (0, 0.5, 1.7), m("swirl", (0.7, 0.4, 1.0), 0.1), (math.pi / 2, 0, 0))
    elif name == "paper":
        box("paper", (0.9, 0.08, 1.2), (1.35, -0.8, 1.5), m("paper", (0.98, 0.98, 0.9), 0.6), 0.02)
    elif name == "sheen":
        sph("sheen", 0.28, (-0.6, -1.15, top - 0.8), m("sheen", WHITE, 0.1), (1, 0.3, 2))


# name -> (body kind, main colour, accent colour, face, face height, accessories)
RECIPES = {
    "SoggyToast": ("slice", (0.93, 0.78, 0.45), (0.55, 0.33, 0.12), "sleepy", 1.9, ["steam"]),
    "BonkBean": ("bean", (0.55, 0.2, 0.12), (0.85, 0.5, 0.35), "dizzy", 1.7, ["stars"]),
    "SleepySock": ("sock", (0.95, 0.95, 1.0), (0.6, 0.35, 0.95), "sleepy", 2.4, []),
    "DiscoPickle": ("tube", (0.3, 0.75, 0.2), (0.15, 0.5, 0.1), "shades", 2.3, ["disco"]),
    "GigachadGoose": ("goose", (0.97, 0.97, 1.0), (1.0, 0.5, 0.05), "shades", 3.05, []),
    "MoonwalkMoth": ("moth", (0.45, 0.35, 0.85), (0.9, 0.85, 1.0), "star", 1.8, ["antennae", "moth_wings"]),
    "ChiliChihuahua": ("blob", (0.9, 0.65, 0.35), (1.0, 0.85, 0.65), "angry", 1.8, ["dog_ears", "chili"]),
    "LavaLatte": ("cup", (0.55, 0.3, 0.15), (1.0, 0.45, 0.08), "happy", 1.4, ["steam"]),
    "VolcanoVicar": ("cone", (0.4, 0.28, 0.25), (1.0, 0.4, 0.05), "angry", 1.5, ["flame"]),
    "PharaohPancake": ("stack", (0.95, 0.7, 0.3), (0.65, 0.3, 0.1), "happy", 1.6, ["headdress"]),
    "SphinxSneaker": ("sneaker", (0.88, 0.7, 0.3), (0.2, 0.4, 0.9), "shades", 1.6, []),
    "CleoCroissant": ("crescent", (0.9, 0.58, 0.25), (1.0, 0.8, 0.4), "happy", 2.2, ["crown"]),
    "NebulaNoodle": ("ring", (0.75, 0.45, 0.95), (1.0, 0.7, 0.9), "star", 1.7, ["swirl", "stars"]),
    "QuasarQuokka": ("blob", (0.7, 0.5, 0.3), (0.95, 0.85, 0.7), "happy", 1.8, ["cat_ears", "aura"]),
    "BlackHoleBagel": ("ring", (0.08, 0.06, 0.14), (0.7, 0.3, 1.0), "star", 1.7, ["aura"]),
    "TaxAngel": ("egg", (0.97, 0.97, 1.0), (1.0, 0.9, 0.5), "happy", 2.0, ["halo", "wings", "paper"]),
    "FinalBossHamster": ("blob", (0.95, 0.6, 0.2), (1.0, 0.9, 0.7), "angry", 1.8, ["horns"]),
    "OmegaMeme": ("egg", (0.45, 0.15, 0.85), (1.0, 0.3, 0.6), "shades", 2.1, ["crown", "aura"]),
    "GoldenGoose": ("goose", (1.0, 0.78, 0.15), (1.0, 0.45, 0.05), "happy", 3.05, ["sheen"]),
    "PlatinumGoose": ("goose", (0.8, 0.88, 0.97), (0.55, 0.65, 0.8), "shades", 3.05, ["sheen", "crown"]),
    "MythicGoose": ("goose", (0.95, 0.4, 0.9), (1.0, 0.85, 0.2), "star", 3.05, ["halo", "wings"]),
    "CosmicKitten": ("blob", (0.4, 0.45, 0.95), (0.85, 0.85, 1.0), "happy", 1.8, ["cat_ears", "stars"]),
    "NebulaCat": ("blob", (0.7, 0.3, 0.85), (1.0, 0.7, 0.95), "shades", 1.8, ["cat_ears", "aura"]),
    "GalaxyTiger": ("blob", (1.0, 0.55, 0.1), (0.1, 0.05, 0.2), "angry", 1.8, ["cat_ears", "stars", "crown"]),
    "MemeLordJr": ("egg", (0.3, 0.85, 0.5), (1.0, 0.85, 0.3), "shades", 2.1, ["crown"]),
    "MemeLordPrime": ("egg", (0.2, 0.55, 1.0), (1.0, 0.85, 0.3), "shades", 2.1, ["crown", "halo"]),
    "MemeLordOmega": ("egg", (0.95, 0.2, 0.35), (1.0, 0.85, 0.3), "shades", 2.1, ["crown", "halo", "flame", "aura"]),
}

only = sys.argv[sys.argv.index("--") + 1] if "--" in sys.argv and len(sys.argv) > sys.argv.index("--") + 1 else None
for name, (kind, c, accent, style, face_z, extras) in RECIPES.items():
    if only and name != only:
        continue
    scene()
    cam = bpy.context.scene.camera
    cam.data.ortho_scale = 7.0  # taller than the icons: geese and crowns need the room
    cam.location = (0, -10, 2.6)
    top = body(kind, c, accent)
    if kind not in ("ring", "stack", "sneaker", "crescent"):
        face(style, face_z, 0.5, -1.05 if kind not in ("slice", "cup", "sock", "goose") else -0.85 if kind != "goose" else -0.85)
    else:
        face(style, face_z, 0.5, -0.72 if kind == "stack" else -1.0 if kind == "ring" else -0.7)
    for a in extras:
        acc(a, top, accent if a in ("crown", "horns", "cat_ears", "dog_ears", "wings", "headdress", "antennae") else None)
    save(name)
print("pets done")
