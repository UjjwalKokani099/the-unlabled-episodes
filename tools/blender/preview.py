"""Quick look at a built character (Cycles on the CPU, no GPU needed):
    blender -b --factory-startup --python tools/blender/preview.py -- <glb> <out.png> [closeup]
Renders front, three-quarter and side views side by side (or the head only with closeup)."""
import math
import sys

import bpy
from mathutils import Vector

args = sys.argv[sys.argv.index("--") + 1:]
glb, out = args[0], args[1]
closeup = len(args) > 2 and args[2] == "closeup"
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=glb)
# lids rest closed (the game opens them): hide them so the face reads
for ob in bpy.data.objects:
    if ob.name.startswith("lid"):
        ob.hide_render = True
scene = bpy.context.scene
scene.render.engine = "CYCLES"
scene.cycles.samples = 24
scene.cycles.use_denoising = False
scene.render.resolution_x = 420 if not closeup else 360
scene.render.resolution_y = 760 if not closeup else 400
scene.render.film_transparent = False
world = bpy.data.worlds.new("w")
world.use_nodes = True
world.node_tree.nodes["Background"].inputs[0].default_value = (0.18, 0.18, 0.2, 1)
scene.world = world
key = bpy.data.lights.new("key", "AREA")
key.energy = 120
key.size = 1.5
ko = bpy.data.objects.new("key", key)
ko.location = (1.2, -2.0, 2.4)
ko.rotation_euler = (math.radians(50), 0, math.radians(30))
scene.collection.objects.link(ko)
cam = bpy.data.cameras.new("cam")
cam.lens = 50 if not closeup else 85
co = bpy.data.objects.new("cam", cam)
scene.collection.objects.link(co)
scene.camera = co
import json, os
info = json.load(open(glb.replace(".glb", ".json"))) if os.path.exists(glb.replace(".glb", ".json")) else {}
eye_y = info.get("eye_y", 1.6)
target = Vector((0, 0, info.get("height", 1.7) * 0.52)) if not closeup else Vector((0, 0, eye_y - 0.02))
dist = 4.0 if not closeup else 0.85
frames = []
for i, ang in enumerate((180, 145, 90) if not closeup else (180, 150, 105)):
    a = math.radians(ang)
    co.location = target + Vector((math.sin(a) * dist, -math.cos(a) * dist, 0.05))
    d = target - co.location
    co.rotation_euler = d.to_track_quat("-Z", "Y").to_euler()
    scene.render.filepath = out.replace(".png", f"_{i}.png")
    bpy.ops.render.render(write_still=True)
    frames.append(scene.render.filepath)
print("PREVIEW", " ".join(frames))
