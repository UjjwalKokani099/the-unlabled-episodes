"""Builds tests/scenes/material_gallery.tscn: a 20 x 12 m room showing every material in
assets/materials (labelled panels and floor strips) plus the decals, lit by tube lights and
a sodium lamp. Re-run after adding materials:  python tools/gen_material_gallery.py
"""
import os

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "tests", "scenes", "material_gallery.tscn")

W, D, H = 20.0, 12.0, 3.0  # room width (x), depth (z), height
BACK = ["wall_paint_cream", "wall_paint_mint", "wall_paint_sky", "wall_paint_peach", "wall_paint_white",
        "wall_exterior_cream", "wall_exterior_peach", "wall_exterior_sky", "wall_stairwell_mint", "wall_stairwell_cream"]
LEFT = ["wall_peeling", "wall_peeling_heavy", "wall_damp_green", "wall_yellow_peeling", "wall_bare_stained", "brick_red"]
RIGHT = ["concrete_rough", "concrete_dirty", "concrete_dark", "metal_gate_green", "metal_meter_white", "metal_rust"]
FRONT = ["wood_door_dark", "wood_door_varnished", "wood_frame_blue", "wood_planks", "metal_corrugated",
         "tile_white", "paper", "wall_paint_white", "wall_paint_white", "wall_paint_white"]
FLOORS = ["floor_mosaic", "floor_kota", "tile_white", "tile_checker", "tile_polished"]
GROUNDS = ["ground_pavers", "ground_asphalt", "ground_dirt", "concrete_dark", "concrete_rough"]
DECALS = [  # name, position on the centre wall's front face (x, y)
    ("notice_water", -2.3, 1.55), ("tuition", -1.5, 1.45), ("ganesh", -0.6, 1.6),
    ("lost_dog", 0.3, 1.45), ("room_rent", 1.1, 1.5), ("stencil_no_bills", -0.2, 2.45),
    ("crack_a", 2.1, 1.7), ("hand_grime", 2.6, 1.15), ("paan_a", 2.5, 0.35),
]

ext = {}      # path -> id
subs = []     # sub-resource text blocks
nodes = []    # node text blocks


def res(path: str, kind: str) -> str:
    if path not in ext:
        ext[path] = (kind, f"{len(ext) + 1}_r")
    return ext[path][1]


def mat(name: str) -> str:
    return res(f"res://assets/materials/{name}.tres", "Material")


box_ids = {}


def box_mesh(size) -> str:
    key = tuple(round(v, 3) for v in size)
    if key not in box_ids:
        bid = f"Box_{len(box_ids)}"
        box_ids[key] = bid
        subs.append(f'[sub_resource type="BoxMesh" id="{bid}"]\nsize = Vector3({key[0]}, {key[1]}, {key[2]})\nadd_uv2 = true\n')
    return box_ids[key]


def node(name, typ, parent, props=None, instance=None):
    head = f'[node name="{name}"'
    head += f' type="{typ}"' if typ else ""
    head += f' parent="{parent}"' if parent is not None else ""
    head += f' instance=ExtResource("{instance}")' if instance else ""
    lines = [head + "]"]
    for k, v in (props or {}).items():
        lines.append(f"{k} = {v}")
    nodes.append("\n".join(lines) + "\n")


def v3(x, y, z):
    return f"Vector3({x}, {y}, {z})"


def panel(parent, name, material, pos, size, label_pos=None, label_rot=None):
    node(name, "MeshInstance3D", parent, {
        "position": v3(*pos), "mesh": f'SubResource("{box_mesh(size)}")',
        "material_override": f'ExtResource("{mat(material)}")'})
    if label_pos:
        props = {"position": v3(*label_pos), "pixel_size": "0.0035", "text": f'"{material}"',
                 "font_size": "40", "outline_size": "10", "modulate": "Color(1, 1, 0.85, 1)"}
        if label_rot:
            props["rotation_degrees"] = v3(*label_rot)
        node(name + "Label", "Label3D", parent, props)


def build() -> str:
    node("MaterialGallery", "Node3D", None)
    env_id = "Env"
    subs.append(f'''[sub_resource type="Environment" id="{env_id}"]
background_mode = 1
background_color = Color(0, 0, 0, 1)
ambient_light_source = 2
ambient_light_color = Color(0.55, 0.6, 0.7, 1)
ambient_light_energy = 0.08
tonemap_mode = 4
tonemap_exposure = 1.1
ssao_enabled = true
ssao_radius = 1.0
ssao_intensity = 2.0
ssil_enabled = true
ssil_radius = 3.0
ssil_intensity = 0.8
glow_enabled = true
glow_intensity = 0.6
glow_bloom = 0.03
glow_hdr_threshold = 0.9
volumetric_fog_enabled = false
metadata/authored_graphics = {{"ssao": true, "ssil": true, "volumetric_fog": true, "glow": true, "ssr": false}}
volumetric_fog_density = 0.015
volumetric_fog_length = 32.0
''')
    node("WorldEnvironment", "WorldEnvironment", ".", {"environment": f'SubResource("{env_id}")'})

    # Floors: front half = indoor floors, back half = outdoor grounds (strips 4 m wide).
    node("Floors", "Node3D", ".")
    for i, m in enumerate(FLOORS):
        x = -W / 2 + 2 + i * 4
        panel("Floors", f"F_{m}", m, (x, -0.05, 3.0), (4, 0.1, 6),
              label_pos=(x, 0.02, 0.4), label_rot=(-90, 0, 0))
    for i, m in enumerate(GROUNDS):
        x = -W / 2 + 2 + i * 4
        panel("Floors", f"G_{m}", m, (x, -0.05, -3.0), (4, 0.1, 6),
              label_pos=(x, 0.02, -0.4), label_rot=(-90, 0, 0))
    panel("Floors", "Ceiling", "wall_paint_white", (0, H + 0.05, 0), (W, 0.1, D))

    # Walls made of labelled 2 m panels.
    node("Walls", "Node3D", ".")
    for i, m in enumerate(BACK):
        x = -W / 2 + 1 + i * 2
        panel("Walls", f"B{i}_{m}", m, (x, H / 2, -D / 2 - 0.1), (2, H, 0.2), label_pos=(x, 2.75, -D / 2 + 0.01))
    for i, m in enumerate(FRONT):
        x = -W / 2 + 1 + i * 2
        panel("Walls", f"Fr{i}_{m}", m, (x, H / 2, D / 2 + 0.1), (2, H, 0.2),
              label_pos=(x, 2.75, D / 2 - 0.01), label_rot=(0, 180, 0))
    for i, m in enumerate(LEFT):
        z = -D / 2 + 1 + i * 2
        panel("Walls", f"L{i}_{m}", m, (-W / 2 - 0.1, H / 2, z), (0.2, H, 2),
              label_pos=(-W / 2 + 0.01, 2.75, z), label_rot=(0, 90, 0))
    for i, m in enumerate(RIGHT):
        z = -D / 2 + 1 + i * 2
        panel("Walls", f"R{i}_{m}", m, (W / 2 + 0.1, H / 2, z), (0.2, H, 2),
              label_pos=(W / 2 - 0.01, 2.75, z), label_rot=(0, -90, 0))

    # Free-standing decal wall (weathered exterior paint) in the middle.
    panel("Walls", "DecalWall", "wall_exterior_cream", (0, H / 2, 0.05), (6.4, H, 0.1))
    panel("Walls", "DecalWallBack", "tile_white", (0, H / 2, -0.05), (6.4, H, 0.1))
    node("Decals", "Node3D", ".")
    for name, x, y in DECALS:
        did = res(f"res://assets/decals/{name}.tscn", "PackedScene")
        node(name, None, "Decals", {"position": v3(x, y, 0.1)}, instance=did)
    # Water stain on the ceiling (decal faces down) and paan on the floor (faces up).
    node("water_stain", None, "Decals", {"position": v3(-4, H, 2), "rotation_degrees": v3(90, 0, 0)},
         instance=res("res://assets/decals/water_stain.tscn", "PackedScene"))
    node("paan_b", None, "Decals", {"position": v3(3.0, 0.0, 0.6), "rotation_degrees": v3(-90, 0, 0)},
         instance=res("res://assets/decals/paan_b.tscn", "PackedScene"))

    # Collision: floor, walls, centre wall.
    node("Collision", "StaticBody3D", ".")
    for i, (pos, size) in enumerate([((0, -0.05, 0), (W, 0.1, D)), ((0, H / 2, -D / 2 - 0.1), (W, H, 0.2)),
                                     ((0, H / 2, D / 2 + 0.1), (W, H, 0.2)), ((-W / 2 - 0.1, H / 2, 0), (0.2, H, D)),
                                     ((W / 2 + 0.1, H / 2, 0), (0.2, H, D)), ((0, H / 2, 0), (6.4, H, 0.2))]):
        sid = f"Shape_{i}"
        subs.append(f'[sub_resource type="BoxShape3D" id="{sid}"]\nsize = Vector3({size[0]}, {size[1]}, {size[2]})\n')
        node(f"Shape{i}", "CollisionShape3D", "Collision", {"position": v3(*pos), "shape": f'SubResource("{sid}")'})

    # Lights: tube lights (one flickering), a sodium lamp glow by the decal wall.
    tube = res("res://systems/props/tube_light.tscn", "PackedScene")
    for i, (x, z, flicker) in enumerate([(-6, 3, 0.0), (0, 3, 0.0), (6, 3, 0.6), (-6, -3, 0.0), (6, -3, 0.0)]):
        node(f"TubeLight{i}", None, ".", {"position": v3(x, H - 0.05, z), "flicker": str(flicker)}, instance=tube)
    node("SodiumLamp", "OmniLight3D", ".", {"position": v3(2.5, 2.6, 1.5), "light_color": "Color(1, 0.55, 0.18, 1)",
                                            "light_energy": "1.4", "omni_range": "5.0", "shadow_enabled": "true"})

    # Player, HUD, camcorder look, debug overlay, benchmark points.
    node("Player", None, ".", {"position": v3(0, 0, 4.5)}, instance=res("res://player/player.tscn", "PackedScene"))
    node("Camcorder", None, ".", instance=res("res://ui/hud/camcorder.tscn", "PackedScene"))
    node("HUD", None, ".", instance=res("res://ui/hud/hud.tscn", "PackedScene"))
    node("DebugOverlay", "CanvasLayer", ".", {"layer": "20", "script": f'ExtResource("{res("res://ui/hud/debug_overlay.gd", "Script")}")'})
    node("Label", "Label", "DebugOverlay", {"offset_left": "70.0", "offset_top": "96.0", "offset_right": "870.0", "offset_bottom": "260.0",
                                            "theme_override_colors/font_color": "Color(0.85, 0.85, 0.85, 1)",
                                            "theme_override_colors/font_outline_color": "Color(0, 0, 0, 1)",
                                            "theme_override_constants/outline_size": "4",
                                            "theme_override_font_sizes/font_size": "14"})
    node("BenchmarkPoints", "Node3D", ".")
    for i, p in enumerate([(0, 0, 4.5), (-6, 0, -3), (6, 0, 3)]):
        nodes.append(f'[node name="P{i}" type="Marker3D" parent="BenchmarkPoints" groups=["benchmark_points"]]\nposition = {v3(*p)}\n')

    header = ['[gd_scene format=3]', ""]
    for path, (kind, rid) in ext.items():
        header.append(f'[ext_resource type="{kind}" path="{path}" id="{rid}"]')
    return "\n".join(header) + "\n\n" + "\n".join(subs) + "\n" + "\n".join(nodes)


if __name__ == "__main__":
    with open(OUT, "w", encoding="utf-8", newline="\n") as f:
        f.write(build())
    print("wrote", OUT)
