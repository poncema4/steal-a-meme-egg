"""Renders the backpack item icons as real 3D pictures (smooth meshes, PBR materials, soft studio light, a thin dark outline),
like Steal an Egg's hotbar: a jagged steel bear trap and a wooden baseball bat with a taped grip.
Usage: blender -b -P art/items/render_items.py -- out_dir"""
import math
import sys

import bpy
import bmesh
from mathutils import Vector

out = sys.argv[sys.argv.index("--") + 1]


def reset():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    sc = bpy.context.scene
    sc.render.engine = "BLENDER_EEVEE_NEXT"
    sc.render.resolution_x = sc.render.resolution_y = 512
    sc.render.film_transparent = True
    sc.eevee.taa_render_samples = 64
    sc.view_settings.view_transform = "Standard"
    sc.render.use_freestyle = True
    sc.render.line_thickness_mode = "ABSOLUTE"
    sc.render.line_thickness = 2.2
    ls = sc.view_layers[0].freestyle_settings.linesets.new("outline")
    ls.select_by_visibility = True
    ls.select_silhouette, ls.select_border, ls.select_crease = True, True, False
    ls.linestyle.color = (0.06, 0.05, 0.08)
    world = bpy.data.worlds.new("w")
    world.use_nodes = True
    world.node_tree.nodes["Background"].inputs[0].default_value = (0.75, 0.78, 0.85, 1)
    world.node_tree.nodes["Background"].inputs[1].default_value = 0.22
    sc.world = world
    for name, loc, energy in (("key", (3, -4, 6), 420), ("fill", (-5, -2, 3), 110), ("rim", (0, 5, 4), 260)):
        light = bpy.data.lights.new(name, "AREA")
        light.energy, light.size = energy, 4
        obj = bpy.data.objects.new(name, light)
        obj.location = loc
        obj.rotation_euler = (Vector((0, 0, 0)) - Vector(loc)).to_track_quat("-Z", "Y").to_euler()
        sc.collection.objects.link(obj)
    return sc


def material(name, color, metallic=0.0, rough=0.5, noise=0.0):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    nt = m.node_tree
    bsdf = nt.nodes["Principled BSDF"]
    bsdf.inputs["Metallic"].default_value = metallic
    bsdf.inputs["Roughness"].default_value = rough
    if noise > 0:
        tex = nt.nodes.new("ShaderNodeTexNoise")
        tex.inputs["Scale"].default_value = 9
        tex.inputs["Detail"].default_value = 8
        ramp = nt.nodes.new("ShaderNodeValToRGB")
        ramp.color_ramp.elements[0].color = tuple(c * (1 - noise) for c in color) + (1,)
        ramp.color_ramp.elements[1].color = tuple(min(c * (1 + noise), 1) for c in color) + (1,)
        nt.links.new(tex.outputs["Fac"], ramp.inputs["Fac"])
        nt.links.new(ramp.outputs["Color"], bsdf.inputs["Base Color"])
    else:
        bsdf.inputs["Base Color"].default_value = color + (1,)
    return m


def add(obj, mat, smooth=True):
    obj.data.materials.append(mat)
    if smooth:
        for p in obj.data.polygons:
            p.use_smooth = True
    return obj


def camera(sc, loc, target, scale):
    cam = bpy.data.cameras.new("cam")
    cam.type = "ORTHO"
    cam.ortho_scale = scale
    obj = bpy.data.objects.new("cam", cam)
    obj.location = loc
    obj.rotation_euler = (Vector(target) - Vector(loc)).to_track_quat("-Z", "Y").to_euler()
    sc.collection.objects.link(obj)
    sc.camera = obj


def trap():
    sc = reset()
    steel = material("steel", (0.46, 0.33, 0.32), metallic=0.75, rough=0.55, noise=0.45)  # worn, a little rusty
    dark = material("dark", (0.12, 0.11, 0.13), metallic=0.7, rough=0.5)
    pan = material("pan", (0.42, 0.36, 0.3), metallic=0.8, rough=0.5)
    # the jaw ring and its saw teeth all round, lying open
    bpy.ops.mesh.primitive_torus_add(major_radius=1.0, minor_radius=0.11, major_segments=96, minor_segments=16)
    add(bpy.context.object, steel)
    for i in range(22):
        a = 2 * math.pi * i / 22
        bpy.ops.mesh.primitive_cone_add(vertices=6, radius1=0.12, radius2=0.0, depth=0.34,
                                        location=(math.cos(a) * 0.9, math.sin(a) * 0.9, 0.15))
        cone = bpy.context.object
        cone.rotation_euler = (math.cos(a + math.pi / 2) * 0.35, math.sin(a + math.pi / 2) * -0.35, a)
        add(cone, steel, smooth=False)
    bpy.ops.mesh.primitive_cylinder_add(radius=0.42, depth=0.06, location=(0, 0, -0.04), vertices=48)
    add(bpy.context.object, pan)
    bpy.ops.mesh.primitive_cube_add(size=1, location=(0, 0, -0.1))
    bpy.context.object.scale = (2.5, 0.16, 0.06)
    add(bpy.context.object, dark)
    for x in (-1.25, 1.25):
        bpy.ops.mesh.primitive_torus_add(major_radius=0.16, minor_radius=0.05, location=(x, 0, -0.06), rotation=(math.pi / 2, 0, 0))
        add(bpy.context.object, dark)
    camera(sc, (0, -3.2, 3.2), (0, 0, 0), 3.0)
    return sc


def bat():
    sc = reset()
    wood = material("wood", (0.55, 0.3, 0.13), rough=0.4, noise=0.35)
    tape = material("tape", (0.55, 0.06, 0.06), rough=0.75)
    # a lathe-turned bat: a long profile of radii from the knob to the rounded barrel end
    profile = [(0.0, 0.11), (0.04, 0.12), (0.08, 0.07), (0.6, 0.075), (1.2, 0.1), (1.7, 0.16), (2.2, 0.2), (2.6, 0.21),
               (2.75, 0.19), (2.82, 0.12), (2.85, 0.0)]
    mesh = bpy.data.meshes.new("bat")
    bm = bmesh.new()
    rings = []
    n = 40
    for z, r in profile:
        ring = [bm.verts.new((math.cos(2 * math.pi * k / n) * r, math.sin(2 * math.pi * k / n) * r, z)) for k in range(n)]
        rings.append(ring)
    for a, b in zip(rings, rings[1:]):
        for k in range(n):
            bm.faces.new((a[k], a[(k + 1) % n], b[(k + 1) % n], b[k]))
    bm.to_mesh(mesh)
    obj = bpy.data.objects.new("bat", mesh)
    sc.collection.objects.link(obj)
    add(obj, wood)
    mod = obj.modifiers.new("smooth", "SUBSURF")
    mod.levels = mod.render_levels = 1
    bpy.ops.mesh.primitive_cylinder_add(radius=0.083, depth=0.62, location=(0, 0, 0.42), vertices=40)
    add(bpy.context.object, tape)
    for o in list(sc.objects):
        if o.type == "MESH":
            o.rotation_euler = (0, math.radians(-45), 0)
            o.location = Vector((o.location.x, o.location.y, o.location.z)) if o.name == "bat" else o.location
    # keep the tape on the bat: rotate it about the same origin
    tape_obj = [o for o in sc.objects if o.type == "MESH" and o.name != "bat"][0]
    tape_obj.location = (math.sin(math.radians(-45)) * 0.42, 0, math.cos(math.radians(-45)) * 0.42)
    camera(sc, (-1.0, -5, 1.0), (-1.0, 0, 1.0), 3.3)
    return sc


for name, build in (("trap", trap), ("bat", bat)):
    sc = build()
    sc.render.filepath = f"{out}/{name}.png"
    bpy.ops.render.render(write_still=True)
    print("rendered", name)
