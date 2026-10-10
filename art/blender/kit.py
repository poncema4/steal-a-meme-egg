"""Shared Blender helpers for the HUD art (icons and character portraits): a transparent-background studio and a few primitives."""
import sys, os, math, random
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from common import *
from mathutils import Vector

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


OUT = "."


def save(name):
    bpy.context.scene.render.filepath = os.path.join(OUT, name + ".png")
    bpy.ops.render.render(write_still=True)


def gloss(name, rgb, rough=0.18):
    return mat(name, rgb, rough)


