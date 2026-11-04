"""Blender props (run headless):

    blender -b --factory-startup --python tools/blender/build_props.py

assets/models/phone/phone_body.obj: Nikhil's phone (2020s slab, 71 x 150 x 8 mm): rounded
corners, softened edges, a raised camera island on the back, side buttons. Godot axes: x right,
y up (long side), +z = the screen side; origin at the centre. The screen itself is a quad the
game adds (PlayerPhone), showing a live SubViewport.
"""
import math
import os

import bmesh
import bpy
from mathutils import Vector

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))


def g2b(x, y, z):
    return Vector((x, -z, y))


def rounded_slab(bm, w, h, d, r, z0, segs=8):
    """A rounded-rectangle outline (corner radius r) extruded from z0 to z0 + d (godot)."""
    pts = []
    for cx, cy, a0 in ((w / 2 - r, h / 2 - r, 0), (-w / 2 + r, h / 2 - r, 90), (-w / 2 + r, -h / 2 + r, 180),
                       (w / 2 - r, -h / 2 + r, 270)):
        for i in range(segs + 1):
            a = math.radians(a0 + 90 * i / segs)
            pts.append((cx + math.cos(a) * r, cy + math.sin(a) * r))
    bottom = [bm.verts.new(g2b(x, y, z0)) for x, y in pts]
    top = [bm.verts.new(g2b(x, y, z0 + d)) for x, y in pts]
    bm.faces.new(bottom[::-1])
    bm.faces.new(top)
    n = len(pts)
    for i in range(n):
        j = (i + 1) % n
        bm.faces.new((bottom[i], bottom[j], top[j], top[i]))


def box(bm, c, s):
    v = [bm.verts.new(g2b(c[0] + dx * s[0] / 2, c[1] + dy * s[1] / 2, c[2] + dz * s[2] / 2))
         for dx in (-1, 1) for dy in (-1, 1) for dz in (-1, 1)]
    for f in ((0, 1, 3, 2), (4, 6, 7, 5), (0, 4, 5, 1), (2, 3, 7, 6), (0, 2, 6, 4), (1, 5, 7, 3)):
        bm.faces.new([v[i] for i in f])


def phone():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bm = bmesh.new()
    rounded_slab(bm, 0.071, 0.150, 0.008, 0.009, -0.004)
    # camera island on the back (-z): built at the centre, moved to the top corner below
    rounded_slab(bm, 0.026, 0.030, 0.0018, 0.006, -0.0058)
    me = bpy.data.meshes.new("phone_body")
    bm.to_mesh(me)
    bm.free()
    ob = bpy.data.objects.new("phone_body", me)
    bpy.context.collection.objects.link(ob)
    # move the island (the second slab's vertices: both slabs have the same count)
    verts = ob.data.vertices
    n_slab = len(verts) // 2
    for v in list(verts)[n_slab:]:
        v.co.x += 0.016
        v.co.z += 0.052  # blender z = godot y (up the phone)
    bm = bmesh.new()
    bm.from_mesh(me)
    # side buttons (right side: power; left: volume)
    box(bm, (0.0362, 0.02, 0.0), (0.0016, 0.016, 0.0035))
    box(bm, (-0.0362, 0.03, 0.0), (0.0016, 0.022, 0.0035))
    bm.to_mesh(me)
    bm.free()
    bv = ob.modifiers.new("bevel", "BEVEL")
    bv.width = 0.0012
    bv.segments = 2
    bv.limit_method = "ANGLE"
    bv.angle_limit = math.radians(40)
    ws = ob.modifiers.new("ws", "WEIGHTED_NORMAL")
    ws.keep_sharp = True
    ob.select_set(True)
    bpy.context.view_layer.objects.active = ob
    out = os.path.join(ROOT, "assets", "models", "phone", "phone_body.obj")
    bpy.ops.wm.obj_export(filepath=out, export_selected_objects=True, export_materials=False, export_uv=False,
                          export_normals=True, apply_modifiers=True, forward_axis="NEGATIVE_Z", up_axis="Y")
    print("PROP phone", out)


if __name__ == "__main__":
    phone()
