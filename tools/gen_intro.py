"""Builds chapters/intro/intro.tscn: Sunday flea market at dusk + Nikhil's room (for the
"that night" shot), camera shot markers, VCR blue-screen UI. Driven by
chapters/intro/scripts/intro_director.gd.  Run: python tools/gen_intro.py
"""
import os
import random
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from levelkit import ROOT, Level, v3, wall  # noqa: E402

GOODS = ["cardboard", "glass_dark", "fabric_sheet", "fabric_curtain", "wood_door_dark", "metal_rust", "paper"]


def stall(lv, x, z, side, rng, tarp, vendor=False):
    lv.box((x, 0.37, z), (1.0, 0.74, 2.2), "wood_planks")
    for dz in (-1.1, 1.1):
        for dx in (-0.5, 0.5):
            lv.box((x + dx, 1.1, z + dz), (0.05, 2.2, 0.05), "metal_rust", collide=False)
    lv.box((x - side * 0.1, 2.25, z), (1.6, 0.03, 2.6), tarp, collide=False)
    if not vendor:
        for i in range(rng.randint(4, 8)):
            sx, sy, sz = rng.uniform(0.12, 0.35), rng.uniform(0.05, 0.3), rng.uniform(0.12, 0.35)
            lv.box((x + rng.uniform(-0.3, 0.3), 0.74 + sy / 2, z + rng.uniform(-0.9, 0.9)), (sx, sy, sz), rng.choice(GOODS), collide=False)
    bulb = lv.add("Bulb", "OmniLight3D", ".", {"position": v3(x, 2.0, z), "light_color": "Color(1, 0.72, 0.4, 1)",
                                              "light_energy": "0.9", "omni_range": "4.5", "light_volumetric_fog_energy": "1.5"})
    lv.box((x, 2.08, z), (0.06, 0.08, 0.06), "glass_lit_warm", collide=False, shadow=False)


def main() -> None:
    rng = random.Random(1998)
    lv = Level("Intro", "res://chapters/intro/scripts/intro_director.gd")
    sky_mat = lv.sub("ShaderMaterial", {"shader": f'ExtResource("{lv.ext("res://assets/shaders/sky_city_night.gdshader", "Shader")}")',
                                        "shader_parameter/zenith_color": "Color(0.08, 0.09, 0.17, 1)",
                                        "shader_parameter/horizon_color": "Color(0.62, 0.33, 0.15, 1)",
                                        "shader_parameter/glow_height": "0.3", "shader_parameter/star_density": "0.0"})
    sky = lv.sub("Sky", {"sky_material": f'SubResource("{sky_mat}")'})
    env = lv.sub("Environment", {"background_mode": "2", "sky": f'SubResource("{sky}")', "ambient_light_source": "2",
                                 "ambient_light_color": "Color(0.6, 0.45, 0.4, 1)", "ambient_light_energy": "0.35", "tonemap_mode": "4", "tonemap_exposure": "1.1",
                                 "ssao_enabled": "true", "glow_enabled": "true", "glow_intensity": "0.6",
                                 "volumetric_fog_enabled": "true", "volumetric_fog_density": "0.02",
                                 "volumetric_fog_albedo": "Color(1, 0.85, 0.7, 1)"})
    lv.add("WorldEnvironment", "WorldEnvironment", ".", {"environment": f'SubResource("{env}")'})
    lv.add("DuskSun", "DirectionalLight3D", ".", {"rotation_degrees": v3(-8, -70, 0), "light_color": "Color(1, 0.55, 0.3, 1)",
                                                 "light_energy": "0.35", "shadow_enabled": "true"})
    # ground + lane
    lv.box((0, -0.1, -12), (24, 0.2, 40), "ground_dirt")
    lv.box((0, -0.095, -12), (3.2, 0.2, 40), "ground_asphalt", collide=False)
    # buildings either side
    for side, mat in ((-1, "wall_exterior_peach"), (1, "wall_exterior_sky")):
        x = side * 8.0
        for fl in range(3):
            ops = [{"along": z, "w": 1.2, "bottom": 0.9, "top": 2.1, "kind": "window",
                    "glass": "glass_lit_warm" if rng.random() < 0.2 else "glass_dark"} for z in range(-28, 6, 5)]
            wall(lv, (x, -30), (x, 6), fl * 3.0, 3.0, 0.23, mat, "wall_paint_white", side, ops, collide=False)
    # the far end of the lane: another building closes the view
    for fl in range(3):
        ops = [{"along": x, "w": 1.2, "bottom": 0.9, "top": 2.1, "kind": "window",
                "glass": "glass_lit_warm" if (x + fl) % 3 == 0 else "glass_dark"} for x in (-6, -2, 2, 6)]
        wall(lv, (-8, -31), (8, -31), fl * 3.0, 3.0, 0.23, "wall_exterior_cream", "wall_paint_white", +1, ops, collide=False)
    # stalls
    tarps = ["fabric_curtain", "fabric_sheet", "cardboard"]
    for i in range(5):
        stall(lv, -3.4, -3 - i * 5, -1, rng, tarps[i % 3])
        stall(lv, 3.4, -3 - i * 5, 1, rng, tarps[(i + 1) % 3], vendor=(i == 4))
    # the vendor (face turned away from the lane) and the box of tapes
    lv.box((4.3, 0.22, -25.4), (0.35, 0.44, 0.35), "wood_planks")
    vendor = lv.add("Vendor", "Node3D", ".", {"position": v3(4.3, 0, -25.4), "rotation_degrees": v3(0, 120, 0)})
    shawl = lv.sub("CapsuleMesh", {"radius": "0.24", "height": "0.95"})
    head = lv.sub("SphereMesh", {"radius": "0.11", "height": "0.24"})
    lv.add("Body", "MeshInstance3D", vendor, {"position": v3(0, 0.92, 0), "mesh": f'SubResource("{shawl}")', "material_override": lv.mat("wood_door_dark")})
    lv.add("Head", "MeshInstance3D", vendor, {"position": v3(0, 1.5, 0.04), "mesh": f'SubResource("{head}")', "material_override": lv.mat("fabric_curtain")})
    for x, z, sx, sz in ((2.85, -25.0, 0.02, 0.34), (3.31, -25.0, 0.02, 0.34), (3.08, -25.16, 0.48, 0.02), (3.08, -24.84, 0.48, 0.02)):
        lv.box((x, 0.88, z), (sx, 0.26, sz), "cardboard", collide=False)
    for i in range(4):
        lv.box((3.08, 0.84, -25.12 + i * 0.07), (0.19, 0.1, 0.025), "glass_dark", collide=False)
    # Nikhil's room, far away, for the "that night" shot
    home = lv.add("Home", "Node3D", ".", {"position": v3(100, 0, 0)})
    lv.scene("Room", "res://chapters/hub/nikhil_room.tscn", home)
    thud = lv.ext("res://assets/audio/sfx/vcr_click.wav", "AudioStream")
    lv.add("Thud", "AudioStreamPlayer3D", home, {"position": v3(1.75, 0.2, 3.75), "stream": f'ExtResource("{thud}")', "bus": '&"SFX"'})
    # camera + shots
    lv.add("Camera3D", "Camera3D", ".", {"fov": "70.0", "current": "true"})
    lv.add("Shots", "Node3D", ".")
    shots = {"M0": (0, 1.6, 4), "M1": (0, 1.6, -6), "M2": (-0.5, 1.6, -13), "M3": (0.6, 1.6, -20),
             "M4": (1.5, 1.55, -23.7), "M5": (1.8, 1.45, -24.4),
             "L0": (0, 1.4, -20), "L1": (-3.2, 1.0, -10), "L2": (3.2, 1.0, -18), "L3": (3.0, 1.0, -24.5),
             "L4": (4.2, 1.3, -25.5), "L5": (3.08, 0.8, -25.0),
             "H0": (100.75, 1.6, 3.7), "H1": (101.3, 1.45, 3.0), "HL0": (102.2, 0.6, 3.6), "HL1": (101.75, 0.15, 3.75)}
    for name, pos in shots.items():
        lv.add(name, "Marker3D", "Shots", {"position": v3(*pos)})
    # VHS look (OSD hidden by the director), subtitles, UI overlays
    lv.scene("Camcorder", "res://ui/hud/camcorder.tscn", ".")
    lv.scene("Subtitles", "res://ui/hud/subtitles.tscn", ".")
    font = lv.sub("SystemFont", {"font_names": 'PackedStringArray("VCR OSD Mono", "Consolas", "Courier New")', "font_weight": "700"})
    lv.add("UI", "CanvasLayer", ".", {"layer": "50"})
    full = {"anchors_preset": "15", "anchor_right": "1.0", "anchor_bottom": "1.0", "grow_horizontal": "2", "grow_vertical": "2", "mouse_filter": "2"}
    lv.add("Fade", "ColorRect", "UI", {**full, "color": "Color(0, 0, 0, 0)"})
    lv.add("Blue", "ColorRect", "UI", {**full, "color": "Color(0.03, 0.08, 0.62, 1)"})
    lv.add("Play", "Label", "UI/Blue", {"offset_left": "74.0", "offset_top": "48.0", "offset_right": "500.0", "offset_bottom": "90.0",
                                         "theme_override_fonts/font": f'SubResource("{font}")', "theme_override_font_sizes/font_size": "34",
                                         "text": '"PLAY ►"'})
    lv.add("Card", "Label", "UI", {**full, "theme_override_fonts/font": f'SubResource("{font}")',
                                    "theme_override_font_sizes/font_size": "40", "horizontal_alignment": "1",
                                    "vertical_alignment": "1", "text": '"THAT NIGHT"'})
    lv.add("Skip", "Label", "UI", {"anchors_preset": "3", "anchor_left": "1.0", "anchor_top": "1.0", "anchor_right": "1.0",
                                    "anchor_bottom": "1.0", "offset_left": "-330.0", "offset_top": "-60.0", "offset_right": "-40.0",
                                    "offset_bottom": "-30.0", "grow_horizontal": "0", "grow_vertical": "0",
                                    "theme_override_fonts/font": f'SubResource("{font}")', "theme_override_font_sizes/font_size": "18",
                                    "horizontal_alignment": "2", "text": '"Hold [Space] to skip"'})
    lv.write(os.path.join(ROOT, "chapters", "intro", "intro.tscn"))


if __name__ == "__main__":
    main()
