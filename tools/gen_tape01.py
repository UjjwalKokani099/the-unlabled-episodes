"""Builds Tape 1's level: chapters/tape_01_watchman/shanti_vihar.tscn (story bible:
Shanti Vihar Housing Society, 14 March 1998, 10:40 PM) and its objectives.
Compound x -32..32, z -28..28; gate at +z. Wings A-D in a row (fronts face the gate).
Run: python tools/gen_tape01.py
"""
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from levelkit import (ROOT, Level, acoustic_zone, benchmark_points, night_environment, player_rig,  # noqa: E402
                      residential_wing, slab, sodium_lamp, v3, wall)
from propkit import Props  # noqa: E402

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


def sound(lv, name):
    return f'ExtResource("{lv.ext(f"res://assets/audio/sfx/{name}.wav", "AudioStream")}")'


def character(lv, name, kind, parent, pos, yaw, props=None):
    return lv.scene(name, f"res://scenes/characters/{kind}.tscn", parent,
                    {"position": v3(*pos), "rotation_degrees": v3(0, yaw, 0), **(props or {})})


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


def story_beats(lv) -> None:
    """3:12 AM onwards (story bible, Tape 1): Deshmukh walks out, CCTV-only balcony figure,
    4B dressing, the Cameraman's three hidden appearances + the ending shot, zones, power.
    Timing and dialogue live in chapters/tape_01_watchman/scripts/tape01_director.gd."""
    walk = lv.add("Deshmukh", "Node3D", ".", {
        "script": script(lv, "res://scripts/characters/npc_walker.gd"),
        "points": "PackedVector3Array(-2, 0, 2, -0.5, 0, 10, 1, 0, 20, 2.5, 0, 26.6, 2.5, 0, 29.6, -4, 0, 31.6, -34, 0, 31.6)",
        "speed": "1.15", "start_event": '&"deshmukh_walk"',
        "waypoint_events": 'PackedStringArray("", "", "", "deshmukh_at_gate", "deshmukh_left")',
        "arrived_event": '&"deshmukh_gone"', "step_sound": sound(lv, "footstep_chappal")})
    character(lv, "Body", "deshmukh", walk, (0, 0, 0), 0)
    # ...yet on the CCTV he stands on his balcony (only cameras see this node)
    bal = lv.add("BalconyDeshmukh", "Node3D", ".", {"script": script(lv, "res://scripts/characters/cctv_only.gd"),
                                                     "position": v3(-4.9, 12.0, -13.15), "rotation_degrees": v3(0, 180, 0),
                                                     "visible": "false"})
    character(lv, "Body", "deshmukh", bal, (0, 0, 0), 0)
    lv.add("Light", "OmniLight3D", bal, {"position": v3(0.3, 2.2, -0.9), "light_color": "Color(0.8, 0.85, 1, 1)",
                                         "light_energy": "2.4", "omni_range": "3.5"})
    # flat 4B: empty for eight months
    p = Props(lv)
    for pos, size in (((-8.2, 12.42, -15.6), (2.0, 0.8, 0.9)), ((-5.0, 12.38, -17.6), (1.2, 0.75, 0.8)),
                      ((-3.2, 12.55, -15.0), (0.9, 1.1, 0.6)), ((-9.0, 12.5, -21.5), (1.9, 0.6, 1.4))):
        p.dust_sheet(pos, size)  # furniture under dust sheets
    # the clock on the living-room wall stopped at 3:12
    p.model("wall_clock", (-7.2, 14.3, -14.12), node_name="StoppedClock", script="res://scripts/props/wall_clock.gd",
            stopped_at=3 * 3600 + 12 * 60 + 7)
    # curtains drawn across the living-room window (x -9.4..-8.2)
    for x in (-9.12, -8.48):
        p.cloth((x, 14.22, -14.17), 0.66, 1.42, (0.36, 0.4, 0.34), folds=5.0, fold_depth=0.03, gather=0.6, sway=0.0,
                name="FlatCurtain")
    p.cyl((-8.8, 14.24, -14.15), 0.01, 0.01, 1.5, "steel", rot=(0, 0, 90), seg=6)
    for name, pos, rot in (("water_stain", (-7.0, 14.84, -17.0), (90, 0, 0)), ("water_stain", (-3.5, 14.84, -21.0), (90, 20, 0)),
                           ("crack_a", (-10.88, 13.6, -17.6), (0, 90, 0)), ("crack_b", (-2.12, 12.5, -16.3), (0, -90, 0))):
        lv.scene(name, f"res://scenes/decals/{name}.tscn", ".", {"position": v3(*pos), "rotation_degrees": v3(*rot)})
    papers = usable(lv, ".", "Newspapers", (-10.55, 12.05, -15.65), (0.42, 0.12, 0.5), "Look at the newspapers",
                    {"title": '"Newspapers"',
                     "description": '"Weeks of them, still folded, pushed under the door. The newest is from 23 July 1997."'},
                    "res://scripts/interaction/inspectable.gd")
    pmodel = lv.add("Model", "Node3D", papers)
    for i in range(6):
        lv.box(((i % 2) * 0.06 - 0.05, -0.02 + i * 0.012, -(i % 3) * 0.05 + 0.05), (0.32, 0.012, 0.42), "paper",
               collide=False, parent=pmodel)
    lv.add("Headline", "Label3D", pmodel, {"position": v3(-0.05, 0.045, 0.0), "rotation_degrees": v3(-90, 0, 0),
                                           "pixel_size": "0.0006", "font_size": "48", "outline_size": "0",
                                           "modulate": "Color(0.1, 0.1, 0.1, 1)",
                                           "text": '"MUMBAI SAMACHAR\n23 JULY 1997\n—————"'})
    lv.add("Calendar", "Label3D", ".", {"position": v3(-2.13, 13.6, -16.0), "rotation_degrees": v3(0, -90, 0),
                                         "pixel_size": "0.002", "shaded": "true", "outline_size": "0", "font_size": "48",
                                         "modulate": "Color(0.25, 0.1, 0.1, 1)", "text": '"JULY 1997\\nजुलाई 1997"'})
    lv.box((-2.2, 13.55, -16.0), (0.02, 0.6, 0.42), "paper", collide=False)
    lv.box((-10.85, 13.4, -16.4), (0.05, 0.22, 0.13), "metal_meter_white", collide=False)   # 4B intercom panel
    lv.box((-10.83, 12.78, -16.38), (0.05, 0.22, 0.06), "glass_dark", collide=False)        # handset, off the hook
    lv.add("FlatBreath", "AudioStreamPlayer3D", ".", {"position": v3(-10.8, 12.8, -16.4), "stream": sound(lv, "breathing"),
                                                       "volume_db": "-4.0", "unit_size": "2.0", "bus": '&"SFX"'})
    # the Cameraman: three hidden appearances (spot them) + the last CCTV frame
    character(lv, "CamStairs", "cameraman", ".", (-12.2, 0, -15.2), 180,
              {"active": "false", "cctv_only": "true", "tracking_noise": "0.0"})
    lv.add("SpotCCTV", "Node3D", ".", {"position": v3(7.0, 0.97, 24.87), "script": script(lv, "res://scripts/story/spottable.gd"),
                                        "spot_id": '&"t1_cctv_stairs"', "monitor": 'NodePath("../CCTV")',
                                        "monitor_camera": "2", "active": "false"})
    character(lv, "Cam4B", "cameraman", ".", (-4.25, 12.0, -20.6), 180,
              {"active": "false", "spot_id": '&"t1_flat_4b"', "vanish_when_unseen": "true"})
    # spot 3: a figure on D wing's lit 3rd-floor balcony during the first round ("watching")
    character(lv, "CamWindowD", "cameraman", ".", (27.1, 9.0, -13.3), 180,
              {"active": "false", "spot_id": '&"t1_d_balcony"', "vanish_when_unseen": "true",
               "spot_max_distance": "48.0", "vanish_distance": "6.0", "tracking_noise": "0.15"})
    character(lv, "CamEnding", "cameraman", ".", (26.9, 0, -4.0), -70,
              {"active": "false", "tracking_noise": "0.0", "steady_dot": "true"})
    character(lv, "RaghuStandIn", "raghu", ".", (28.6, 0, -3.0), 180, {"visible": "false"})
    # zones that move the night along (they fire Events ids; the director and objectives listen)
    trig = "res://scripts/events/trigger_zone.gd"
    for name, pos, size, ev, armed in (("BalconyZone", (-5, 1.2, -7), (9, 2.4, 7), "balcony_checked", "cctv_deshmukh"),
                                       ("FlatZone", (-7, 13.2, -16.5), (5, 2.4, 4), "4b_checked", "take_key"),
                                       ("CabinZone2", (5.75, 1.2, 23.75), (3.2, 2.4, 3.2), "cabin_return2", "check_4b"),
                                       ("MeterZone", (28, 1.2, -4), (3.6, 2.4, 3.6), "meter_room_reached", "power_cut")):
        area(lv, ".", name, pos, size, {"script": script(lv, trig), "event_id": f'&"{ev}"', "armed_by": f'&"{armed}"'})
    # ---- people (Phase 4): NPC base scene + a character model under Model
    nav_mesh = lv.sub("NavigationMesh", {
        "geometry_parsed_geometry_type": "1", "geometry_collision_mask": "1",
        "geometry_source_geometry_mode": "1", "geometry_source_group_name": '&"nav_source"',
        "cell_size": "0.25", "cell_height": "0.25", "agent_radius": "0.25", "agent_height": "1.75",
        "agent_max_climb": "0.25", "agent_max_slope": "40.0",
        "filter_baking_aabb": "AABB(-40, -1, -34, 80, 4, 80)"})  # ground level only: NPCs stay down here
    lv.add("Navigation", "NavigationRegion3D", ".", {"script": script(lv, "res://scripts/kit/nav_baker.gd"),
                                                     "navigation_mesh": f'SubResource("{nav_mesh}")'})
    npc = "res://scenes/characters/npc.tscn"
    # Mr. Deshmukh, early in the night, under B wing: body turned to the gate (uncanny head)
    lv.scene("DeshmukhNPC", npc, ".", {"position": v3(-10.4, 0, -11.5), "rotation_degrees": v3(0, 180, 0),
                                       "display_name": '"Mr. Deshmukh"', "dialogue": '"res://dialogue/tape01/deshmukh.json"',
                                       "talked_event": '&"talked_deshmukh"', "uncanny": "true", "look_distance": "7.0",
                                       "walk_speed": "0.9"})
    character(lv, "Deshmukh", "deshmukh", "DeshmukhNPC/Model", (0, 0, 0), 0)
    # Mrs. Iyer of 2C: comes down for her parcel after the first CCTV check
    lv.scene("IyerNPC", npc, ".", {"position": v3(3.5, 0, -13.2), "display_name": '"Mrs. Iyer"',
                                   "dialogue": '"res://dialogue/tape01/iyer.json"', "talked_event": '&"talked_iyer"',
                                   "active": "false", "walk_speed": "1.0"})
    character(lv, "Iyer", "iyer", "IyerNPC/Model", (0, 0, 0), 0)
    parcel = usable(lv, ".", "Parcel", (6.9, 0.12, 22.4), (0.42, 0.3, 0.36), "Pick up the parcel for 2C",
                    {"item_id": '&"parcel_2c"', "display_name": '"Parcel for 2C"'}, "res://scripts/interaction/pickup.gd")
    lv.box((0, 0, 0), (0.36, 0.22, 0.28), "cardboard", collide=False, parent=parcel)
    lv.add("Label", "Label3D", parcel, {"position": v3(0, 0.111, 0), "rotation_degrees": v3(-90, 0, 0),
                                        "pixel_size": "0.0012", "font_size": "48", "outline_size": "0",
                                        "modulate": "Color(0.1, 0.1, 0.1, 1)", "text": '"IYER  2C"'})

    # ---- the Cameraman stalks the dark courtyard after the power cut (Phase 5)
    stalker = lv.scene("Stalker", npc, ".", {"position": v3(14, 0, -2), "display_name": '"?"', "active": "false",
                                             "walk_speed": "0.85"})
    character(lv, "Cameraman", "cameraman", "Stalker/Model", (0, 0, 0), 0, {"tracking_noise": "0.0"})
    lv.add("Brain", "Node", stalker, {"script": script(lv, "res://scripts/characters/stalker.gd"),
                                      "patrol_points": "PackedVector3Array(14, 0, -2, 22, 0, 1, 20, 0, 9, 9, 0, 7, 8, 0, -4)"})
    # places to hide from his camera: crouch behind the cars, the covered car, the tank pillars
    Props(lv).model("covered_car", (11, 0.3, 2), node_name="CoveredCar")  # a car under a dust cover
    lv.collider((11, 0.65, 2), (1.8, 1.3, 4.3), "metal")
    hide = "res://scripts/story/hiding_spot.gd"
    for name, pos, size in (("HideBlueCar", (16, 0.9, 12), (3.2, 1.8, 4.8)), ("HideCoveredCar", (11, 0.9, 2), (3.4, 1.8, 5.2)),
                            ("HideTank", (28, 0.9, 4), (4.6, 1.8, 4.6)), ("HideWestCars", (-18.2, 0.9, 12.2), (6.6, 1.8, 4.9))):
        area(lv, ".", name, pos, size, {"script": script(lv, hide)})
    # footsteps one floor up in B wing's stairs, matching Raghu's, on the way to 4B
    area(lv, ".", "StepsAboveB", (-12.5, 6, -16.9), (3.0, 12.0, 5.8),
         {"script": script(lv, "res://scripts/story/footsteps_above.gd"), "armed_by": '&"intercom_answered"'})

    # mains power + the story director
    glow = ", ".join(f'ExtResource("{lv.ext(f"res://assets/materials/{m}.tres", "Material")}")'
                     for m in ("glass_sodium", "glass_lit_warm", "glass_lit_tv"))
    lv.add("Power", "Node", ".", {"script": script(lv, "res://scripts/props/power_grid.gd"),
                                  "glow_materials": f"Array[BaseMaterial3D]([{glow}])"})
    lv.add("Story", "Node", ".", {"script": script(lv, SCRIPTS + "tape01_director.gd")})


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
    # wicket gate in the pedestrian gap (hinge at x=3). Opens outwards for Deshmukh only.
    wicket = lv.add("Wicket", "Node3D", ".", {"position": v3(3.0, 0, 28)})
    for i in range(5):
        lv.box((-0.12 - i * 0.2, 0.75, 0), (0.03, 1.5, 0.03), "metal_gate_green", collide=False, parent=wicket)
    for y in (0.15, 0.75, 1.45):
        lv.box((-0.5, y, 0), (0.95, 0.05, 0.04), "metal_gate_green", collide=False, parent=wicket)
    lv.collider((2.5, 1.0, 28), (1.0, 2.0, 0.15))
    # the lane outside: asphalt, the facing compound wall, dark buildings, one lamp
    lv.box((0, -0.095, 33.5), (96, 0.2, 11), "ground_asphalt", collide=False)
    wall(lv, (-48, 39), (48, 39), 0, 2.4, 0.23, "wall_exterior_peach", "brick_red", -1, collide=False)
    for x, w, h, mat in ((-30, 16, 12, "wall_exterior_sky"), (-10, 14, 9, "wall_exterior_cream"),
                         (12, 18, 15, "wall_exterior_peach"), (34, 14, 9, "wall_exterior_cream")):
        lv.box((x, h / 2, 45), (w, h, 10), mat, collide=False)
    for x, y in ((-33, 4.5), (13, 7.5), (8, 10.5)):
        lv.box((x, y, 39.97), (1.2, 1.1, 0.05), "glass_lit_warm", collide=False, shadow=False)
    sodium_lamp(lv, -12, 37.6, facing_x=1)
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
    # table: top, legs, aprons, and a drawer (Kishan's ID card + a spare camcorder battery)
    lv.box((6.6, 0.74, 24.9), (1.5, 0.04, 0.6), "wood_planks")
    for lx in (5.9, 7.3):
        for lz in (24.65, 25.15):
            lv.box((lx, 0.36, lz), (0.05, 0.72, 0.05), "wood_planks")
    lv.box((6.6, 0.65, 25.17), (1.4, 0.14, 0.02), "wood_planks", collide=False)
    lv.box((5.98, 0.65, 24.62), (0.26, 0.14, 0.02), "wood_planks", collide=False)
    lv.box((6.96, 0.65, 24.62), (0.76, 0.14, 0.02), "wood_planks", collide=False)
    lv.collider((6.6, 0.36, 24.9), (1.5, 0.5, 0.6), "wood")  # keeps the player out from under it
    drawer = lv.scene("TableDrawer", "res://scenes/props/drawer.tscn", ".",
                      {"position": v3(6.35, 0.655, 24.86), "rotation_degrees": v3(0, 180, 0)})
    card = usable(lv, drawer, "KishanID", (-0.08, -0.042, 0.02), (0.14, 0.05, 0.1), "Look at the ID card",
                  {"title": "\"Kishan's ID card\"",
                   "description": '"SHANTI VIHAR CHS — WATCHMAN No. 07 — KISHAN LAL, since 1991. Left in the drawer. '
                                  'He never came back for it. Someone has cut the photo out."',
                   "inspected_event": '&"kishan_card"'}, "res://scripts/interaction/inspectable.gd")
    model = lv.add("Model", "Node3D", card)
    lv.box((0, 0, 0), (0.086, 0.003, 0.054), "paper", collide=False, parent=model)
    lv.box((-0.026, 0.0012, 0), (0.024, 0.002, 0.03), "glass_dark", collide=False, parent=model)
    lv.add("Text", "Label3D", model, {"position": v3(0.012, 0.0022, 0), "rotation_degrees": v3(-90, 0, 0),
                                      "pixel_size": "0.00012", "font_size": "48", "outline_size": "0",
                                      "modulate": "Color(0.15, 0.12, 0.1, 1)",
                                      "text": '"SHANTI VIHAR CHS\nWATCHMAN\nKISHAN LAL\nNo. 07  1991"'})
    lv.scene("Battery", "res://scenes/props/battery.tscn", drawer, {"position": v3(0.12, -0.035, -0.06)})
    stool = lv.add("Stool", "Node3D", ".", {"position": v3(5.3, 0, 24.4)})  # moves by itself after the cut
    Props(lv).model("wooden_stool_01", (0, 0, 0), parent=stool, node_name="Model")
    dress_cabin(lv)
    dress_grounds(lv)
    dress_stairwells(lv, wings)
    place_acoustics(lv, wings)
    lv.scene("CabinTube", "res://scenes/props/tube_light.tscn", ".", {"position": v3(5.75, 2.6, 23.75)}, groups=["mains"])
    lv.add("CabinFan", "AudioStreamPlayer3D", ".", {"position": v3(5.75, 2.4, 23.75), "stream": sound(lv, "fan_hum"),
                                                     "volume_db": "-16.0", "unit_size": "3.0", "autoplay": "true",
                                                     "bus": '&"Ambience"'}, groups=["mains"])
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
    icom = usable(lv, ".", "Intercom", (4.12, 1.4, 24.6), (0.2, 0.3, 0.25), "Intercom",
                  {"ring_event": '&"intercom_ring"', "answered_event": '&"intercom_answered"', "use_event": '&"intercom_used"',
                   "idle_message": '"Intercom. Just a dial tone."', "ring_sound": sound(lv, "intercom_buzz"),
                   "answer_prompt": '"Answer the intercom (4B)"'}, "res://scripts/props/ringing_phone.gd")
    lv.box((0, 0, 0), (0.06, 0.22, 0.14), "metal_meter_white", collide=False, parent=icom)
    led = lv.add("Led", "Node3D", icom, {"position": v3(0.035, 0.06, -0.03)})
    lv.box((0, 0, 0), (0.01, 0.02, 0.02), "glass_sodium", collide=False, shadow=False, parent=led)
    lv.add("Glow", "OmniLight3D", led, {"light_color": "Color(1, 0.15, 0.05, 1)", "light_energy": "0.4", "omni_range": "0.6"})
    lv.add("Breath", "AudioStreamPlayer3D", icom, {"stream": sound(lv, "breathing"), "volume_db": "-2.0", "unit_size": "2.0",
                                                   "bus": '&"SFX"'})
    phone = usable(lv, ".", "Phone", (5.97, 0.8, 24.85), (0.24, 0.2, 0.25), "Use the phone",
                   {"use_event": '&"phone_used"', "ring_sound": sound(lv, "phone_ring")}, "res://scripts/props/ringing_phone.gd")
    lv.box((0, 0, 0), (0.18, 0.07, 0.21), "glass_dark", collide=False, parent=phone)
    lv.box((0, 0.06, 0), (0.2, 0.04, 0.06), "glass_dark", collide=False, parent=phone)
    lv.add("CamSpots", "Node3D", ".")
    # B WING feed: narrow lens on the 4B balcony. METER ROOM feed: inside, from the far corner.
    for name, pos, rot, fov in (("Gate", (0, 3.0, 22), (-12, 180, 0), 75), ("Courtyard", (-1, 5.5, 0), (28.6, 16.5, 0), 15),
                                ("StairsB", (-12.5, 2.6, -12.0), (-12, 0, 0), 75),
                                ("MeterRoom", (29.55, 2.6, -5.55), (-28, 137.7, 0), 70)):
        lv.add(name, "Marker3D", "CamSpots", {"position": v3(*pos), "rotation_degrees": v3(*rot), "metadata/fov": f"{fov}.0"})
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
    lv.scene("MeterTube", "res://scenes/props/tube_light.tscn", ".", {"position": v3(28, 2.8, -4), "flicker": "0.8"},
             groups=["mains"])
    main = usable(lv, ".", "MainSwitch", (28.6, 1.45, -2.2), (0.45, 0.55, 0.35), "Reset the main switch",
                  {"event_id": '&"main_switch"'}, "res://scripts/interaction/event_on_use.gd")
    lv.box((0, 0, -0.04), (0.36, 0.48, 0.12), "metal_meter_white", collide=False, parent=main)
    lv.box((0.2, -0.05, -0.08), (0.05, 0.22, 0.05), "paint_car_red", collide=False, parent=main)
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
    for name, snd in (("Dog1", "dog_bark"), ("Dog2", "dog_bark"), ("Horn", "horn_far"), ("Train", "train_far")):
        lv.add(name, "AudioStreamPlayer3D", f"{amb}/OneShots", {"stream": f'ExtResource("{lv.ext(f"res://assets/audio/sfx/{snd}.wav", "AudioStream")}")',
                                                                "unit_size": "25.0", "volume_db": "-6.0", "bus": '&"Ambience"'})
    # ---- chapter flow: objectives, checkpoints, end of the round
    lv.add("ObjectiveLoader", "Node", ".", {"script": script(lv, "res://scripts/objectives/objective_loader.gd"),
                                           "objective_set": f'ExtResource("{lv.ext("res://chapters/tape_01_watchman/objectives.tres", "Resource")}")'})
    lv.add("Checkpoints", "Node3D", ".")
    for name, pos in (("start", (5.75, 0, 23.6)), ("courtyard", (0, 0, 2)), ("terraces", (-12.5, 15, -15.5)),
                      ("wing_b4", (-12.5, 12, -15.0))):
        area(lv, "Checkpoints", name, pos, (3, 3, 3), {"script": script(lv, "res://scripts/chapters/checkpoint.gd"), "checkpoint_id": f'&"{name}"'})
    area(lv, ".", "CabinZone", (5.75, 1.2, 23.75), (3.2, 2.4, 3.2), {"script": script(lv, "res://scripts/events/trigger_zone.gd"),
                                                                    "event_id": '&"back_at_cabin"', "armed_by": '&"lock_terraces"'})
    story_beats(lv)
    player_rig(lv, 5.75, 23.6, 0.0, debug=False)
    benchmark_points(lv, [(5.75, 0, 23.6), (0, 0, 2), (-12.5, 6, -14.8), (0, 0, -10), (28, 0, -4)])
    lv.write(os.path.join(OUT_DIR, "shanti_vihar.tscn"))

    # ---- objectives (Raghu's normal night duties)
    objs = [("sign_register", "Sign in at the gate register", "register_signed", 1, ""),
            ("check_cctv", "Check the CCTV monitor", "cctv_checked", 1, "sign_register"),
            ("give_parcel", "Give Mrs. Iyer her parcel", "parcel_given", 1, "check_cctv"),
            ("patrol", "Patrol the four wings", "patrol_point", 4, "check_cctv"),
            ("lock_terraces", "Padlock the terrace doors", "terrace_locked", 4, "patrol"),
            ("return_cabin", "Go back to the cabin", "back_at_cabin", 1, "lock_terraces"),
            # 3 AM: the wrong thing, escalation, ending (story bible)
            ("sign_3am", "Write the 3 AM round in the register", "register_3am", 1, "return_cabin"),
            ("watch_gate", "Keep an eye on the gate", "deshmukh_left", 1, "sign_3am"),
            ("log_deshmukh", "Write Mr. Deshmukh's exit in the register", "deshmukh_logged", 1, "watch_gate"),
            ("cctv_again", "Check the CCTV", "cctv_deshmukh", 1, "log_deshmukh"),
            ("look_balcony", "Look up at the 4B balcony", "balcony_checked", 1, "cctv_again"),
            ("answer_intercom", "Answer the intercom", "intercom_answered", 1, "look_balcony"),
            ("take_key", "Take the spare key for 4B", "key_4b", 1, "answer_intercom"),
            ("check_4b", "Go up and check flat 4B", "4b_checked", 1, "take_key"),
            ("back_to_cabin", "Go back to the cabin", "cabin_return2", 1, "check_4b"),
            ("read_register", "Write the 4B check in the register", "register_read_late", 1, "back_to_cabin"),
            ("call_secretary", "Phone the society secretary", "secretary_called", 1, "read_register"),
            ("meter_room", "Go to the meter room (by D Wing)", "meter_room_reached", 1, "call_secretary"),
            ("main_switch", "Reset the main switch", "main_switch", 1, "meter_room")]
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


def place_acoustics(lv: Level, wings: dict) -> None:
    """Reverb zones: the courtyard's slap-back between the wings, concrete stairwells, the
    cabin and meter room, and the empty flat 4B (scripts/audio/acoustic_zone.gd)."""
    group = lv.add("Acoustics", "Node3D", ".")
    acoustic_zone(lv, "Courtyard", (0, 4, 7), (64, 8, 42), "yard", parent=group)
    acoustic_zone(lv, "Cabin", (5.75, 1.3, 23.75), (3.5, 2.6, 3.5), "hard_room", parent=group)
    acoustic_zone(lv, "MeterRoom", (28, 1.45, -4), (4, 2.9, 4), "hard_room", parent=group)
    acoustic_zone(lv, "Flat4B", (-6.5, 13.5, -19), (9, 3, 10), "empty_room", parent=group)
    for letter, info in wings.items():
        lx, _, lz = info["landings"][0]
        ox, oz = lx - 1.5, lz - 9.2
        acoustic_zone(lv, f"Stairs{letter}", (ox + 1.5, 9.0, oz + 7.1), (3.0, 18.0, 5.8), "stair", parent=group)


def dress_stairwells(lv: Level, wings: dict) -> None:
    """Every flat's landing: doormat, shoes left outside, the odd clay pot, paan in the corner,
    hand grime by the door. 4B (empty) gets old newspapers at its door instead of shoes.
    Wing core: x 0..3 from the wing origin, landing z 8.4..10, flat door in the x=3 wall."""
    p = Props(lv)
    for wi, (letter, info) in enumerate(wings.items()):
        for fl, (lx, y, lz) in info["landings"].items():
            if fl == 0:
                continue
            ox, oz = lx - 1.5, lz - 9.2
            flat = f"{fl}{letter}"
            seed = wi * 7 + fl * 3
            p.doormat((ox + 2.55, y, oz + 9.2), yaw=90)
            if flat == "4B":
                p.newspaper_stack((ox + 2.5, y, oz + 8.7), yaw=12, n=7)
            else:
                p.chappals((ox + 2.35, y, oz + 8.75 + (seed % 3) * 0.1), yaw=80 + seed * 23 % 40,
                           mat=("rubber", "cloth_maroon", "plastic_blue")[seed % 3])
                if seed % 2 == 0:
                    p.chappals((ox + 2.45, y, oz + 9.75), yaw=100, mat="rubber")
            if seed % 3 != 1:
                p.model("planter_pot_clay", (ox + 0.32, y, oz + 9.75), yaw=seed * 47, visibility_end=20.0)
            decals = [("paan_a" if seed % 2 else "paan_b", (ox + 0.12, y + 0.3, oz + 8.6), (0, 90, 0))]
            decals.append(("hand_grime", (ox + 2.88, y + 1.15, oz + 8.5), (0, -90, 0)))
            for i, (name, pos, rot) in enumerate(decals):
                lv.scene(f"{name}_{flat}_{i}", f"res://scenes/decals/{name}.tscn", ".",
                         {"position": v3(*pos), "rotation_degrees": v3(*rot)})


def dress_grounds(lv: Level) -> None:
    """Real-model clutter around the compound: parking junk, garbage by the gate, the meter
    room's boxes, and CCTV camera bodies at the feeds (layer 19: not in their own picture)."""
    p = Props(lv)
    far = 45.0  # small clutter stops drawing beyond this
    p.model("old_tyre", (-22.6, 0.3, 13.7), yaw=25, visibility_end=far)
    p.model("old_tyre", (-22.3, 0.08, 14.6), pitch=90, yaw=10, visibility_end=far)
    p.model("plastic_crate_01", (-21.6, 0, 14.4), yaw=5, visibility_end=far)
    p.model("plastic_crate_01", (-21.62, 0.26, 14.42), yaw=-8, visibility_end=far)
    for i, (x, z, yaw) in enumerate(((-3.6, 26.9, 0), (-3.0, 27.25, 40), (-4.1, 27.3, -30))):
        p.model("trashbag", (x, 0, z), yaw=yaw, visibility_end=far)
    for x, z, yaw in ((-2.4, 26.6, 0), (2.2, 18.4, 70), (-7.5, 9.2, 140), (12.4, 4.6, 20)):
        p.model("can_rusted", (x, 0, z), pitch=90, yaw=yaw, visibility_end=25.0)
    # meter room (inner faces x 26.1 / 29.9, z -5.9 / -2.1; door in the x=26 wall at z -4)
    p.model("utility_box_01", (27.1, 0.05, -5.62), yaw=180, collide=(0.52, 1.12, 0.43), surface="metal")
    p.model("power_box_01", (26.1, 1.6, -2.75), yaw=-90)
    p.model("utility_box_02", (30.35, 0, -4.4), yaw=-90, collide=(0.92, 1.12, 0.43), surface="metal")
    # CCTV camera bodies, a little behind each feed's lens (the gate one on its own pole)
    lv.box((0, 1.55, 21.78), (0.08, 3.1, 0.08), "metal_gate_green", collide=False)
    lv.box((0, 3.1, 21.83), (0.06, 0.06, 0.18), "metal_gate_green", collide=False)
    for name, pos, rot in (("Gate", (0, 3.0, 22), (-12, 180)), ("StairsB", (-12.5, 2.6, -12.0), (-12, 0)),
                           ("MeterRoom", (29.55, 2.6, -5.55), (-28, 137.7))):
        pitch, yaw = rot
        back = (math.sin(math.radians(yaw)) * math.cos(math.radians(pitch)), -math.sin(math.radians(pitch)),
                math.cos(math.radians(yaw)) * math.cos(math.radians(pitch)))
        at = tuple(pos[i] + back[i] * 0.12 for i in range(3))
        p.model("security_camera_01", at, yaw=yaw, pitch=-pitch, node_name=f"CCTVCam{name}",
                render_layers=1 << 18)


def dress_cabin(lv: Level) -> None:
    """A watchman's cabin someone has lived nights in (1998). Inner faces x 4.1 / 7.4,
    z 22.1 / 25.4, floor y 0.05, table top y 0.76. Door hole in the x=4 wall, z 22.5..23.5."""
    p = Props(lv)
    f = 0.05
    p.tiffin((5.98, 0.76, 25.1))
    p.tumbler((6.62, 0.76, 24.72))
    p.model("vintage_flashlight", (6.95, 0.76, 24.68), yaw=95)
    p.model("cigarette_pack", (6.52, 0.76, 25.02), yaw=25)
    # outside the cabin door: a bulkhead porch light (dies in the power cut), two money plants
    p.model("security_light", (3.9, 2.35, 23.0), yaw=90, node_name="PorchLightBody")
    lv.add("PorchLight", "OmniLight3D", ".", {"position": v3(3.62, 2.2, 23.0), "light_color": "Color(1, 0.86, 0.62, 1)",
           "light_energy": "1.3", "omni_range": "9.0", "omni_attenuation": "1.3", "shadow_enabled": "true",
           "light_volumetric_fog_energy": "1.5"}, groups=["mains"])
    p.cyl((3.68, 2.2, 23.0), 0.035, 0.035, 0.07, "bulb_warm", seg=10, shadow=False)
    for z in (22.15, 23.85):
        p.model("planter_pot_clay", (3.65, 0, z), yaw=z * 40)
    # wear
    for name, pos, rot in (("hand_grime", (4.11, 1.2, 23.65), (0, 90, 0)), ("crack_a", (7.39, 2.1, 22.6), (0, -90, 0)),
                           ("water_stain", (6.9, 2.595, 22.6), (90, 0, 0)), ("paan_b", (3.89, 0.3, 24.4), (0, -90, 0))):
        lv.scene(name, f"res://scenes/decals/{name}.tscn", ".", {"position": v3(*pos), "rotation_degrees": v3(*rot)})
    p.radio((6.66, 0.76, 25.18), yaw=180)
    p.model("plastic_monobloc_chair_01", (6.55, f, 24.12), yaw=172, collide=(0.6, 0.5, 0.6), surface="soft")
    p.matka((4.38, f, 25.1))
    p.model("metal_jug", (4.7, f, 25.18), yaw=30)
    p.lathi((7.28, f, 22.3), lean_yaw=-90)
    p.newspaper_stack((6.95, f, 24.95), yaw=-6, n=6)
    p.mosquito_coil((4.7, f, 24.0))
    p.chappals((4.4, f, 24.25), yaw=80)
    p.model("wall_clock", (5.75, 2.3, 22.1), yaw=180, script="res://scripts/props/wall_clock.gd")
    lv.scene("CabinCalendar", "res://scenes/decals/ganesh.tscn", ".", {"position": v3(4.65, 1.55, 25.4), "rotation_degrees": v3(0, 180, 0)})
    p.notices((7.4, 1.5, 24.1), yaw=90)
    p.hooks_with_bag((4.62, 1.8, 22.1), yaw=180)
    p.switchboard((4.1, 1.3, 23.85), yaw=-90, n=2)
    p.wire((4.11, 1.37, 23.85), (4.11, 2.58, 23.85))
    p.wire((4.11, 2.585, 23.85), (5.2, 2.585, 23.75))


if __name__ == "__main__":
    main()
