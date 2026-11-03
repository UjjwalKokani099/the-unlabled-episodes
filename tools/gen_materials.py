"""Writes the material library: assets/materials/<name>.tres (ShaderMaterials using
assets/shaders/surfaces/surface.gdshader). THIS TABLE IS THE SOURCE OF TRUTH: tweak a line and
re-run `python tools/gen_materials.py` (don't hand-edit the .tres files).

tile = metres one texture repeat covers. Colours are linear-ish RGB 0..1.
"""
import os

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "assets", "materials")
SHADER = "res://assets/shaders/surfaces/surface.gdshader"
LEAKS = "res://assets/materials/textures/overlay_leaks_a/overlay_leaks_a_mask.jpg"
LEAKS_B = "res://assets/materials/textures/overlay_leaks_b/overlay_leaks_b_mask.jpg"

CREAM = (0.96, 0.89, 0.72)
MINT = (0.76, 0.89, 0.8)
SKY = (0.74, 0.85, 0.94)
PEACH = (0.97, 0.8, 0.66)
WHITE = (0.92, 0.92, 0.89)
DADO_GREEN = (0.36, 0.5, 0.42)
DADO_BROWN = (0.42, 0.3, 0.22)

WEATHERED = {"damp_height": 0.6, "damp_strength": 0.65, "damp_storeys": 1, "leak": LEAKS, "leak_strength": 0.55, "top_grime": 0.3, "macro_strength": 0.45}
INDOOR_WORN = {"damp_height": 0.35, "damp_strength": 0.35, "top_grime": 0.2, "macro_strength": 0.3}

# name: (texture set, tile metres, extra params)
MATERIALS = {
    # --- Painted plaster walls (tinted) ---
    "wall_paint_cream": ("plaster_painted", 2.0, {"tint": CREAM}),
    "wall_paint_mint": ("plaster_painted", 2.0, {"tint": MINT}),
    "wall_paint_sky": ("plaster_painted", 2.0, {"tint": SKY}),
    "wall_paint_peach": ("plaster_painted", 2.0, {"tint": PEACH}),
    "wall_paint_white": ("plaster_painted", 2.0, {"tint": WHITE}),
    # Exterior: monsoon-weathered (rising damp, rain streaks, grime under slabs)
    "wall_exterior_cream": ("plaster_painted", 2.0, {"tint": CREAM, **WEATHERED}),
    "wall_exterior_peach": ("plaster_painted", 2.0, {"tint": PEACH, **WEATHERED, "leak": LEAKS_B}),
    "wall_exterior_sky": ("plaster_painted", 2.0, {"tint": SKY, **WEATHERED}),
    # Stairwells / corridors: two-tone dado, worn
    "wall_stairwell_mint": ("plaster_painted", 2.0, {"tint": MINT, "dado_height": 1.2, "dado_tint": DADO_GREEN, **INDOOR_WORN}),
    "wall_stairwell_cream": ("plaster_painted", 2.0, {"tint": CREAM, "dado_height": 1.2, "dado_tint": DADO_BROWN, **INDOOR_WORN}),
    # Damaged walls
    "wall_peeling": ("plaster_peeling", 2.0, {"damp_height": 0.5, "damp_strength": 0.4, "macro_strength": 0.2}),
    "wall_peeling_heavy": ("plaster_peeling_heavy", 2.0, {"macro_strength": 0.2}),
    "wall_damp_green": ("plaster_damp", 2.0, {"leak": LEAKS, "leak_strength": 0.3, "macro_strength": 0.3}),
    "wall_yellow_peeling": ("plaster_yellow_peeling", 2.0, {"damp_height": 0.5, "damp_strength": 0.5, "macro_strength": 0.25, "roughness_offset": 0.25}),
    "wall_bare_stained": ("plaster_bare", 2.0, {"damp_height": 0.5, "damp_strength": 0.5, "leak": LEAKS_B, "leak_strength": 0.4}),
    # --- Concrete and brick ---
    "concrete_rough": ("concrete_rough", 2.0, {"macro_strength": 0.35}),
    "concrete_dirty": ("concrete_dirty", 3.0, {"damp_height": 0.5, "damp_storeys": 1, "leak": LEAKS, "leak_strength": 0.5, "macro_strength": 0.4}),
    "concrete_dark": ("concrete_dark", 3.0, {"macro_strength": 0.45}),
    "brick_red": ("brick_red", 1.5, {"macro_strength": 0.3, "damp_height": 0.4, "damp_strength": 0.5, "damp_storeys": 1}),
    # --- Floors ---
    "floor_mosaic": ("floor_mosaic", 1.2, {"roughness_offset": -0.25, "macro_strength": 0.25}),
    "floor_kota": ("floor_kota", 1.2, {"tint": (0.88, 0.97, 0.93), "roughness_offset": 0.05, "macro_strength": 0.3}),
    "tile_white": ("tile_white", 0.6, {"macro_strength": 0.15}),
    "tile_checker": ("tile_checker", 0.8, {"roughness_offset": 0.08, "macro_strength": 0.25}),
    "tile_polished": ("tile_polished", 1.2, {"roughness_offset": -0.15, "macro_strength": 0.2}),
    "ground_pavers": ("ground_pavers", 1.6, {"macro_strength": 0.45}),
    "ground_asphalt": ("ground_asphalt", 4.0, {"macro_strength": 0.5}),
    "ground_dirt": ("ground_dirt", 3.0, {"macro_strength": 0.4}),
    # --- Metal ---
    "metal_gate_green": ("metal_painted_green", 1.0, {"metallic": True, "roughness_offset": 0.15}),
    "metal_meter_white": ("metal_painted_white", 1.0, {"metallic": True}),
    "metal_rust": ("metal_rust", 1.0, {"macro_strength": 0.2}),
    "metal_corrugated": ("metal_corrugated", 1.5, {"metallic": True, "macro_strength": 0.35}),
    # --- Wood ---
    "wood_door_dark": ("wood_painted_dark", 1.5, {"macro_strength": 0.2}),
    "wood_door_varnished": ("wood_varnished", 1.5, {"roughness_offset": -0.1, "macro_strength": 0.15}),
    "wood_frame_blue": ("wood_painted_blue", 1.0, {"macro_strength": 0.15}),
    "wood_planks": ("wood_planks", 1.5, {"macro_strength": 0.2}),
    # --- Hub / props ---
    "metal_trunk_blue": ("metal_painted_white", 1.0, {"metallic": True, "tint": (0.32, 0.46, 0.72), "roughness_offset": 0.1}),
    "fabric_sheet": ("paper", 0.6, {"tint": (0.5, 0.58, 0.78), "normal_strength": 0.3, "roughness_offset": 0.2}),
    "fabric_curtain": ("paper", 0.8, {"tint": (0.75, 0.42, 0.3), "normal_strength": 0.3, "roughness_offset": 0.2}),
    "cardboard": ("paper", 0.5, {"tint": (0.62, 0.45, 0.28), "normal_strength": 0.5}),
    # --- Misc ---
    "paper": ("paper", 0.5, {"macro_strength": 0.1}),
}


def tex(set_name: str, suffix: str) -> str:
    return f"res://assets/materials/textures/{set_name}/{set_name}_{suffix}.jpg"


def color(rgb) -> str:
    return f"Color({rgb[0]}, {rgb[1]}, {rgb[2]}, 1)"


# Painted plaster is smoothed by many coats of paint: soften its bump map.
SOFT_BUMP = {"plaster_painted": 0.45, "plaster_bare": 0.7, "tile_white": 0.6}


def build(name: str, set_name: str, tile: float, params: dict) -> str:
    if set_name in SOFT_BUMP and "normal_strength" not in params:
        params = {**params, "normal_strength": SOFT_BUMP[set_name]}
    ext = [("Shader", SHADER, "shader"),
           ("Texture2D", tex(set_name, "albedo"), "albedo"),
           ("Texture2D", tex(set_name, "normal"), "normal"),
           ("Texture2D", tex(set_name, "roughness"), "roughness")]
    if params.get("metallic") and os.path.exists(os.path.join(ROOT, tex(set_name, "metallic")[6:])):
        ext.append(("Texture2D", tex(set_name, "metallic"), "metallic"))
    if params.get("leak"):
        ext.append(("Texture2D", params["leak"], "leak"))
    lines = ['[gd_resource type="ShaderMaterial" format=3]', ""]
    for kind, path, rid in ext:
        lines.append(f'[ext_resource type="{kind}" path="{path}" id="{rid}"]')
    lines += ["", "[resource]", 'shader = ExtResource("shader")',
              'shader_parameter/albedo_tex = ExtResource("albedo")',
              'shader_parameter/normal_tex = ExtResource("normal")',
              'shader_parameter/roughness_tex = ExtResource("roughness")',
              f"shader_parameter/tile_size = {tile}"]
    if any(rid == "metallic" for _, _, rid in ext):
        lines += ['shader_parameter/metallic_tex = ExtResource("metallic")', "shader_parameter/metallic_amount = 1.0"]
    if params.get("leak"):
        lines.append('shader_parameter/leak_tex = ExtResource("leak")')
    simple = {"tint": color, "dado_tint": color}
    for key, value in params.items():
        if key in ("metallic", "leak"):
            continue
        if key == "leak_strength":
            lines.append(f"shader_parameter/leak_strength = {value}")
        elif key in simple:
            lines.append(f"shader_parameter/{key} = {simple[key](value)}")
        else:
            lines.append(f"shader_parameter/{key} = {value}")
    return "\n".join(lines) + "\n"


def main() -> None:
    os.makedirs(OUT, exist_ok=True)
    for name, (set_name, tile, params) in MATERIALS.items():
        with open(os.path.join(OUT, name + ".tres"), "w", encoding="utf-8", newline="\n") as f:
            f.write(build(name, set_name, tile, params))
    print(f"wrote {len(MATERIALS)} materials")


if __name__ == "__main__":
    main()
