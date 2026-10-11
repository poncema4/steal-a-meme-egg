"""Renders ONE brick model (art/renders/models/<Name>.json) as a portrait on a transparent background, the way a sticker icon is lit:
a front three-quarter view, an orthographic camera fitted to the model, a soft key light and a fill.
Usage: blender -b -P scripts/preview/portrait.py -- model.json out.png [yawDegrees=28] [elevationDegrees=14] [size=1024]"""
import bpy, sys, json, math, bmesh
from mathutils import Vector, Matrix

args = sys.argv[sys.argv.index("--") + 1:]
data, out = json.load(open(args[0])), args[1]
yaw = math.radians(float(args[2]) if len(args) > 2 else 28)
elev = math.radians(float(args[3]) if len(args) > 3 else 14)
size = int(args[4]) if len(args) > 4 else 1024


def B(x, y, z):  # Roblox -> Blender
    return (x, -z, y)


def lin(c):
    c = c / 255
    return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4


bpy.ops.wm.read_factory_settings(use_empty=True)
sc = bpy.context.scene
sc.render.engine = "BLENDER_EEVEE_NEXT"
sc.render.resolution_x = sc.render.resolution_y = size
sc.render.film_transparent = True
sc.render.image_settings.color_mode = "RGBA"
sc.eevee.taa_render_samples = 48
sc.view_settings.view_transform = "Standard"
world = bpy.data.worlds.new("w"); sc.world = world; world.use_nodes = True
bg = world.node_tree.nodes["Background"]
bg.inputs[0].default_value = (1, 1, 1, 1); bg.inputs[1].default_value = 0.55  # a soft white fill from everywhere

buckets = {}
lo = [1e9] * 3
hi = [-1e9] * 3
for p in data:
    if p["sy"] <= 0:
        continue
    buckets.setdefault((p["r"], p["g"], p["b"]), []).append(p)
    c = B(p["x"], p["y"], p["z"])
    for i in range(3):
        lo[i] = min(lo[i], c[i] - 0.5 * max(p["sx"], p["sy"], p["sz"]))
        hi[i] = max(hi[i], c[i] + 0.5 * max(p["sx"], p["sy"], p["sz"]))
for key, plist in buckets.items():
    mesh = bpy.data.meshes.new("m")
    bm = bmesh.new()
    for p in plist:
        sx, sy = (p["sy"], p["sx"]) if p.get("rolled") else (p["sx"], p["sy"])
        m = (Matrix.Translation(B(p["x"], p["y"], p["z"])) @ Matrix.Rotation(p["yaw"], 4, "Z")
             @ Matrix.Diagonal((sx / 2, p["sz"] / 2, sy / 2, 1)))
        bmesh.ops.create_cube(bm, size=2.0, matrix=m)
    bm.to_mesh(mesh)
    bm.free()
    mat = bpy.data.materials.new("m"); mat.use_nodes = True
    bsdf = mat.node_tree.nodes["Principled BSDF"]
    bsdf.inputs["Base Color"].default_value = (lin(key[0]), lin(key[1]), lin(key[2]), 1)
    bsdf.inputs["Roughness"].default_value = 0.45
    mesh.materials.append(mat)
    obj = bpy.data.objects.new("o", mesh)
    sc.collection.objects.link(obj)

centre = Vector(((lo[0] + hi[0]) / 2, (lo[1] + hi[1]) / 2, (lo[2] + hi[2]) / 2))
radius = max(hi[0] - lo[0], hi[2] - lo[2], hi[1] - lo[1])
# front is +Y in Blender; the camera stands in front, turned by `yaw` to the side and raised by `elev`
direction = Vector((math.sin(yaw) * math.cos(elev), math.cos(yaw) * math.cos(elev), math.sin(elev)))
camera = bpy.data.objects.new("cam", bpy.data.cameras.new("cam"))
sc.collection.objects.link(camera); sc.camera = camera
camera.data.type = "ORTHO"
camera.data.ortho_scale = radius * 1.15
camera.location = centre + direction * (radius * 4)
camera.data.clip_end = 1000
camera.rotation_euler = (centre - camera.location).to_track_quat("-Z", "Y").to_euler()

for energy, rot in ((3.4, (math.radians(55), 0, math.radians(35))), (1.2, (math.radians(70), 0, math.radians(-120)))):
    bpy.ops.object.light_add(type="SUN", location=(0, 0, 100))
    sun = bpy.context.object; sun.data.energy = energy; sun.rotation_euler = rot
sc.render.filepath = out
bpy.ops.render.render(write_still=True)
print("rendered", out)
