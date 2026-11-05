"""Builds Tape 2's level: chapters/chapter_02/toll_plaza.tscn (story bible: the NH-4 toll
plaza, 2 November 2001, 1:05 AM; Salim's overnight booth) and its objectives.

The highway runs along Z; traffic in Salim's lane drives towards -Z on the left-hand side of
the road (India), so the driver (right-hand drive) stops with his window at the booth's -X
window. Booth 3 sits on the island at x 0; its lane centre is x -2.7; the barrier lifts just
past the booth (z -2.4). Two more islands with dark, closed booths.
First pass of the tape (step 10): the shared systems, the full night and the ending are in;
art is kit boxes + propkit (no bespoke models yet).
Run: python tools/gen_tape02.py
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from levelkit import (ROOT, Level, acoustic_zone, benchmark_points, night_environment, player_rig,  # noqa: E402
                      slab, sodium_lamp, v3, wall)
from propkit import Props  # noqa: E402

OUT_DIR = os.path.join(ROOT, "chapters", "chapter_02")
SCRIPTS = "res://chapters/chapter_02/scripts/"
LANE_X = -2.7


def script(lv, path):
    return f'ExtResource("{lv.ext(path, "Script")}")'


def sound(lv, name):
    return f'ExtResource("{lv.ext(f"res://assets/audio/sfx/{name}.wav", "AudioStream")}")'


def area(lv, parent, name, pos, size, props):
    path = lv.add(name, "Area3D", parent, {"position": v3(*pos), **props})
    shape = lv.sub("BoxShape3D", {"size": v3(*size)})
    lv.add("Shape", "CollisionShape3D", path, {"shape": f'SubResource("{shape}")'})
    return path


def usable(lv, parent, name, pos, size, prompt, node_props=None, node_script=None):
    props = {"position": v3(*pos)}
    if node_script:
        props["script"] = script(lv, node_script)
    props.update(node_props or {})
    node = lv.add(name, "Node3D", parent, props)
    area(lv, node, "Interactable", (0, 0, 0), size,
         {"script": script(lv, "res://systems/interaction/interactable.gd"), "prompt": f'"{prompt}"'})
    return node


def event_use(lv, name, pos, size, prompt, event, parent="."):
    # booth controls are used all night: not one-shot
    return usable(lv, parent, name, pos, size, prompt, {"event_id": f'&"{event}"', "once": "false"},
                  "res://systems/interaction/event_on_use.gd")


def character(lv, name, kind, parent, pos, yaw, props=None, scale=1.0):
    p = {"position": v3(*pos), "rotation_degrees": v3(0, yaw, 0)}
    if scale != 1.0:
        p["scale"] = v3(scale, scale, scale)
    return lv.scene(name, f"res://assets/characters/{kind}.tscn", parent, {**p, **(props or {})})


def figure(lv, parent, name, pos, shirt, hair="glass_dark", cap=None, visible=True):
    """A seated person seen through a vehicle window: shoulders, neck, head, hair (boxes)."""
    f = lv.add(name, "Node3D", parent, {"position": v3(*pos), "visible": "true" if visible else "false"})
    lv.box((0, 0.0, 0), (0.44, 0.5, 0.26), shirt, collide=False, parent=f)
    lv.box((0, 0.3, 0), (0.1, 0.1, 0.1), "floor_kota", collide=False, parent=f)
    lv.box((0, 0.45, 0), (0.19, 0.24, 0.21), "floor_kota", collide=False, parent=f)
    lv.box((0, 0.56, 0.02), (0.2, 0.06, 0.22), hair, collide=False, parent=f)
    if cap:
        lv.box((0, 0.6, 0), (0.22, 0.06, 0.24), cap, collide=False, parent=f)
        lv.box((0, 0.58, -0.14), (0.2, 0.02, 0.08), cap, collide=False, parent=f)
    return f


def vehicle(lv, name, kind, plate, paint, stop_z, start_z=120.0):
    """A TollVehicle (chapters/chapter_02/scripts/toll_vehicle.gd) parked out of sight.
    Local -Z = its front; right-hand drive: the driver sits at +X (the booth side)."""
    v = lv.add(name, "AnimatableBody3D", "Vehicles", {
        "position": v3(LANE_X, 0, start_z), "script": script(lv, SCRIPTS + "toll_vehicle.gd"),
        "plate": f'"{plate}"', "stop_z": str(stop_z), "start_z": str(start_z),
        "collision_layer": "1", "collision_mask": "0"})
    length, width, height = {"van": (3.5, 1.45, 1.75), "car": (3.6, 1.5, 1.45), "tempo": (4.6, 1.7, 2.0)}[kind]
    body = lv.add("Body", "Node3D", v)
    sill = 0.95 if kind != "tempo" else 1.1
    # lower body, roof, pillars: window gaps stay open so the people inside can be seen
    lv.box((0, (0.25 + sill) / 2, 0), (width, sill - 0.25, length), paint, collide=False, parent=body)
    if kind == "tempo":
        lv.box((0, (sill + height) / 2, -length / 2 + 0.75), (width, 0.06, 1.5), paint, collide=False, parent=body)
        lv.box((0, height - 0.03, -length / 2 + 0.75), (width, 0.06, 1.5), paint, collide=False, parent=body)
        for sx in (-1, 1):
            lv.box((sx * (width / 2 - 0.04), (sill + height) / 2, -length / 2 + 0.05), (0.08, height - sill, 0.08), paint, collide=False, parent=body)
            lv.box((sx * (width / 2 - 0.04), (sill + height) / 2, -length / 2 + 1.45), (0.08, height - sill, 0.08), paint, collide=False, parent=body)
        # open cargo bed with onion sacks
        lv.box((0, sill + 0.25, 0.75), (width, 0.5, 3.0), "wood_planks", collide=False, parent=body)
        for i in range(6):
            lv.box(((i % 2 - 0.5) * 0.7, sill + 0.65, -0.3 + (i // 2) * 0.85), (0.6, 0.38, 0.7), "fabric_sheet", collide=False, parent=body)
    else:
        front = -length / 2 + (0.15 if kind == "van" else 0.9)
        back = length / 2 - (0.05 if kind == "van" else 0.5)
        lv.box((0, height - 0.04, (front + back) / 2), (width, 0.08, back - front), paint, collide=False, parent=body)
        for sx in (-1, 1):
            for z in (front, (front + back) / 2 - (0.2 if kind == "van" else 0.0), back):
                lv.box((sx * (width / 2 - 0.04), (sill + height) / 2, z), (0.07, height - sill, 0.07), paint, collide=False, parent=body)
        if kind == "car":
            lv.box((0, sill + 0.06, -length / 2 + 0.45), (width, 0.12, 0.9), paint, collide=False, parent=body)  # bonnet
        # tinted glass (people inside still show); the driver's window (+X, front) is rolled down
        gh = height - sill - 0.1
        gy = sill + gh / 2 + 0.02
        b_pillar = (front + back) / 2 - (0.2 if kind == "van" else 0.0)
        lv.box((0, gy, front + 0.03), (width - 0.12, gh, 0.02), "glass_tint", collide=False, shadow=False, parent=body)
        lv.box((0, gy, back - 0.03), (width - 0.12, gh, 0.02), "glass_tint", collide=False, shadow=False, parent=body)
        lv.box((-(width / 2 - 0.03), gy, (front + back) / 2), (0.02, gh, back - front - 0.1), "glass_tint", collide=False, shadow=False, parent=body)
        lv.box((width / 2 - 0.03, gy, (b_pillar + back) / 2), (0.02, gh, back - b_pillar - 0.1), "glass_tint", collide=False, shadow=False, parent=body)
        if kind == "van":  # Omni: the flat back with its door seam and handle
            lv.box((0, (0.25 + sill) / 2, length / 2 + 0.01), (width - 0.1, sill - 0.3, 0.02), paint, collide=False, parent=body)
            lv.box((0, sill - 0.1, length / 2 + 0.03), (0.18, 0.04, 0.03), "glass_dark", collide=False, parent=body)
    for sx in (-1, 1):
        for z in (-length / 2 + 0.6, length / 2 - 0.6):
            lv.box((sx * (width / 2 - 0.1), 0.28, z), (0.18, 0.56, 0.56), "glass_dark", collide=False, parent=body)  # wheels
    lv.box((0, 0.5, -length / 2 - 0.01), (0.5, 0.11, 0.02), "paper", collide=False, parent=body)  # number plate
    lv.add("Plate", "Label3D", body, {"position": v3(0, 0.5, -length / 2 - 0.025), "pixel_size": "0.0012", "font_size": "64",
                                      "outline_size": "0", "modulate": "Color(0.08, 0.08, 0.08, 1)", "text": f'"{plate}"'})
    for sx in (-1, 1):
        lv.box((sx * (width / 2 - 0.2), 0.7, -length / 2 - 0.01), (0.22, 0.12, 0.03), "glass_sodium", collide=False, shadow=False, parent=body)
        lv.box((sx * (width / 2 - 0.15), 0.75, length / 2 + 0.01), (0.12, 0.16, 0.03), "paint_car_red", collide=False, shadow=False, parent=body)
        lv.add("Headlight", "SpotLight3D", v, {"position": v3(sx * (width / 2 - 0.2), 0.7, -length / 2 - 0.05),
                                               "rotation_degrees": v3(-4, 0, 0), "light_color": "Color(1, 0.92, 0.75, 1)",
                                               "light_energy": "4.0", "spot_range": "45.0", "spot_angle": "32.0",
                                               "shadow_enabled": "false", "light_volumetric_fog_energy": "1.2"})
    # the tail lights: two of the night's red decoys
    lv.add("Tail", "OmniLight3D", v, {"position": v3(0, 0.75, length / 2 + 0.25), "light_color": "Color(1, 0.08, 0.04, 1)",
                                      "light_energy": "0.8", "omni_range": "2.5", "shadow_enabled": "false"})
    lv.add("Engine", "AudioStreamPlayer3D", v, {"position": v3(0, 0.6, -length / 2 + 0.5), "stream": sound(lv, "engine_idle"),
                                                 "volume_db": "-6.0", "unit_size": "4.0", "max_distance": "80.0", "bus": '&"SFX"'})
    shape = lv.sub("BoxShape3D", {"size": v3(width, height - 0.2, length)})
    lv.add("CollisionShape3D", "CollisionShape3D", v, {"position": v3(0, (height + 0.2) / 2, 0), "shape": f'SubResource("{shape}")'})
    return v


def tree(lv, x, z):
    lv.box((x, 1.8, z), (0.4, 3.6, 0.4), "wood_planks", collide=False)
    for dx, dy, dz, s in ((0, 4.2, 0, 3.4), (0.9, 3.7, 0.5, 2.2), (-0.8, 3.8, -0.6, 2.4)):
        lv.box((x + dx, dy, z + dz), (s, s * 0.6, s), "foliage", collide=False)


def main() -> None:
    lv = Level("TollPlaza")
    night_environment(lv, fog_density=0.018)
    # ---- ground: fields, the highway, the plaza apron, islands
    lv.box((0, -0.15, 0), (420, 0.2, 640), "ground_dirt", collide=True)
    lv.box((0, -0.04, 0), (30, 0.1, 640), "ground_asphalt")
    lv.box((0, -0.035, 0), (36, 0.1, 60), "ground_asphalt", collide=False)
    for x in (-5.6, 0.0, 5.6):
        lv.box((x, 0.1, 0), (2.2, 0.2, 14), "concrete_rough")
        for z in (-6.4, 6.4):
            lv.box((x, 0.6, z), (0.5, 1.0, 0.5), "metal_gate_green")  # yellow-black bollards stand-in
    for x in (-15.2, 15.2):
        lv.box((x, 0.12, 0), (0.3, 0.25, 640), "concrete_rough", collide=False)  # kerbs
    for z in range(-300, 301, 12):  # lane dashes
        for x in (-8.3, 8.3):
            lv.box((x, 0.02, z), (0.15, 0.02, 3.0), "paper", collide=False, shadow=False)
    # ---- canopy over the plaza
    slab(lv, -18, 18, -9, 9, 6.4, 0.4, "metal_corrugated", "metal_meter_white", collide=False)
    for x in (-5.6, 0.0, 5.6):
        for z in (-6.0, 6.0):
            lv.box((x, 3.2, z), (0.4, 6.4, 0.4), "metal_meter_white")
    lv.box((0, 7.1, 9.05), (36, 1.0, 0.1), "metal_meter_white", collide=False)
    lv.add("PlazaSign", "Label3D", ".", {"position": v3(0, 7.1, 9.12), "pixel_size": "0.012", "font_size": "64", "outline_size": "0",
                                          "modulate": "Color(0.1, 0.25, 0.6, 1)", "shaded": "true",
                                          "text": '"NH-4   TOLL PLAZA   पथकर नाका   KM 112"'})
    lights = lv.add("CanopyLights", "Node3D", ".")
    for i, (x, z) in enumerate(((-2.8, 3.0), (-2.8, -3.0), (-8.4, 0.0), (2.8, 0.0), (8.4, 0.0))):
        lv.box((x, 6.15, z), (1.3, 0.06, 0.18), "glass_lit_warm", collide=False, shadow=False)
        lv.add(f"Lamp{i}", "OmniLight3D", lights, {"position": v3(x, 5.9, z), "light_color": "Color(0.85, 0.95, 1, 1)",
                                                    "light_energy": "1.6" if i < 2 else "0.9", "omni_range": "11.0",
                                                    "shadow_enabled": "true" if i == 0 else "false",
                                                    "light_volumetric_fog_energy": "0.8"}, groups=["mains"])
    # ---- booth 3 (Salim's): x -0.9..0.9, z -1.4..1.4, floor on the island (y 0.2)
    slab(lv, -0.9, 0.9, -1.4, 1.4, 0.24, 0.04, "floor_mosaic", "floor_mosaic")
    slab(lv, -1.0, 1.0, -1.5, 1.5, 2.75, 0.12, "concrete_dark", "wall_paint_white")
    ext, inn = "wall_exterior_cream", "wall_paint_mint"
    wall(lv, (-0.9, -1.4), (-0.9, 1.4), 0.2, 2.5, 0.12, ext, inn, -1,
         [{"along": 0.0, "w": 1.3, "bottom": 1.0, "top": 2.0, "kind": "hole"}])   # the toll window (lane side)
    wall(lv, (0.9, -1.4), (0.9, 1.4), 0.2, 2.5, 0.12, ext, inn, +1,
         [{"along": 0.3, "w": 0.9, "bottom": 1.0, "top": 1.9, "kind": "window"}])
    wall(lv, (-0.9, 1.4), (0.9, 1.4), 0.2, 2.5, 0.12, ext, inn, +1)
    wall(lv, (-0.9, -1.4), (0.9, -1.4), 0.2, 2.5, 0.12, ext, inn, -1,
         [{"along": 0.25, "w": 0.8, "bottom": 0.2, "top": 2.2, "kind": "hole"}])  # door (exit side)
    lv.box((-0.95, 2.25, 0), (0.06, 0.3, 1.6), "metal_meter_white", collide=False)
    lv.add("BoothSign", "Label3D", ".", {"position": v3(-0.99, 2.25, 0), "rotation_degrees": v3(0, -90, 0), "pixel_size": "0.004",
                                          "font_size": "48", "outline_size": "0", "modulate": "Color(0.1, 0.1, 0.1, 1)",
                                          "text": '"BOOTH 3   CASH ONLY"'})
    # counter under the window, a stool, the cash tray, receipt printer
    lv.box((-0.62, 0.98, 0), (0.5, 0.05, 1.9), "wood_planks")
    lv.box((-0.62, 0.6, 0), (0.46, 0.75, 1.86), "wood_door_dark", collide=False)
    lv.box((-0.6, 1.04, 0.15), (0.3, 0.06, 0.24), "metal_meter_white", collide=False)
    lv.box((-0.66, 1.08, -0.45), (0.22, 0.12, 0.2), "glass_dark", collide=False)
    lv.box((-0.64, 1.15, -0.45), (0.06, 0.003, 0.1), "paper", collide=False)
    p = Props(lv)
    p.model("wooden_stool_01", (0.05, 0.22, 0.1), yaw=90)
    p.calendar((0.84, 1.75, -0.6), yaw=-90)
    p.tiffin((-0.55, 1.0, 0.75))
    p.tumbler((-0.6, 1.0, 0.55))
    lv.scene("BoothTube", "res://systems/props/tube_light.tscn", ".", {"position": v3(0, 2.62, 0)}, groups=["mains"])
    # the things Salim uses
    event_use(lv, "TollWindow", (-0.98, 1.35, 0.15), (0.35, 0.7, 1.1), "Take the toll", "toll_window")
    btn = event_use(lv, "BarrierButton", (-0.55, 1.1, -0.85), (0.2, 0.2, 0.2), "Lift the barrier", "barrier_button")
    lv.box((0, 0, 0), (0.12, 0.08, 0.12), "metal_meter_white", collide=False, parent=btn)
    lv.box((0, 0.05, 0), (0.06, 0.03, 0.06), "paint_car_red", collide=False, shadow=False, parent=btn)
    radio = event_use(lv, "Radio", (0.62, 1.45, 1.15), (0.35, 0.3, 0.25), "Use the radio", "radio_used")
    lv.box((0, -0.15, 0), (0.4, 0.04, 0.26), "wood_planks", collide=False, parent=radio)   # shelf
    lv.box((0, 0, 0), (0.3, 0.18, 0.16), "glass_dark", collide=False, parent=radio)
    lv.box((0.08, 0.2, 0), (0.015, 0.25, 0.015), "glass_dark", collide=False, parent=radio)
    led = lv.add("Led", "OmniLight3D", radio, {"position": v3(-0.1, 0.05, -0.09), "light_color": "Color(1, 0.1, 0.05, 1)",
                                                "light_energy": "0.25", "omni_range": "0.4"})
    log = usable(lv, ".", "PlateLog", (-0.58, 1.02, 0.42), (0.35, 0.12, 0.3), "Read the plate log", node_script=SCRIPTS + "plate_log.gd")
    lv.box((0, 0, 0), (0.24, 0.025, 0.32), "paper", collide=False, parent=log)
    # lane CCTV monitor on the counter, screen towards the stool (+X)
    cctv = lv.add("CCTV", "Node3D", ".", {"position": v3(-0.6, 1.0, -0.2), "rotation_degrees": v3(0, -90, 0),
                                          "script": script(lv, "res://systems/props/cctv_monitor.gd"),
                                          "cameras": 'Array[NodePath]([NodePath("../CamSpots/Entry"), NodePath("../CamSpots/Exit")])',
                                          "names": 'PackedStringArray("CAM 1  LANE 3 ENTRY", "CAM 2  LANE 3 EXIT")',
                                          "active_distance": "6.0"})
    lv.box((0, 0.15, 0.05), (0.3, 0.28, 0.26), "glass_dark", collide=False, parent=cctv)
    scr = lv.sub("QuadMesh", {"size": "Vector2(0.24, 0.18)"})
    lv.add("Screen", "MeshInstance3D", cctv, {"position": v3(0, 0.16, -0.081), "rotation_degrees": v3(0, 180, 0), "mesh": f'SubResource("{scr}")'})
    lv.add("Label", "Label3D", cctv, {"position": v3(0, 0.27, -0.09), "rotation_degrees": v3(0, 180, 0), "pixel_size": "0.0006",
                                      "font_size": "28", "outline_size": "0", "modulate": "Color(0.7, 1, 0.7, 1)", "text": '"CAM 1"'})
    area(lv, cctv, "Interactable", (0, 0.15, -0.05), (0.36, 0.34, 0.32),
         {"script": script(lv, "res://systems/interaction/interactable.gd"), "prompt": '"Check the lane camera"'})
    lv.add("CamSpots", "Node3D", ".")
    # CAM 1 looks up the highway (narrow lens: the far end of the lane); CAM 2 the exit
    for name, pos, rot, fov in (("Entry", (-4.5, 5.6, -8.5), (-6, 180, 0), 22), ("Exit", (-4.5, 5.6, 8.5), (-14, 0, 0), 60)):
        lv.add(name, "Marker3D", "CamSpots", {"position": v3(*pos), "rotation_degrees": v3(*rot), "metadata/fov": f"{fov}.0"})
    # ---- the barrier: pivot on its post, arm across the lane (-X), lifts by rotating about Z
    lv.box((-1.2, 0.6, -2.4), (0.3, 1.0, 0.3), "metal_meter_white")
    lv.add("Barrier", "Node3D", ".", {"position": v3(-1.2, 1.05, -2.4)})
    arm = lv.add("Arm", "Node3D", "Barrier")
    for i in range(7):
        lv.box((-0.25 - i * 0.5, 0, 0), (0.5, 0.09, 0.09), "paint_car_red" if i % 2 == 0 else "paper", collide=False, parent=arm)
    lv.box((-1.2, 1.25, -2.4), (0.12, 0.08, 0.12), "glass_sodium", collide=False, shadow=False)
    # ---- the two closed booths (dark, shutters down)
    for x in (-5.6, 5.6):
        slab(lv, x - 0.9, x + 0.9, -1.4, 1.4, 2.75, 0.12, "concrete_dark", "concrete_dark")
        for p0, p1, s in (((x - 0.9, -1.4), (x - 0.9, 1.4), -1), ((x + 0.9, -1.4), (x + 0.9, 1.4), 1),
                          ((x - 0.9, 1.4), (x + 0.9, 1.4), 1), ((x - 0.9, -1.4), (x + 0.9, -1.4), -1)):
            wall(lv, p0, p1, 0.2, 2.5, 0.12, "wall_exterior_cream", "concrete_dark", s)
        lv.box((x - 0.97, 1.5, 0), (0.03, 0.9, 1.2), "metal_corrugated", collide=False)
    # ---- the road beyond: lamps, trees, a dhaba far off, a billboard
    for z in (-120, -80, -40, 40, 80, 120):
        sodium_lamp(lv, -16.5, z, facing_x=1)
    for z in range(-200, 201, 23):
        if abs(z) > 14:
            tree(lv, -24 - (z % 3) * 3, z)
            tree(lv, 25 + (z % 4) * 2, z + 9)
    lv.box((34, 1.6, -70), (8, 3.2, 6), "wall_exterior_peach", collide=False)
    lv.box((29.97, 1.4, -70), (0.05, 1.0, 2.0), "glass_lit_warm", collide=False, shadow=False)
    lv.add("DhabaLight", "OmniLight3D", ".", {"position": v3(28.5, 2.6, -70), "light_color": "Color(1, 0.6, 0.3, 1)",
                                               "light_energy": "1.5", "omni_range": "9.0", "shadow_enabled": "false"})
    lv.add("DhabaSign", "Label3D", ".", {"position": v3(29.9, 3.5, -70), "rotation_degrees": v3(0, -90, 0), "pixel_size": "0.01",
                                          "font_size": "64", "outline_size": "0", "modulate": "Color(0.9, 0.5, 0.2, 1)",
                                          "text": '"SHER-E-PUNJAB DHABA  24 HRS"'})
    lv.box((-26, 6, 40), (0.3, 4, 10), "metal_rust", collide=False)
    lv.box((-25.8, 7, 40), (0.05, 3.2, 9.4), "paper", collide=False)
    lv.add("Billboard", "Label3D", ".", {"position": v3(-25.75, 7, 40), "rotation_degrees": v3(0, 90, 0), "pixel_size": "0.012",
                                          "font_size": "64", "outline_size": "0", "modulate": "Color(0.6, 0.15, 0.1, 1)",
                                          "text": '"DRIVE SLOW\\nYOUR FAMILY IS WAITING"'})
    # ---- vehicles (scripted: chapters/chapter_02/scripts/toll_vehicle.gd)
    lv.add("Vehicles", "Node3D", ".")
    for name, kind, plate, paint, stop in (("Car1", "car", "MH 12 KT 4471", "paint_car_white", 0.2),
                                           ("Tempo", "tempo", "MH 43 E 7710", "metal_trunk_blue", 1.8),
                                           ("Car2", "car", "GJ 05 CR 2208", "paint_car_red", 0.2)):
        v = vehicle(lv, name, kind, plate, paint, stop)
        figure(lv, v, "Driver", (0.35, 1.0, -0.35 if kind == "car" else -1.7), "fabric_curtain")
    van = vehicle(lv, "Van", "van", "MH 04 AX 0312", "paint_car_white", 0.9)
    # three drivers (the director shows one): older, younger, in Salim's uniform
    figure(lv, van, "DriverOld", (0.35, 1.05, -1.0), "fabric_sheet", hair="paper")
    figure(lv, van, "DriverYoung", (0.35, 1.05, -1.0), "fabric_curtain", visible=False)
    figure(lv, van, "DriverUniform", (0.35, 1.05, -1.0), "paint_car_blue", cap="paint_car_blue", visible=False)
    lv.add("Passengers", "Node3D", van)
    for i, (x, z) in enumerate(((0.35, 0.35), (-0.35, 0.35), (0.35, 1.15), (-0.05, 1.15))):
        figure(lv, f"{van}/Passengers", f"P{i + 1}", (x, 1.0, z), "glass_dark", visible=False)
    character(lv, "Raghu", "raghu", f"{van}/Passengers", (-0.35, -0.38, 1.15), 0, {"visible": "false"}, scale=0.85)
    character(lv, "CamBackseat", "cameraman", van, (0.0, -0.4, 1.35), 0,
              {"active": "false", "steady_dot": "true", "tracking_noise": "0.0", "spot_id": '&"t2_backseat"'}, scale=0.85)
    # ---- the Cameraman: on the lane camera (CCTV only), and on the road in the headlights
    character(lv, "CamLane", "cameraman", ".", (LANE_X, 0, 70), 0, {"active": "false", "cctv_only": "true", "tracking_noise": "0.0"})
    lv.add("SpotCCTV", "Node3D", ".", {"position": v3(-0.6, 1.16, -0.2), "script": script(lv, "res://systems/story/spottable.gd"),
                                        "spot_id": '&"t2_cctv"', "monitor": 'NodePath("../CCTV")', "monitor_camera": "0",
                                        "active": "false"})
    character(lv, "CamRoad", "cameraman", ".", (-6.5, 0, 46), 0,
              {"active": "false", "spot_id": '&"t2_road"', "vanish_when_unseen": "true", "spot_max_distance": "60.0",
               "vanish_distance": "8.0"})
    # ---- mains power (the ending kills it), story, sequences, ambience
    glow = ", ".join(f'ExtResource("{lv.ext(f"res://assets/materials/{m}.tres", "Material")}")'
                     for m in ("glass_sodium", "glass_lit_warm"))
    lv.add("Power", "Node", ".", {"script": script(lv, "res://systems/props/power_grid.gd"),
                                  "glow_materials": f"Array[BaseMaterial3D]([{glow}])"})
    lv.add("Story", "Node", ".", {"script": script(lv, SCRIPTS + "tape02_director.gd")})
    idle = ", ".join(sound(lv, n) for n in ("dog_bark", "horn_far", "train_far", "pipe_creak"))
    lv.add("IdleEvents", "Node", ".", {"script": script(lv, "res://systems/story/idle_events.gd"),
                                       "sounds": f"Array[AudioStream]([{idle}])"})
    group = lv.add("Acoustics", "Node3D", ".")
    acoustic_zone(lv, "Highway", (0, 10, 0), (200, 24, 600), "outdoors", parent=group, ambience="courtyard_night")
    acoustic_zone(lv, "Plaza", (0, 3.5, 0), (36, 7, 18), "yard", parent=group)
    acoustic_zone(lv, "Booth", (0, 1.4, 0), (1.8, 2.5, 2.8), "small_room", parent=group, ambience="cabin")
    # ---- chapter flow
    lv.add("ObjectiveLoader", "Node", ".", {"script": script(lv, "res://systems/objectives/objective_loader.gd"),
                                           "objective_set": f'ExtResource("{lv.ext("res://chapters/chapter_02/objectives.tres", "Resource")}")'})
    lv.add("Checkpoints", "Node3D", ".")
    area(lv, "Checkpoints", "booth", (0.3, 0.24, 0.4), (1.2, 2.0, 1.6),
         {"script": script(lv, "res://systems/chapters/checkpoint.gd"), "checkpoint_id": '&"booth"', "rotation_degrees": v3(0, 90, 0)})
    player_rig(lv, 0.3, 0.4, 90.0, y=0.26, flashlight=False, debug=False)
    benchmark_points(lv, [(0.3, 0.26, 0.4), (-2.7, 0, 12), (0, 0, -20), (-10, 0, 0)])
    lv.write(os.path.join(OUT_DIR, "toll_plaza.tscn"))
    write_objectives()


def write_objectives() -> None:
    objs = [("radio_checkin", "Check in with control on the radio", "radio_checkin", 1, ""),
            ("serve_cars", "Take the toll, lift the barrier", "vehicle_served", 3, "radio_checkin"),
            ("log_hour", "Write the plates in the log", "log_written", 1, "serve_cars"),
            ("van_1", "Serve the next vehicle", "van_served_1", 1, "log_hour"),
            ("radio_van", "Radio control about the van", "radio_van", 1, "van_1"),
            ("van_2", "Serve the van", "van_served_2", 1, "radio_van"),
            ("check_cctv", "Check the lane camera", "lane_checked", 1, "van_2"),
            ("van_3", "Serve the van", "van_served_3", 1, "check_cctv"),
            ("radio_again", "Try the radio again", "radio_dead", 1, "van_3"),
            ("van_4", "Serve the van", "van_served_4", 1, "radio_again"),
            ("read_log", "Read the plate log", "log_read_late", 1, "van_4"),
            ("last_toll", "Take the toll", "last_toll", 1, "read_log")]
    lines = ['[gd_resource type="Resource" script_class="ObjectiveSet" format=3]', "",
             '[ext_resource type="Script" path="res://systems/objectives/objective_set.gd" id="1_set"]',
             '[ext_resource type="Script" path="res://systems/objectives/objective_data.gd" id="2_data"]', ""]
    for oid, text, ev, req, after in objs:
        lines += [f'[sub_resource type="Resource" id="O_{oid}"]', 'script = ExtResource("2_data")', f'id = &"{oid}"',
                  f'text = "{text}"', f'complete_on = &"{ev}"', f"required = {req}", f'starts_after = &"{after}"', ""]
    lines += ["[resource]", 'script = ExtResource("1_set")',
              "objectives = Array[ExtResource(\"2_data\")]([" + ", ".join(f'SubResource("O_{o[0]}")' for o in objs) + "])", ""]
    with open(os.path.join(OUT_DIR, "objectives.tres"), "w", encoding="utf-8") as f:
        f.write("\n".join(lines))
    print("wrote objectives.tres")


if __name__ == "__main__":
    main()
