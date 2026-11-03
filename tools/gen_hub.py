"""Builds scenes/hub/nikhil_room.tscn: Nikhil's rented single room (story bible), the
corridor outside his door, and the lane + building opposite seen through the window.
Used by the hub (scenes/hub/hub.tscn) and as the main-menu backdrop.
Run: python tools/gen_hub.py   (then: bake GI with tools/bake_voxelgi.gd)
Room: x 0..3.6, z 0..4.2, floor y 0, ceiling 2.9. Window (z=0) looks down at the lane (y -6).
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from levelkit import ROOT, Level, slab, sodium_lamp, v3, wall  # noqa: E402
from propkit import Props  # noqa: E402

GI_DATA = "res://scenes/hub/nikhil_room_gi.res"
H = 2.9


def interactable(lv, parent, name, pos, size, prompt, hold=0.0):
    path = lv.add(name, "Area3D", parent, {
        "position": v3(*pos), "script": f'ExtResource("{lv.ext("res://scripts/interaction/interactable.gd", "Script")}")',
        "prompt": f'"{prompt}"', "hold_time": str(hold)})
    shape = lv.sub("BoxShape3D", {"size": v3(*size)})
    lv.add("Shape", "CollisionShape3D", path, {"shape": f'SubResource("{shape}")'})
    return path


def main() -> None:
    lv = Level("NikhilRoom")
    sky_mat = lv.sub("ShaderMaterial", {"shader": f'ExtResource("{lv.ext("res://shaders/sky_city_night.gdshader", "Shader")}")'})
    sky = lv.sub("Sky", {"sky_material": f'SubResource("{sky_mat}")'})
    env = lv.sub("Environment", {
        "background_mode": "2", "sky": f'SubResource("{sky}")', "ambient_light_source": "2",
        "ambient_light_color": "Color(0.32, 0.36, 0.5, 1)", "ambient_light_energy": "0.035",
        "tonemap_mode": "4", "tonemap_exposure": "1.15", "ssao_enabled": "true", "ssao_radius": "0.8",
        "ssao_intensity": "2.0", "glow_enabled": "true", "glow_intensity": "0.6", "glow_bloom": "0.04",
        "glow_hdr_threshold": "0.9", "volumetric_fog_enabled": "true", "volumetric_fog_density": "0.035", "volumetric_fog_albedo": "Color(0.85, 0.8, 0.72, 1)",
        "volumetric_fog_length": "24.0"})
    lv.add("WorldEnvironment", "WorldEnvironment", ".", {"environment": f'SubResource("{env}")'})

    # ---- the room
    slab(lv, 0, 3.6, 0, 4.2, 0, 0.2, "tile_polished", "wall_paint_white")
    slab(lv, -0.12, 3.72, -0.12, 6.0, H + 0.2, 0.2, "concrete_dark", "wall_paint_white")
    window = {"along": 1.8, "w": 1.3, "bottom": 0.85, "top": 2.15, "kind": "vent", "frame": "wood_frame_blue"}
    wall(lv, (0, 0), (3.6, 0), 0, H, 0.23, "wall_exterior_peach", "wall_paint_mint", -1, [window])
    wall(lv, (0, 0), (0, 4.2), 0, H, 0.23, "wall_exterior_peach", "wall_paint_mint", -1)
    wall(lv, (3.6, 0), (3.6, 4.2), 0, H, 0.23, "wall_exterior_peach", "wall_paint_mint", +1)
    door_op = {"along": 0.75, "w": 1.2, "bottom": 0, "top": 2.2, "kind": "door", "frame": "wood_door_dark"}
    wall(lv, (0, 4.2), (3.6, 4.2), 0, H, 0.23, "wall_stairwell_cream", "wall_paint_mint", +1, [door_op])
    lv.scene("Door", "res://scenes/props/door.tscn", ".", {"position": v3(0.2, 0, 4.2)})
    # outer wall below the window down to the lane
    lv.box((1.8, -3.0, -0.06), (5.0, 6.0, 0.12), "wall_exterior_peach", collide=False)

    # ---- corridor outside the door (where the delivery bag appears)
    slab(lv, -0.12, 3.72, 4.32, 6.0, 0, 0.2, "floor_kota", "wall_paint_white")
    wall(lv, (-0.12, 4.2), (-0.12, 6.0), 0, H, 0.23, "wall_stairwell_cream", "wall_stairwell_cream", -1)
    wall(lv, (3.72, 4.2), (3.72, 6.0), 0, H, 0.23, "wall_stairwell_cream", "wall_stairwell_cream", +1)
    wall(lv, (-0.12, 6.0), (3.72, 6.0), 0, H, 0.23, "wall_stairwell_cream", "wall_stairwell_cream", +1)
    lv.add("CorridorBulb", "OmniLight3D", ".", {"position": v3(1.8, 2.6, 5.1), "light_color": "Color(1, 0.8, 0.55, 1)",
                                               "light_energy": "0.5", "omni_range": "4.0"})
    bag = lv.add("DeliveryBag", "Node3D", ".", {"position": v3(0.8, 0, 4.85)})
    lv.box((0, 0.2, 0), (0.38, 0.4, 0.3), "fabric_curtain", collide=False, parent=bag)
    lv.box((0, 0.42, 0), (0.3, 0.04, 0.2), "paper", collide=False, parent=bag)
    interactable(lv, bag, "Interactable", (0, 0.25, 0), (0.5, 0.6, 0.45), "Read the bill")

    # ---- furniture
    lv.box((0.55, 0.18, 1.35), (0.9, 0.36, 2.0), "wood_planks")                      # bed frame
    lv.box((0.55, 0.42, 1.35), (0.86, 0.14, 1.96), "fabric_sheet", collide=False)     # mattress + sheet
    lv.box((0.55, 0.53, 0.55), (0.6, 0.1, 0.35), "wall_paint_white", collide=False)   # pillow
    lv.box((3.2, 0.73, 1.8), (0.65, 0.04, 1.3), "wood_planks")                        # desk top
    for dz in (1.2, 2.4):
        lv.box((3.2, 0.36, dz), (0.6, 0.72, 0.04), "wood_planks", collide=False)
    lv.box((3.15, 0.765, 1.75), (0.34, 0.02, 0.24), "glass_dark", collide=False)      # laptop base
    lv.box((3.32, 0.88, 1.75), (0.02, 0.22, 0.34), "glass_lit_tv", collide=False, shadow=False)  # screen
    lv.add("LaptopGlow", "OmniLight3D", ".", {"position": v3(3.0, 0.95, 1.75), "light_color": "Color(0.55, 0.65, 1, 1)",
                                             "light_energy": "0.25", "omni_range": "1.6"})
    lv.box((3.45, 1.55, 1.8), (0.25, 0.03, 1.0), "wood_planks", collide=False)        # wall shelf
    for i, m in enumerate(("cardboard", "fabric_curtain", "fabric_sheet", "wood_door_dark")):
        lv.box((3.45, 1.66, 1.45 + i * 0.12), (0.18, 0.2, 0.06), m, collide=False)    # books
    lv.box((1.25, 1.5, 0.08), (0.06, 1.3, 0.04), "fabric_curtain", collide=False)     # curtain bunched left
    # steel trunk + CRT + VCR against the front wall, facing the bed (-Z)
    lv.box((2.85, 0.27, 3.75), (1.3, 0.54, 0.6), "metal_trunk_blue")
    lv.box((3.15, 0.78, 3.8), (0.56, 0.46, 0.46), "glass_dark")                       # CRT body (dark plastic)
    # ceiling tube light on the left wall
    lv.scene("TubeLight", "res://scenes/props/tube_light.tscn", ".", {"position": v3(1.6, H - 0.05, 0.9), "on": "false"})
    lv.scene("LightSwitch", "res://scenes/props/light_switch.tscn", ".", {
        "position": v3(1.55, 1.3, 4.072), "rotation_degrees": v3(0, 180, 0),
        "light_paths": 'Array[NodePath]([NodePath("../TubeLight")])', "is_on": "false"})
    # ceiling fan
    fan = lv.add("CeilingFan", "Node3D", ".", {"position": v3(1.8, H - 0.02, 2.1),
                                              "script": f'ExtResource("{lv.ext("res://scripts/props/ceiling_fan.gd", "Script")}")'})
    rod = lv.sub("CylinderMesh", {"top_radius": "0.02", "bottom_radius": "0.02", "height": "0.35", "radial_segments": "8"})
    lv.add("Rod", "MeshInstance3D", fan, {"position": v3(0, -0.17, 0), "mesh": f'SubResource("{rod}")', "material_override": lv.mat("metal_meter_white")})
    blades = lv.add("Blades", "Node3D", fan, {"position": v3(0, -0.36, 0)})
    hub_mesh = lv.sub("CylinderMesh", {"top_radius": "0.1", "bottom_radius": "0.12", "height": "0.08", "radial_segments": "12"})
    lv.add("Hub", "MeshInstance3D", blades, {"mesh": f'SubResource("{hub_mesh}")', "material_override": lv.mat("metal_meter_white")})
    blade = lv.sub("BoxMesh", {"size": v3(0.56, 0.008, 0.11)})
    for i in range(3):
        pivot = lv.add(f"Arm{i}", "Node3D", blades, {"rotation_degrees": v3(0, i * 120, 0)})
        lv.add("Blade", "MeshInstance3D", pivot, {"position": v3(0.38, 0, 0), "rotation_degrees": v3(6, 0, 0),
                                                  "mesh": f'SubResource("{blade}")', "material_override": lv.mat("metal_meter_white")})
    hum_stream = lv.ext("res://assets/audio/sfx/fan_hum.wav", "AudioStream")
    lv.add("Hum", "AudioStreamPlayer3D", fan, {"stream": f'ExtResource("{hum_stream}")', "volume_db": "-20.0",
                                              "unit_size": "2.0", "bus": '&"Ambience"'})

    # ---- TV (the hub CRT): screen faces -Z toward the bed
    tv = lv.add("TV", "Node3D", ".", {"script": f'ExtResource("{lv.ext("res://scripts/hub/tv.gd", "Script")}")'})
    screen_mat = lv.sub("ShaderMaterial", {"render_priority": "0", "shader": f'ExtResource("{lv.ext("res://shaders/tv_screen.gdshader", "Shader")}")'})
    quad = lv.sub("QuadMesh", {"material": f'SubResource("{screen_mat}")', "size": "Vector2(0.44, 0.33)"})
    lv.add("Screen", "MeshInstance3D", tv, {"position": v3(3.15, 0.8, 3.565), "rotation_degrees": v3(0, 180, 0), "mesh": f'SubResource("{quad}")'})
    font = lv.sub("SystemFont", {"font_names": 'PackedStringArray("VCR OSD Mono", "Consolas", "Courier New")', "font_weight": "600"})
    lv.add("ScreenText", "Label3D", tv, {"position": v3(3.15, 0.8, 3.56), "rotation_degrees": v3(0, 180, 0), "pixel_size": "0.001",
                                         "outline_size": "0", "font": f'SubResource("{font}")', "font_size": "48", "text": '""'})
    lv.add("Glow", "OmniLight3D", tv, {"position": v3(3.1, 0.9, 3.2), "light_color": "Color(0.75, 0.8, 0.95, 1)",
                                       "light_energy": "0.8", "shadow_enabled": "true", "omni_range": "4.0"})
    hiss = lv.ext("res://assets/audio/sfx/tv_static.wav", "AudioStream")
    lv.add("Hiss", "AudioStreamPlayer3D", tv, {"position": v3(3.15, 0.8, 3.6), "stream": f'ExtResource("{hiss}")',
                                               "volume_db": "-18.0", "unit_size": "2.5", "bus": '&"SFX"'})
    # ---- VCR beside the TV
    vcr = lv.add("VCR", "Node3D", ".", {"position": v3(2.45, 0.585, 3.75), "rotation_degrees": v3(0, 180, 0),
                                       "script": f'ExtResource("{lv.ext("res://scripts/hub/vcr.gd", "Script")}")'})
    vcr_body = lv.sub("BoxMesh", {"size": v3(0.43, 0.09, 0.3)})
    lv.add("Body", "MeshInstance3D", vcr, {"mesh": f'SubResource("{vcr_body}")', "material_override": lv.mat("glass_dark")})
    slot = lv.sub("BoxMesh", {"size": v3(0.24, 0.022, 0.01)})
    lv.add("Slot", "MeshInstance3D", vcr, {"position": v3(-0.04, 0.012, 0.152), "mesh": f'SubResource("{slot}")'})
    lv.add("Clock", "Label3D", vcr, {"position": v3(0.14, -0.012, 0.152), "pixel_size": "0.0006", "modulate": "Color(0.3, 1, 0.45, 1)",
                                     "outline_size": "0", "font": f'SubResource("{font}")', "font_size": "32", "text": '"12:00"'})
    clunk = lv.ext("res://assets/audio/sfx/vcr_insert.wav", "AudioStream")
    lv.add("InsertSound", "AudioStreamPlayer3D", vcr, {"stream": f'ExtResource("{clunk}")', "unit_size": "4.0", "bus": '&"SFX"'})
    interactable(lv, vcr, "Interactable", (0, 0, 0), (0.5, 0.2, 0.4), "VCR")

    # ---- cardboard box of tapes on the floor beside the trunk
    box = lv.add("TapeBox", "Node3D", ".", {"position": v3(1.75, 0, 3.75)})
    lv.box((0, 0.01, 0), (0.48, 0.02, 0.34), "cardboard", collide=False, parent=box)
    for x, z, sx, sz in ((-0.23, 0, 0.02, 0.34), (0.23, 0, 0.02, 0.34), (0, -0.16, 0.48, 0.02), (0, 0.16, 0.48, 0.02)):
        lv.box((x, 0.14, z), (sx, 0.26, sz), "cardboard", collide=False, parent=box)
    lv.add("Slots", "Node3D", box)
    interactable(lv, box, "Interactable", (0, 0.2, 0), (0.6, 0.45, 0.5), "Tapes")

    # ---- desk things: diary, dinner plate, phone (on the bed), charger socket
    diary = lv.add("Diary", "Node3D", ".", {"position": v3(3.25, 0.76, 2.3)})
    lv.box((0, 0.005, 0), (0.15, 0.025, 0.21), "wood_door_dark", collide=False, parent=diary)
    interactable(lv, diary, "Interactable", (0, 0.05, 0), (0.3, 0.2, 0.3), "Read your diary")
    plate = lv.add("Plate", "Node3D", ".", {"position": v3(3.2, 0.76, 1.3)})
    plate_mesh = lv.sub("CylinderMesh", {"top_radius": "0.12", "bottom_radius": "0.1", "height": "0.02", "radial_segments": "16"})
    lv.add("Mesh", "MeshInstance3D", plate, {"position": v3(0, 0.01, 0), "mesh": f'SubResource("{plate_mesh}")', "material_override": lv.mat("metal_meter_white")})
    food = lv.sub("CylinderMesh", {"top_radius": "0.08", "bottom_radius": "0.09", "height": "0.03", "radial_segments": "12"})
    lv.add("Food", "MeshInstance3D", plate, {"position": v3(0, 0.03, 0), "mesh": f'SubResource("{food}")', "material_override": lv.mat("fabric_curtain")})
    interactable(lv, plate, "Interactable", (0, 0.05, 0), (0.3, 0.2, 0.3), "Eat dinner")
    phone = lv.add("Phone", "Node3D", ".", {"position": v3(0.75, 0.5, 2.0)})
    phone_mesh = lv.sub("BoxMesh", {"size": v3(0.075, 0.01, 0.155)})
    lv.add("Mesh", "MeshInstance3D", phone, {"mesh": f'SubResource("{phone_mesh}")', "material_override": lv.mat("glass_dark")})
    interactable(lv, phone, "Interactable", (0, 0.05, 0), (0.25, 0.15, 0.3), "Read messages")
    charger = lv.add("Charger", "Node3D", ".", {"position": v3(3.56, 0.95, 2.6)})
    socket = lv.sub("BoxMesh", {"size": v3(0.02, 0.1, 0.16)})
    lv.add("Mesh", "MeshInstance3D", charger, {"mesh": f'SubResource("{socket}")', "material_override": lv.mat("wall_paint_white")})
    interactable(lv, charger, "Interactable", (-0.1, 0, 0), (0.25, 0.3, 0.3), "Charge your phone")
    lv.add("ChargingSpot", "Marker3D", ".", {"position": v3(3.35, 0.76, 2.65)})

    dress_room(lv)

    # ---- outside: lane below, building opposite, street lamp, the van spot
    lv.box((1.8, -6.1, -6.0), (40, 0.2, 14), "ground_asphalt")
    opp = []
    for i, x in enumerate((-6.5, -2.5, 1.5, 5.5, 9.5)):
        g = "glass_lit_warm" if i in (1, 4) else ("glass_lit_tv" if i == 3 else "glass_dark")
        opp.append({"along": x, "w": 1.2, "bottom": 0.9, "top": 2.1, "kind": "window", "glass": g})
    for fl in range(4):
        ops = [dict(o, glass=(o["glass"] if fl == 2 else "glass_dark")) for o in opp]
        wall(lv, (-9, -11), (13, -11), -6 + fl * 3, 3, 0.23, "wall_exterior_sky", "wall_paint_white", +1, ops, collide=False)
    sodium_lamp(lv, 6.0, -8.5, height=5.5, facing_x=-1.0)
    van = lv.add("Van", "Node3D", ".", {"position": v3(-1.0, -6.0, -6.5),
                                       "script": f'ExtResource("{lv.ext("res://scripts/props/vanish_when_unseen.gd", "Script")}")'})
    white = lv.sub("StandardMaterial3D", {"albedo_color": "Color(0.82, 0.82, 0.8, 1)", "roughness": "0.45", "metallic": "0.3"})
    head = lv.sub("StandardMaterial3D", {"albedo_color": "Color(1, 0.95, 0.8, 1)", "emission_enabled": "true",
                                         "emission": "Color(1, 0.92, 0.75, 1)", "emission_energy_multiplier": "4.0"})
    tail = lv.sub("StandardMaterial3D", {"albedo_color": "Color(0.8, 0.05, 0.03, 1)", "emission_enabled": "true",
                                         "emission": "Color(1, 0.04, 0.02, 1)", "emission_energy_multiplier": "3.0"})
    for nm, pos, size, m in (("Body", (0, 0.95, 0), (3.4, 1.35, 1.45), f'SubResource("{white}")'),
                             ("Glass", (0.05, 1.35, 0), (3.0, 0.45, 1.47), lv.mat("glass_dark")),
                             ("HeadL", (1.71, 0.7, 0.5), (0.02, 0.14, 0.18), f'SubResource("{head}")'),
                             ("HeadR", (1.71, 0.7, -0.5), (0.02, 0.14, 0.18), f'SubResource("{head}")'),
                             ("TailL", (-1.71, 0.75, 0.6), (0.02, 0.18, 0.1), f'SubResource("{tail}")'),
                             ("TailR", (-1.71, 0.75, -0.6), (0.02, 0.18, 0.1), f'SubResource("{tail}")')):
        mesh = lv.sub("BoxMesh", {"size": v3(*size)})
        lv.add(nm, "MeshInstance3D", van, {"position": v3(*pos), "mesh": f'SubResource("{mesh}")', "material_override": m})
    wheel = lv.sub("CylinderMesh", {"top_radius": "0.3", "bottom_radius": "0.3", "height": "0.2", "radial_segments": "12"})
    for i, (x, z) in enumerate(((1.1, 0.7), (1.1, -0.7), (-1.1, 0.7), (-1.1, -0.7))):
        lv.add(f"Wheel{i}", "MeshInstance3D", van, {"position": v3(x, 0.3, z), "rotation_degrees": v3(90, 0, 0),
                                                    "mesh": f'SubResource("{wheel}")', "material_override": lv.mat("glass_dark")})
    lv.add("Headlights", "SpotLight3D", van, {"position": v3(1.8, 0.7, 0), "rotation_degrees": v3(0, -90, 0),
                                              "light_color": "Color(1, 0.92, 0.75, 1)", "light_energy": "3.0",
                                              "spot_range": "14.0", "spot_angle": "35.0", "light_volumetric_fog_energy": "2.0"})
    lv.add("Notifier", "VisibleOnScreenNotifier3D", van, {"aabb": "AABB(-1.8, 0, -0.8, 3.6, 1.8, 1.6)"})

    # ---- GI for the room (baked by tools/bake_voxelgi.gd)
    gi = {"position": v3(1.8, 1.45, 2.4), "size": v3(4.2, 3.2, 5.6), "subdiv": "1"}
    if os.path.exists(os.path.join(ROOT, GI_DATA[6:])):
        gi["data"] = f'ExtResource("{lv.ext(GI_DATA, "VoxelGIData")}")'
    lv.add("VoxelGI", "VoxelGI", ".", gi)
    lv.write(os.path.join(ROOT, "scenes", "hub", "nikhil_room.tscn"))


def dress_room(lv: Level) -> None:
    """Lived-in clutter + the practical lights the room is really lit by at night.
    Inner wall faces: x 0.115 / 3.485, z 0.115 / 4.085. Desk top y 0.75, mattress top 0.49."""
    p = Props(lv)
    # desk: lamp (the main light), water, tumbler, pens, extension board under the desk
    lamp = p.desk_lamp((3.36, 0.75, 2.06))
    lv.add("DeskLamp", "OmniLight3D", ".", {"position": v3(lamp[0] - 0.05, lamp[1] + 0.02, lamp[2]),
        "light_color": "Color(1, 0.72, 0.42, 1)", "light_energy": "1.6", "light_size": "0.08",
        "shadow_enabled": "true", "omni_range": "5.0", "omni_attenuation": "1.6",
        "light_volumetric_fog_energy": "1.5"})
    p.tumbler((2.98, 0.75, 1.42))
    p.bottle((3.4, 0.75, 1.24))
    p.pen_stand((3.02, 0.75, 2.36))
    p.books((3.4, 0.75, 2.36), yaw=8, n=3)
    p.plastic_chair((2.45, 0, 1.85), yaw=-90)
    p.extension_board((3.3, 0, 1.45), yaw=90)
    p.wire((3.3, 0.02, 1.6), (3.47, 0.02, 2.6))
    p.wire((3.475, 0.02, 2.6), (3.475, 0.9, 2.6))
    p.newspaper_stack((3.15, 0, 2.15), yaw=4)
    # bed: folded blanket at the foot, a second pillow, phone charger cable
    lv.box((0.55, 0.545, 2.08), (0.78, 0.11, 0.38), "fabric_curtain", collide=False)
    p.box((0.55, 0.6, 2.08), (0.78, 0.01, 0.38), "blanket", shadow=False)
    p.box((0.62, 0.56, 0.75), (0.5, 0.09, 0.3), "cloth_check", rot=(0, 12, 0))
    p.mosquito_coil((1.2, 0, 0.9))
    # corners: steel almirah (front right), water can, broom, slippers
    p.steel_almirah((3.02, 0, 0.38), yaw=180, w=0.82, h=1.75, d=0.5)
    p.water_can((3.3, 0, 0.82))
    p.broom((0.2, 0, 2.75), lean_yaw=90)
    p.doormat((0.75, 0, 3.85))
    p.chappals((1.0, 0, 3.9), yaw=170)
    # clothesline across the corner over the bed's head end
    p.clothesline((0.12, 2.12, 1.75), (1.05, 2.12, 0.12), [
        (0.2, "shirt", "cloth_check"), (0.45, "towel", "cloth_towel"), (0.75, "trousers", "cloth_grey")])
    # walls: clock over the window, calendar between desk and TV, mirror + hooks by the door
    p.wall_clock((1.8, 2.55, 0.115), yaw=180)
    p.calendar((3.485, 1.65, 3.05), yaw=90)
    p.mirror((0.115, 1.55, 3.35), yaw=-90)
    p.hooks_with_bag((2.0, 1.8, 4.085))
    p.switchboard((1.78, 1.3, 4.085), n=3)
    p.wire((1.55, 1.37, 4.075), (1.55, 2.86, 4.075))
    p.wire((1.55, 2.875, 4.075), (1.6, 2.875, 0.95))
    # curtain rod over the window
    p.cyl((1.8, 2.22, 0.15), 0.012, 0.012, 1.7, "steel", rot=(0, 0, 90), seg=6)
    # corridor: shared-bathroom bucket, shoes outside the door
    p.bucket_and_mug((3.3, 0, 5.6))
    p.chappals((1.6, 0, 4.55), yaw=10, mat="cloth_maroon")
    p.newspaper_stack((3.35, 0, 4.6), n=4)


if __name__ == "__main__":
    main()
