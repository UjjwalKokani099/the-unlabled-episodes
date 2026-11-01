"""Builds Tape 1's level: chapters/tape_01_watchman/shanti_vihar.tscn (story bible:
Shanti Vihar Housing Society, 14 March 1998, 10:40 PM) and its objectives.
Compound x -32..32, z -28..28; gate at +z. Wings A-D in a row (fronts face the gate).
Run: python tools/gen_tape01.py
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from levelkit import (ROOT, Level, benchmark_points, night_environment, player_rig,  # noqa: E402
                      residential_wing, slab, sodium_lamp, v3, wall)

OUT_DIR = os.path.join(ROOT, "chapters", "tape_01_watchman")
SCRIPTS = "res://chapters/tape_01_watchman/scripts/"


def script(lv, path):
    return f'ExtResource("{lv.ext(path, "Script")}")'


def area(lv, parent, name, pos, size, props):
    path = lv.add(name, "Area3D", parent, {"position": v3(*pos), **props})
    shape = lv.sub("BoxShape3D", {"size": v3(*size)})
    lv.add("Shape", "CollisionShape3D", path, {"shape": f'SubResource("{shape}")'})
    return path


def usable(lv, parent, name, pos, size, prompt, node_props=None, node_script=None):
    # "script" must come before the script's exported values, or Godot drops them on load.
    props = {"position": v3(*pos)}
    if node_script:
        props["script"] = script(lv, node_script)
    props.update(node_props or {})
    node = lv.add(name, "Node3D", parent, props)
    area(lv, node, "Interactable", (0, 0, 0), size, {"script": script(lv, "res://scripts/interaction/interactable.gd"), "prompt": f'"{prompt}"'})
    return node


def scooter(lv, x, z, paint, facing=1):
    lv.box((x, 0.45, z), (0.32, 0.35, 1.25), paint, collide=False)
    lv.box((x, 0.68, z - 0.1 * facing), (0.3, 0.1, 0.55), "glass_dark", collide=False)
    lv.box((x, 0.85, z + 0.55 * facing), (0.6, 0.04, 0.04), "metal_rust", collide=False)
    for dz in (-0.5, 0.5):
        lv.box((x, 0.2, z + dz), (0.1, 0.4, 0.4), "glass_dark", collide=False)
    lv.collider((x, 0.5, z), (0.4, 1.0, 1.4))


def car(lv, x, z, paint):
    lv.box((x, 0.55, z), (1.4, 0.6, 3.3), paint)
    lv.box((x, 1.05, z - 0.15), (1.3, 0.45, 1.8), paint, collide=False)
    lv.box((x, 1.05, z - 0.15), (1.32, 0.38, 1.6), "glass_dark", collide=False)
    for dx in (-0.62, 0.62):
        for dz in (-1.05, 1.05):
            lv.box((x + dx, 0.25, z + dz), (0.2, 0.5, 0.5), "glass_dark", collide=False)


def tree(lv, x, z):
    lv.box((x, 1.6, z), (0.35, 3.2, 0.35), "wood_planks")
    for dx, dy, dz, s in ((0, 3.6, 0, 3.0), (0.8, 3.2, 0.5, 2.0), (-0.7, 3.3, -0.6, 2.2), (0.2, 4.4, 0.1, 2.0)):
        lv.box((x + dx, dy, z + dz), (s, s * 0.6, s), "foliage", collide=False)


def main() -> None:
    lv = Level("ShantiVihar")
    night_environment(lv)
    W = ("wall_exterior_cream", "wall_exterior_peach", "wall_exterior_sky", "wall_exterior_cream")
    # ---- ground: courtyard pavers, driveway, dirt edges
    lv.box((0, -0.1, 0), (64, 0.2, 56), "ground_pavers")
    lv.box((0, -0.095, 12), (6, 0.2, 32), "ground_asphalt", collide=False)
    # ---- four wings in a row, fronts towards the gate
    wings = {}
    for i, letter in enumerate("ABCD"):
        ox = -30 + i * 16
        wings[letter] = residential_wing(
            lv, f"Wing{letter}", ox, -24, letter=letter, exterior=W[i],
            lit_floors=((2,) if letter in "AC" else (1, 3) if letter == "D" else ()),
            tv_floors=((3,) if letter == "A" else ()), interior_floor=(4 if letter == "B" else None),
            flicker_floors=((2,) if letter == "B" else (4,) if letter == "D" else ()),
            door_unlock_events={"4B": "key_4b"})
        group = f"Wing{letter}"
        area(lv, group, "Patrol", (ox + 1.5, 1.0, -24 + 11.0), (3.0, 2.0, 2.0),
             {"script": script(lv, "res://scripts/props/patrol_point.gd"), "label": f'"{letter} Wing: all quiet."'})
        lock = usable(lv, group, "TerraceLock", (ox + 2.75, 15 + 1.1, -24 + 8.3), (0.3, 0.4, 0.3), "Padlock the terrace door",
                      {"door": 'NodePath("../TerraceDoor")'}, "res://scripts/props/padlock.gd")
        lv.box((0, 0, 0), (0.08, 0.12, 0.06), "metal_rust", collide=False, parent=lock)
    # ---- compound wall + gate (a pedestrian gap on the right)
    for p0, p1, s in (((-32, -28), (32, -28), -1), ((-32, -28), (-32, 28), -1), ((32, -28), (32, 28), +1),
                      ((-32, 28), (-3, 28), +1), ((3, 28), (32, 28), +1)):
        wall(lv, p0, p1, 0, 2.2, 0.23, "brick_red", "wall_exterior_cream", s)
    for i in range(26):
        x = -3 + 0.2 + i * 0.2
        if x < 2.0:
            lv.box((x, 1.0, 28), (0.03, 2.0, 0.03), "metal_gate_green", collide=False)
    lv.collider((-0.5, 1.0, 28), (5.0, 2.0, 0.15))
    for y in (0.2, 1.0, 1.9):
        lv.box((-0.5, y, 28), (5.0, 0.06, 0.05), "metal_gate_green", collide=False)
    lv.add("SocietyName", "Label3D", ".", {"position": v3(-0.2, 2.75, 28.2), "pixel_size": "0.006", "shaded": "true",
                                            "modulate": "Color(0.9, 0.85, 0.7, 1)", "font_size": "64", "outline_size": "0",
                                            "text": '"SHANTI VIHAR CO-OP. HSG. SOCIETY\\nशांति विहार को-ऑप. हाउसिंग सोसायटी"'})
    lv.box((-0.2, 2.75, 28.15), (6.4, 0.9, 0.08), "wood_door_dark", collide=False)
    # ---- watchman's cabin (x 4..7.5, z 22..25.5)
    slab(lv, 4, 7.5, 22, 25.5, 0.05, 0.05, "floor_kota", "floor_kota")
    slab(lv, 3.9, 7.6, 21.9, 25.6, 2.75, 0.15, "concrete_dark", "wall_paint_white")
    ext, inn = "wall_exterior_cream", "wall_paint_sky"
    wall(lv, (4, 22), (7.5, 22), 0, 2.6, 0.2, ext, inn, -1, [{"along": 5.75, "w": 1.4, "bottom": 0.9, "top": 2.0, "kind": "vent"}])
    wall(lv, (4, 25.5), (7.5, 25.5), 0, 2.6, 0.2, ext, inn, +1, [{"along": 5.75, "w": 1.4, "bottom": 0.9, "top": 2.0, "kind": "vent"}])
    wall(lv, (7.5, 22), (7.5, 25.5), 0, 2.6, 0.2, ext, inn, +1)
    wall(lv, (4, 22), (4, 25.5), 0, 2.6, 0.2, ext, inn, -1, [{"along": 23.0, "w": 1.0, "bottom": 0, "top": 2.1, "kind": "hole"}])
    lv.box((6.6, 0.38, 24.9), (1.5, 0.76, 0.6), "wood_planks")                       # table
    lv.box((5.3, 0.23, 24.4), (0.4, 0.46, 0.4), "metal_rust", collide=False)          # stool
    lv.scene("CabinTube", "res://scenes/props/tube_light.tscn", ".", {"position": v3(5.75, 2.6, 23.75)})
    cctv = lv.add("CCTV", "Node3D", ".", {"position": v3(7.0, 0.76, 25.0), "script": script(lv, "res://scripts/props/cctv_monitor.gd"),
                                          "cameras": 'Array[NodePath]([NodePath("../CamSpots/Gate"), NodePath("../CamSpots/Courtyard"), NodePath("../CamSpots/StairsB"), NodePath("../CamSpots/MeterRoom")])',
                                          "names": 'PackedStringArray("CAM 1  GATE", "CAM 2  B WING", "CAM 3  B STAIRS", "CAM 4  METER ROOM")'})
    lv.box((0, 0.2, 0.05), (0.42, 0.38, 0.36), "glass_dark", collide=False, parent=cctv)
    scr = lv.sub("QuadMesh", {"size": "Vector2(0.32, 0.24)"})
    lv.add("Screen", "MeshInstance3D", cctv, {"position": v3(0, 0.21, -0.131), "rotation_degrees": v3(0, 180, 0), "mesh": f'SubResource("{scr}")'})
    lv.add("Label", "Label3D", cctv, {"position": v3(0, 0.36, -0.14), "rotation_degrees": v3(0, 180, 0), "pixel_size": "0.0008",
                                      "font_size": "28", "outline_size": "0", "modulate": "Color(0.7, 1, 0.7, 1)", "text": '"CAM 1"'})
    area(lv, cctv, "Interactable", (0, 0.2, -0.1), (0.5, 0.45, 0.4), {"script": script(lv, "res://scripts/interaction/interactable.gd"), "prompt": '"Check the CCTV"'})
    reg = usable(lv, ".", "GateRegister", (6.3, 0.78, 24.85), (0.4, 0.15, 0.35), "Read the gate register", node_script=SCRIPTS + "gate_register.gd")
    lv.box((0, 0, 0), (0.32, 0.03, 0.24), "paper", collide=False, parent=reg)
    keys = usable(lv, ".", "KeyBoard", (7.38, 1.5, 23.2), (0.2, 0.4, 0.6), "Take the spare key for 4B",
                  {"event_id": '&"key_4b"', "message": '"Spare key: 4B. The tag says DESHMUKH."'}, "res://scripts/interaction/event_on_use.gd")
    lv.box((0, 0, 0), (0.03, 0.35, 0.5), "wood_door_dark", collide=False, parent=keys)
    icom = usable(lv, ".", "Intercom", (4.12, 1.4, 24.6), (0.2, 0.3, 0.25), "Intercom", {"event_id": '&"intercom_used"', "message": '"Intercom. Just a dial tone."', "once": "false"},
                  "res://scripts/interaction/event_on_use.gd")
    lv.box((0, 0, 0), (0.06, 0.22, 0.14), "metal_meter_white", collide=False, parent=icom)
    lv.add("CamSpots", "Node3D", ".")
    for name, pos, rot in (("Gate", (0, 3.0, 22), (-12, 180, 0)), ("Courtyard", (6, 3.5, 6), (16.5, 29.8, 0)),
                           ("StairsB", (-12.5, 2.6, -12.0), (-12, 0, 0)), ("MeterRoom", (18, 3.0, -4), (-14, -90, 0))):
        lv.add(name, "Marker3D", "CamSpots", {"position": v3(*pos), "rotation_degrees": v3(*rot)})
    # ---- meter room (x 26..30, z -6..-2) + society water tank beside it
    slab(lv, 26, 30, -6, -2, 0.05, 0.05, "concrete_rough", "concrete_rough")
    slab(lv, 25.9, 30.1, -6.1, -1.9, 2.9, 0.15, "concrete_dark", "wall_bare_stained")
    for p0, p1, s, ops in (((26, -6), (30, -6), -1, []), ((26, -2), (30, -2), +1, []), ((30, -6), (30, -2), +1, []),
                           ((26, -6), (26, -2), -1, [{"along": -4.0, "w": 1.2, "bottom": 0, "top": 2.2, "kind": "door", "frame": "metal_meter_white"}])):
        wall(lv, p0, p1, 0, 2.9, 0.2, "wall_exterior_sky", "wall_bare_stained", s, ops)
    lv.scene("MeterDoor", "res://scenes/props/door.tscn", ".", {"position": v3(26, 0, -3.45), "rotation_degrees": v3(0, 90, 0)})
    for row in range(3):
        for col in range(5):
            z = -5.5 + col * 0.72
            y = 1.0 + row * 0.55
            lv.box((29.82, y, z), (0.15, 0.42, 0.32), "metal_meter_white", collide=False)
            lv.box((29.74, y + 0.06, z), (0.01, 0.1, 0.14), "glass_dark", collide=False)
    lv.box((29.85, 2.2, -4.0), (0.08, 0.7, 3.6), "glass_dark", collide=False)  # cable tray / wires
    lv.scene("MeterTube", "res://scenes/props/tube_light.tscn", ".", {"position": v3(28, 2.8, -4), "flicker": "0.8"})
    for name, pos in (("water_stain", (28, 2.79, -3.2)), ("crack_b", (26.12, 1.6, -5.2)), ("hand_grime", (29.75, 1.4, -2.6))):
        rot = (90, 0, 0) if name == "water_stain" else ((0, 90, 0) if pos[0] < 27 else (0, -90, 0))
        lv.scene(name, f"res://scenes/decals/{name}.tscn", ".", {"position": v3(*pos), "rotation_degrees": v3(*rot)})
    for dx in (0, 3.6):
        for dz in (0, 3.6):
            lv.box((26.2 + dx, 3.0, 2.2 + dz), (0.4, 6.0, 0.4), "concrete_rough")
    lv.box((28.0, 7.25, 4.0), (4.2, 2.5, 4.2), "concrete_dirty")
    for i in range(20):
        lv.box((25.8, 0.3 + i * 0.32, 4.0), (0.05, 0.04, 0.5), "metal_rust", collide=False)
    # ---- parking: scooters, cars, trees
    paints = ("paint_car_red", "paint_car_blue", "paint_car_white", "metal_painted_green" if False else "metal_gate_green")
    for i in range(6):
        scooter(lv, -5.2, 6 + i * 1.1, paints[i % 4])
        scooter(lv, 5.2, 4 + i * 1.1, paints[(i + 2) % 4], -1)
    car(lv, -20, 12, "paint_car_white")
    car(lv, -16.5, 12.4, "paint_car_red")
    car(lv, 16, 12, "paint_car_blue")
    tree(lv, -26, 20)
    tree(lv, 24, 18)
    # ---- street lamps
    for i, (x, z, f) in enumerate(((-4, 22, 1), (4, 10, -1), (-4, -2, 1), (4, -10, -1), (-22, 6, 1), (22, 6, -1))):
        sodium_lamp(lv, x, z, facing_x=f, shadow=i in (0, 2))
    # ---- ambience
    amb = lv.add("Ambience", "Node3D", ".", {"script": script(lv, "res://scripts/props/ambience.gd")})
    for name, snd, vol in (("CricketsLoop", "crickets_loop", -12), ("TrafficLoop", "traffic_loop", -18)):
        lv.add(name, "AudioStreamPlayer", amb, {"stream": f'ExtResource("{lv.ext(f"res://assets/audio/sfx/{snd}.wav", "AudioStream")}")',
                                               "volume_db": f"{vol}.0", "bus": '&"Ambience"'})
    lv.add("OneShots", "Node3D", amb)
    for name, snd in (("Dog1", "dog_bark"), ("Dog2", "dog_bark"), ("Horn", "horn_far")):
        lv.add(name, "AudioStreamPlayer3D", f"{amb}/OneShots", {"stream": f'ExtResource("{lv.ext(f"res://assets/audio/sfx/{snd}.wav", "AudioStream")}")',
                                                                "unit_size": "25.0", "volume_db": "-6.0", "bus": '&"Ambience"'})
    # ---- chapter flow: objectives, checkpoints, end of the round
    lv.add("ObjectiveLoader", "Node", ".", {"script": script(lv, "res://scripts/objectives/objective_loader.gd"),
                                           "objective_set": f'ExtResource("{lv.ext("res://chapters/tape_01_watchman/objectives.tres", "Resource")}")'})
    lv.add("Checkpoints", "Node3D", ".")
    for name, pos in (("start", (5.75, 0, 23.6)), ("courtyard", (0, 0, 2)), ("terraces", (-12.5, 15, -15.5))):
        area(lv, "Checkpoints", name, pos, (3, 3, 3), {"script": script(lv, "res://scripts/chapters/checkpoint.gd"), "checkpoint_id": f'&"{name}"'})
    area(lv, ".", "CabinZone", (5.75, 1.2, 23.75), (3.2, 2.4, 3.2), {"script": script(lv, "res://scripts/events/trigger_zone.gd"),
                                                                    "event_id": '&"back_at_cabin"', "armed_by": '&"lock_terraces"'})
    lv.add("EndRound", "Node", ".", {"script": script(lv, "res://scripts/events/method_reaction.gd"),
                                     "targets": 'Array[NodePath]([NodePath("/root/Game")])', "method": '&"complete_chapter"',
                                     "on_event": '&"back_at_cabin"', "delay": "3.0"})
    lv.add("EndMessage", "Node", ".", {"script": script(lv, "res://scripts/events/method_reaction.gd"),
                                       "targets": 'Array[NodePath]([NodePath("../HUD")])', "method": '&"show_message"',
                                       "args": '["First round done. Everything is quiet. (Story events: next build step.)", 4.0]',
                                       "on_event": '&"back_at_cabin"'})
    player_rig(lv, 5.75, 23.6, 0.0, debug=False)
    benchmark_points(lv, [(5.75, 0, 23.6), (0, 0, 2), (-12.5, 6, -14.8), (0, 0, -10), (28, 0, -4)])
    lv.write(os.path.join(OUT_DIR, "shanti_vihar.tscn"))

    # ---- objectives (Raghu's normal night duties)
    objs = [("sign_register", "Sign in at the gate register", "register_signed", 1, ""),
            ("check_cctv", "Check the CCTV monitor", "cctv_checked", 1, "sign_register"),
            ("patrol", "Patrol the four wings", "patrol_point", 4, "check_cctv"),
            ("lock_terraces", "Padlock the terrace doors", "terrace_locked", 4, "patrol"),
            ("return_cabin", "Go back to the cabin", "back_at_cabin", 1, "lock_terraces")]
    lines = ['[gd_resource type="Resource" script_class="ObjectiveSet" format=3]', "",
             '[ext_resource type="Script" path="res://scripts/objectives/objective_set.gd" id="1_set"]',
             '[ext_resource type="Script" path="res://scripts/objectives/objective_data.gd" id="2_data"]', ""]
    for oid, text, ev, req, after in objs:
        lines += [f'[sub_resource type="Resource" id="O_{oid}"]', 'script = ExtResource("2_data")', f'id = &"{oid}"',
                  f'text = "{text}"', f'complete_on = &"{ev}"', f"required = {req}", f'starts_after = &"{after}"', ""]
    lines += ["[resource]", 'script = ExtResource("1_set")',
              "objectives = Array[ExtResource(\"2_data\")]([" + ", ".join(f'SubResource("O_{o[0]}")' for o in objs) + "])", ""]
    with open(os.path.join(OUT_DIR, "objectives.tres"), "w", encoding="utf-8", newline="\n") as f:
        f.write("\n".join(lines))
    print("wrote objectives.tres")


if __name__ == "__main__":
    main()
