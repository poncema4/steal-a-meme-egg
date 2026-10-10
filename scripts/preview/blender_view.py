"""Renders the dumped map (scripts/preview/dump.luau -> map.json) as a real 3D picture with Blender, so layout and models can be
judged without Studio. Every part becomes a box (cylinders and meshes are approximated), coloured as in the game.
Usage: blender -b -P scripts/preview/blender_view.py -- map.json out.png camX camY camZ targetX targetY targetZ [lens] [x0 x1]
Coordinates are Roblox's (x east, y up, z south); the script converts them."""
import bpy, sys, json, math
from mathutils import Vector

args = sys.argv[sys.argv.index("--") + 1:]
data, out = json.load(open(args[0])), args[1]
cam = [float(v) for v in args[2:5]]
target = [float(v) for v in args[5:8]]
lens = float(args[8]) if len(args) > 8 else 28
x0 = float(args[9]) if len(args) > 9 else -1e9
x1 = float(args[10]) if len(args) > 10 else 1e9


def B(x, y, z):  # Roblox -> Blender
    return (x, -z, y)


def lin(c):
    c = c / 255
    return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4


bpy.ops.wm.read_factory_settings(use_empty=True)
sc = bpy.context.scene
sc.render.engine = "BLENDER_EEVEE_NEXT"
sc.render.resolution_x, sc.render.resolution_y = 1400, 800
sc.eevee.taa_render_samples = 24
sc.view_settings.view_transform = "Standard"
world = bpy.data.worlds.new("w"); sc.world = world; world.use_nodes = True
bg = world.node_tree.nodes["Background"]
bg.inputs[0].default_value = (0.35, 0.62, 1.0, 1); bg.inputs[1].default_value = 1.1

mats = {}
cube = None
for p in data:
    if not (x0 <= p["x"] <= x1) or p["sy"] <= 0:
        continue
    key = (p["r"], p["g"], p["b"])
    if key not in mats:
        m = bpy.data.materials.new("m"); m.use_nodes = True
        b = m.node_tree.nodes["Principled BSDF"]
        b.inputs["Base Color"].default_value = (lin(p["r"]), lin(p["g"]), lin(p["b"]), 1)
        b.inputs["Roughness"].default_value = 0.6
        mats[key] = m
    bpy.ops.mesh.primitive_cube_add(location=B(p["x"], p["y"], p["z"]))
    o = bpy.context.object
    sx, sy = (p["sy"], p["sx"]) if p.get("rolled") else (p["sx"], p["sy"])
    o.scale = (sx / 2, p["sz"] / 2, sy / 2)
    o.rotation_euler = (0, 0, p["yaw"])
    o.data.materials.append(mats[key])

bpy.ops.object.light_add(type="SUN", location=(0, 0, 100))
sun = bpy.context.object; sun.data.energy = 3.2; sun.rotation_euler = (math.radians(50), 0, math.radians(35))
camera = bpy.data.objects.new("cam", bpy.data.cameras.new("cam"))
sc.collection.objects.link(camera); sc.camera = camera
camera.location = B(*cam); camera.data.lens = lens; camera.data.clip_end = 3000
camera.rotation_euler = (Vector(B(*target)) - Vector(B(*cam))).to_track_quat("-Z", "Y").to_euler()
sc.render.filepath = out
bpy.ops.render.render(write_still=True)
print("rendered", out)
