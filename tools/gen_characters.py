"""Builds the stand-in characters from primitives (-Z = forward, feet at y=0):
scenes/characters/deshmukh.tscn  - Mr. Deshmukh of 4B: 70s, a slight stoop, white kurta-pajama
                                   under a grey Nehru jacket, thick black spectacles, white
                                   moustache, white hair around a bald crown, steel watch.
scenes/characters/raghu.tscn     - Raghu the watchman, 52: khaki uniform with epaulettes, pocket
                                   flaps, brass badge, belt, peaked cap, thick moustache.
scenes/characters/cameraman.tscn - the Cameraman: thin, grey ribbed sweater, a VHS shoulder
                                   camcorder held over his face (hood, viewfinder, mic, handle),
                                   blinking red REC light (scripts/characters/cameraman.gd).
scenes/characters/iyer.tscn      - Mrs. Iyer of 2C, 60s: green saree with a gold border and front
                                   pleats, the pallu over her shoulder (cloth, sways), maroon
                                   blouse, shawl, grey bun with jasmine, bindi, gold bangles.

Skeleton (pivots, all Node3D): Body/Pelvis/HipL|HipR/KneeL|KneeR, Body/Chest/ShoulderL|R/
ElbowL|R, Body/Head (NPC head tracking turns it; top of the neck at HEAD_Y), Head/EyelidL|R.
scripts/characters/character_life.gd (child "Life") breathes, blinks and walks them.
Keep the names Body, Body/Head, RecDot and RecLight: scripts look them up.
Run: python tools/gen_characters.py
"""
import os

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "scenes", "characters")

HEAD_Y = 1.52  # Body/Head pivot height (top of the neck)
HIP_Y = 0.92
SHOULDER_Y = 1.42


def col(c, a=1):
    return f"Color({c[0]}, {c[1]}, {c[2]}, {a})"


def v(x, y, z):
    return f"Vector3({round(x, 4)}, {round(y, 4)}, {round(z, 4)})"


class Scene:
    def __init__(self, root, script=None):
        self.ext, self.subs, self.nodes, self.mats, self.meshes = [], [], [], {}, {}
        self.n = 0
        props = {}
        if script:
            props["script"] = f'ExtResource("{self.ext_res("Script", script)}")'
        self.nodes.append(self._node(root, "Node3D", None, props))
        self.nodes.append(self._node("Body", "Node3D", ".", {}))

    def ext_res(self, typ, path):
        for line in self.ext:
            if f'path="{path}"' in line:
                return line.split('id="')[1].split('"')[0]
        rid = f"{len(self.ext) + 1}_r"
        self.ext.append(f'[ext_resource type="{typ}" path="{path}" id="{rid}"]')
        return rid

    def _node(self, name, typ, parent, props):
        head = f'[node name="{name}" type="{typ}"' + (f' parent="{parent}"' if parent else "") + "]"
        return "\n".join([head] + [f"{k} = {val}" for k, val in props.items()])

    def sub(self, typ, props):
        self.n += 1
        sid = f"{typ}_{self.n}"
        self.subs.append("\n".join([f'[sub_resource type="{typ}" id="{sid}"]'] + [f"{k} = {val}" for k, val in props.items()]))
        return sid

    def mat(self, color, rough=0.85, emission=None, metal=0.0, skin=False):
        color = tuple(round(c, 4) for c in color)
        key = (color, rough, emission, metal, skin)
        if key not in self.mats:
            props = {"albedo_color": col(color), "roughness": str(rough)}
            if metal:
                props["metallic"] = str(metal)
            if emission:
                props.update({"emission_enabled": "true", "emission": col(emission), "emission_energy_multiplier": "6.0"})
            if skin:  # soft light through skin (Forward+; ignored on the web)
                props.update({"subsurf_scatter_enabled": "true", "subsurf_scatter_strength": "0.35"})
            self.mats[key] = self.sub("StandardMaterial3D", props)
        return self.mats[key]

    def mesh(self, typ, props):
        key = (typ, tuple(sorted(props.items())))
        if key not in self.meshes:
            self.meshes[key] = self.sub(typ, props)
        return self.meshes[key]

    def pivot(self, name, parent, pos, rot=(0, 0, 0)):
        props = {"position": v(*pos)}
        if rot != (0, 0, 0):
            props["rotation_degrees"] = v(*rot)
        self.nodes.append(self._node(name, "Node3D", parent, props))
        return f"{parent}/{name}"

    def part(self, name, typ, mesh_props, color, pos, rot=(0, 0, 0), scale=(1, 1, 1), parent="Body", rough=0.85,
             emission=None, metal=0.0, skin=False, material=None):
        self.n += 1
        props = {"position": v(*pos)}
        if rot != (0, 0, 0):
            props["rotation_degrees"] = v(*rot)
        if scale != (1, 1, 1):
            props["scale"] = v(*scale)
        props["mesh"] = f'SubResource("{self.mesh(typ, mesh_props)}")'
        props["material_override"] = material or f'SubResource("{self.mat(color, rough, emission, metal, skin)}")'
        self.nodes.append(self._node(name, "MeshInstance3D", parent, props))

    # handy primitives -------------------------------------------------------------
    def ball(self, name, color, pos, size, parent="Body", rot=(0, 0, 0), **kw):
        """Ellipsoid of diameter `size` (x, y, z)."""
        self.part(name, "SphereMesh", {"radius": "0.5", "height": "1.0", "radial_segments": "16", "rings": "8"},
                  color, pos, rot, size, parent, **kw)

    def box(self, name, color, pos, size, parent="Body", rot=(0, 0, 0), **kw):
        self.part(name, "BoxMesh", {"size": v(*size)}, color, pos, rot, parent=parent, **kw)

    def caps(self, name, color, pos, r, h, parent="Body", rot=(0, 0, 0), scale=(1, 1, 1), **kw):
        self.part(name, "CapsuleMesh", {"radius": str(r), "height": str(h), "radial_segments": "12", "rings": "4"},
                  color, pos, rot, scale, parent, **kw)

    def cyl(self, name, color, pos, r_top, r_bot, h, parent="Body", rot=(0, 0, 0), scale=(1, 1, 1), seg=14, **kw):
        self.part(name, "CylinderMesh", {"top_radius": str(r_top), "bottom_radius": str(r_bot), "height": str(h),
                                         "radial_segments": str(seg), "rings": "1"}, color, pos, rot, scale, parent, **kw)

    def ring(self, name, color, pos, inner, outer, parent="Body", rot=(0, 0, 0), scale=(1, 1, 1), **kw):
        self.part(name, "TorusMesh", {"inner_radius": str(inner), "outer_radius": str(outer), "rings": "16",
                                      "ring_segments": "6"}, color, pos, rot, scale, parent, **kw)

    def cloth(self, name, color, pos, w, h, parent="Body", rot=(0, 0, 0), stripes=(0.0, 0.0), stripe_color=(0.8, 0.7, 0.3),
              folds=2.0, fold_depth=0.015, sway=0.02):
        mat = self.sub("ShaderMaterial", {
            "shader": f'ExtResource("{self.ext_res("Shader", "res://shaders/cloth.gdshader")}")',
            "shader_parameter/albedo": col(color), "shader_parameter/stripe_color": col(stripe_color),
            "shader_parameter/stripes": f"Vector2({stripes[0]}, {stripes[1]})",
            "shader_parameter/stripe_width": "0.12",
            "shader_parameter/size": f"Vector2({w}, {h})", "shader_parameter/folds": str(folds),
            "shader_parameter/fold_depth": str(fold_depth), "shader_parameter/sway": str(sway),
            "shader_parameter/wear": "0.1"})
        mesh = self.sub("QuadMesh", {"size": f"Vector2({w}, {h})", "subdivide_width": "8", "subdivide_depth": "14",
                                     "center_offset": f"Vector3(0, {-h / 2}, 0)"})
        self.nodes.append(self._node(name, "MeshInstance3D", parent, {
            "position": v(*pos), "rotation_degrees": v(*rot), "mesh": f'SubResource("{mesh}")',
            "material_override": f'SubResource("{mat}")'}))

    def node(self, name, typ, props, parent="."):
        self.nodes.append(self._node(name, typ, parent, props))

    def life(self, **exports):
        props = {"script": f'ExtResource("{self.ext_res("Script", "res://scripts/characters/character_life.gd")}")'}
        for k, val in exports.items():
            props[k] = ("true" if val else "false") if isinstance(val, bool) else str(val)
        self.node("Life", "Node", props)

    def write(self, filename):
        os.makedirs(OUT, exist_ok=True)
        text = "\n\n".join([f"[gd_scene format=3]"] + self.ext + self.subs + self.nodes) + "\n"
        with open(os.path.join(OUT, filename), "w", encoding="utf-8", newline="\n") as f:
            f.write(text)
        print("wrote", filename)


# ------------------------------------------------------------------------------------ body

def skeleton(s, *, skin, top, sleeve, legs, shoes, thin=1.0, short_sleeves=False, chappals=False,
             arm_pose=None):
    """Pelvis + legs, chest + arms on pivots. `arm_pose` = {"ShoulderL": rot, ...} for posed
    arms. Returns nothing; parts are named for character_life.gd."""
    sk = s.mat(skin, 0.55, skin=True)
    pelvis = s.pivot("Pelvis", "Body", (0, 0.95, 0))
    s.caps("Hips", legs, (0, 0, 0), 0.16, 0.34, parent=pelvis, scale=(1.02 * thin, 1, 0.7))
    for side, x in (("L", -0.095), ("R", 0.095)):
        hip = s.pivot(f"Hip{side}", pelvis, (x * thin, HIP_Y - 0.95, 0))
        s.caps(f"Thigh{side}", legs, (0, -0.22, 0), 0.072, 0.48, parent=hip)
        knee = s.pivot(f"Knee{side}", hip, (0, -0.45, 0))
        s.caps(f"Shin{side}", legs, (0, -0.2, 0), 0.058, 0.44, parent=knee)
        if chappals:
            s.part(f"Foot{side}", "SphereMesh", {"radius": "0.5", "height": "1.0", "radial_segments": "12", "rings": "6"},
                   skin, (0, -0.435, -0.05), scale=(0.085, 0.05, 0.22), parent=knee, material=f'SubResource("{sk}")')
            s.box(f"Sole{side}", shoes, (0, -0.462, -0.05), (0.1, 0.014, 0.26), parent=knee)
            s.box(f"Strap{side}", shoes, (0, -0.44, -0.09), (0.095, 0.02, 0.035), parent=knee)
        else:
            s.box(f"Shoe{side}", shoes, (0, -0.44, -0.035), (0.1, 0.07, 0.22), parent=knee, rough=0.45)
            s.ball(f"Toe{side}", shoes, (0, -0.448, -0.14), (0.1, 0.06, 0.1), parent=knee, rough=0.45)
            s.box(f"Heel{side}", (0.02, 0.02, 0.02), (0, -0.47, 0.04), (0.1, 0.02, 0.08), parent=knee)
    chest = s.pivot("Chest", "Body", (0, 1.0, 0))
    s.caps("Torso", top, (0, 0.2, 0), 0.17, 0.56, parent=chest, scale=(1.04 * thin, 1, 0.64))
    s.ball("Belly", top, (0, 0.06, -0.01), (0.31 * thin, 0.22, 0.23), parent=chest)
    for side, x in (("L", -1), ("R", 1)):
        rot = (arm_pose or {}).get(f"Shoulder{side}", (0, 0, 0))
        shoulder = s.pivot(f"Shoulder{side}", chest, (x * 0.185 * thin, SHOULDER_Y - 1.0, 0), rot)
        s.ball(f"Delt{side}", sleeve, (0, -0.035, 0), (0.1, 0.11, 0.1), parent=shoulder)
        upper = skin if short_sleeves else sleeve
        s.caps(f"UpperArm{side}", upper if not short_sleeves else sleeve, (0, -0.1, 0), 0.05, 0.2, parent=shoulder)
        if short_sleeves:
            s.caps(f"UpperArmSkin{side}", skin, (0, -0.2, 0), 0.042, 0.18, parent=shoulder, skin=True, rough=0.55)
        erot = (arm_pose or {}).get(f"Elbow{side}", (0, 0, 0))
        elbow = s.pivot(f"Elbow{side}", shoulder, (0, -0.29, 0), erot)
        s.caps(f"Forearm{side}", skin if short_sleeves else sleeve, (0, -0.13, 0), 0.042, 0.27, parent=elbow,
               skin=short_sleeves, rough=0.55 if short_sleeves else 0.85)
        if not short_sleeves:
            s.cyl(f"Cuff{side}", sleeve, (0, -0.255, 0), 0.044, 0.046, 0.03, parent=elbow, rough=1.0)
        s.ball(f"Hand{side}", skin, (0, -0.32, -0.005), (0.07, 0.1, 0.035), parent=elbow, skin=True, rough=0.55)
        s.caps(f"Thumb{side}", skin, (-x * 0.03, -0.3, -0.02), 0.012, 0.05, parent=elbow, rot=(20, 0, x * 25),
               skin=True, rough=0.55)
    s.cyl("Neck", skin, (0, 1.46, 0), 0.043, 0.05, 0.14, skin=True, rough=0.55)


def face(s, *, skin, hair, lips=None, brows=None, eyes=(0.12, 0.08, 0.06), age=0.0):
    """Head pivot + skull, jaw, ears, eyes with blinking lids, brows, nose, lips. `age`
    0..1 sags the jaw line and adds under-eye shadows."""
    s.node("Head", "Node3D", {"position": v(0, HEAD_Y, 0)}, parent="Body")
    h = "Body/Head"
    kw = {"skin": True, "rough": 0.55}
    s.ball("Skull", skin, (0, 0.11, 0.005), (0.19, 0.235, 0.215), parent=h, **kw)
    s.ball("Jaw", skin, (0, 0.035 - age * 0.008, -0.025), (0.15, 0.1, 0.15), parent=h, **kw)
    s.ball("Chin", skin, (0, 0.012, -0.075), (0.06, 0.045, 0.04), parent=h, **kw)
    for side, x in (("L", -1), ("R", 1)):
        s.ball(f"Ear{side}", skin, (x * 0.097, 0.1, 0.012), (0.022, 0.058, 0.04), parent=h, **kw)
        s.ball(f"Cheek{side}", skin, (x * 0.05, 0.075, -0.075), (0.05, 0.04, 0.035), parent=h, **kw)
        s.ball(f"Socket{side}", [c * 0.82 for c in skin], (x * 0.034, 0.112, -0.083), (0.036, 0.026, 0.02), parent=h, **kw)
        s.ball(f"Eye{side}", (0.86, 0.84, 0.8), (x * 0.034, 0.113, -0.088), (0.024, 0.02, 0.02), parent=h, rough=0.15)
        s.ball(f"Iris{side}", eyes, (x * 0.034, 0.113, -0.097), (0.011, 0.011, 0.006), parent=h, rough=0.1)
        lid = s.pivot(f"Eyelid{side}", h, (x * 0.034, 0.127, -0.09))
        s.ball(f"Lid{side}", skin, (0, -0.013, 0.0), (0.03, 0.028, 0.022), parent=lid, **kw)
        s.box(f"Brow{side}", brows or hair, (x * 0.035, 0.143, -0.096), (0.036, 0.008, 0.012), parent=h,
              rot=(0, 0, -x * 9), rough=1.0)
        if age > 0.3:
            s.ball(f"Bag{side}", [c * 0.86 for c in skin], (x * 0.034, 0.098, -0.088), (0.03, 0.012, 0.012), parent=h, **kw)
    s.box("NoseBridge", skin, (0, 0.1, -0.1), (0.022, 0.05, 0.03), parent=h, rot=(-14, 0, 0), **kw)
    s.ball("NoseTip", skin, (0, 0.074, -0.112), (0.032, 0.026, 0.026), parent=h, **kw)
    s.ball("Lips", lips or [c * 0.78 for c in skin], (0, 0.045, -0.096), (0.046, 0.014, 0.014), parent=h, rough=0.4)


# ------------------------------------------------------------------------------------ cast

def deshmukh():
    s = Scene("Deshmukh")
    skin, white, jacket, hair = (0.47, 0.33, 0.24), (0.86, 0.85, 0.8), (0.28, 0.27, 0.25), (0.82, 0.82, 0.8)
    skeleton(s, skin=skin, top=white, sleeve=white, legs=white, shoes=(0.3, 0.2, 0.12), chappals=True)
    # kurta to the knees, a mandarin collar and a button placket; sleeveless Nehru jacket over it
    s.cyl("Kurta", white, (0, 0.85, 0), 0.2, 0.25, 0.62, scale=(1, 1, 0.74), rough=0.95)
    s.cyl("KurtaCollar", white, (0, 1.455, 0), 0.055, 0.058, 0.04)
    s.caps("Jacket", jacket, (0, 0.17, 0.004), 0.19, 0.56, parent="Body/Chest", scale=(1.1, 1, 0.74), rough=0.8)
    s.box("JacketOpening", white, (0, 0.16, -0.14), (0.028, 0.46, 0.01), parent="Body/Chest")
    for i in range(4):
        s.ball(f"Button{i}", (0.6, 0.5, 0.35), (0.018, 0.36 - i * 0.09, -0.144), (0.012, 0.012, 0.008),
               parent="Body/Chest", rough=0.3, metal=0.6)
    s.box("JacketPocket", [c * 0.85 for c in jacket], (-0.09, 0.3, -0.138), (0.07, 0.012, 0.01), parent="Body/Chest")
    s.ring("Watch", (0.7, 0.7, 0.68), (0, -0.24, 0), 0.04, 0.05, parent="Body/Chest/ShoulderL/ElbowL", metal=0.9, rough=0.25)
    face(s, skin=skin, hair=hair, brows=hair, age=0.9, eyes=(0.1, 0.07, 0.05))
    h = "Body/Head"
    # bald crown, white hair around the sides and back
    s.ring("HairRing", hair, (0, 0.13, 0.025), 0.07, 0.105, parent=h, rot=(12, 0, 0), scale=(0.95, 0.9, 1.0), rough=1.0)
    s.ball("HairBack", hair, (0, 0.1, 0.07), (0.17, 0.14, 0.09), parent=h, rough=1.0)
    s.box("Moustache", hair, (0, 0.058, -0.103), (0.07, 0.016, 0.014), parent=h, rough=1.0)
    # thick black spectacles
    glass = s.mat((0.05, 0.04, 0.03), 0.3)
    for side, x in (("L", -1), ("R", 1)):
        s.ring(f"Rim{side}", (0.05, 0.04, 0.03), (x * 0.035, 0.115, -0.106), 0.015, 0.021, parent=h, rot=(90, 0, 0),
               scale=(1.15, 1, 1), rough=0.3)
        s.box(f"Temple{side}", (0.05, 0.04, 0.03), (x * 0.093, 0.12, -0.05), (0.006, 0.006, 0.11), parent=h, rough=0.3)
    s.box("Bridge", (0.05, 0.04, 0.03), (0, 0.118, -0.108), (0.016, 0.006, 0.006), parent=h, rough=0.3)
    s.life(stoop_deg=6.0, stride_rate=4.8, stride_deg=18.0)
    s.write("deshmukh.tscn")


def raghu():
    s = Scene("Raghu")
    skin, khaki, dark, black = (0.38, 0.26, 0.18), (0.47, 0.41, 0.27), (0.36, 0.31, 0.2), (0.05, 0.045, 0.04)
    skeleton(s, skin=skin, top=khaki, sleeve=khaki, legs=dark, shoes=black, short_sleeves=True)
    c = "Body/Chest"
    for side, x in (("L", -1), ("R", 1)):
        s.box(f"Epaulette{side}", dark, (x * 0.14, 0.43, 0), (0.1, 0.012, 0.05), parent=c, rot=(0, 0, x * -12))
        s.box(f"Pocket{side}", khaki, (x * 0.085, 0.3, -0.112), (0.085, 0.09, 0.012), parent=c)
        s.box(f"Flap{side}", dark, (x * 0.085, 0.345, -0.12), (0.09, 0.025, 0.01), parent=c)
    s.box("Badge", (0.75, 0.6, 0.25), (0.085, 0.27, -0.121), (0.04, 0.02, 0.004), parent=c, metal=0.8, rough=0.3)
    s.box("NameTag", (0.85, 0.85, 0.82), (-0.085, 0.385, -0.12), (0.06, 0.014, 0.004), parent=c)
    s.box("Placket", dark, (0, 0.2, -0.111), (0.022, 0.45, 0.006), parent=c)
    s.ring("WhistleCord", (0.7, 0.1, 0.1), (0.1, 0.3, -0.06), 0.06, 0.066, parent=c, rot=(20, 0, 40))
    s.box("Belt", (0.12, 0.09, 0.06), (0, 0.1, 0), (0.35, 0.05, 0.25), parent="Body/Pelvis", rough=0.5)
    s.box("Buckle", (0.75, 0.62, 0.3), (0, 0.1, -0.126), (0.05, 0.035, 0.008), parent="Body/Pelvis", metal=0.8, rough=0.3)
    face(s, skin=skin, hair=(0.08, 0.07, 0.07), age=0.55)
    h = "Body/Head"
    s.ball("HairSides", (0.25, 0.24, 0.23), (0, 0.11, 0.03), (0.195, 0.16, 0.19), parent=h, rough=1.0)
    s.cyl("Cap", dark, (0, 0.205, 0.008), 0.108, 0.112, 0.075, parent=h)
    s.box("Brim", (0.1, 0.08, 0.05), (0, 0.172, -0.105), (0.17, 0.012, 0.08), parent=h, rot=(-8, 0, 0), rough=0.4)
    s.box("CapBadge", (0.75, 0.62, 0.3), (0, 0.205, -0.111), (0.03, 0.03, 0.004), parent=h, metal=0.8, rough=0.3)
    s.box("Moustache", (0.06, 0.05, 0.05), (0, 0.059, -0.102), (0.085, 0.022, 0.016), parent=h, rough=1.0)
    s.life()
    s.write("raghu.tscn")


def iyer():
    s = Scene("Iyer")
    skin, blouse, saree, gold, shawl = (0.45, 0.31, 0.22), (0.42, 0.08, 0.12), (0.1, 0.3, 0.2), (0.8, 0.62, 0.22), (0.55, 0.5, 0.42)
    grey = (0.42, 0.41, 0.4)
    skeleton(s, skin=skin, top=blouse, sleeve=blouse, legs=saree, shoes=(0.25, 0.15, 0.1), short_sleeves=True, chappals=True)
    # the saree: a flared skirt with a gold border, pleats tucked at the front
    s.cyl("Saree", saree, (0, 0.49, 0), 0.19, 0.27, 0.98, scale=(1, 1, 0.82), rough=0.7)
    s.cyl("Border", gold, (0, 0.05, 0), 0.272, 0.275, 0.07, scale=(1, 1, 0.82), rough=0.35, metal=0.5)
    for i in range(5):
        x = -0.06 + i * 0.03
        s.box(f"Pleat{i}", saree, (x, 0.45, -0.2 - 0.012 * (i % 2)), (0.022, 0.86, 0.02), rot=(-7, 0, 0), rough=0.7)
        s.box(f"PleatBorder{i}", gold, (x, 0.04, -0.222 - 0.012 * (i % 2)), (0.023, 0.06, 0.021), rough=0.35, metal=0.5)
    s.caps("Waist", saree, (0, 0.0, 0), 0.165, 0.3, parent="Body/Chest", scale=(1.02, 1, 0.72), rough=0.7)
    # pallu: from the left shoulder across the chest, then down the back (sways)
    s.box("PalluFront", saree, (-0.04, 0.24, -0.11), (0.13, 0.42, 0.012), parent="Body/Chest", rot=(0, 0, 30), rough=0.7)
    s.cloth("PalluBack", saree, (-0.08, 0.42, 0.083), 0.24, 0.62, parent="Body/Chest", rot=(-4, 180, -8),
            stripes=(0.0, 0.0), folds=2.0, fold_depth=0.012, sway=0.02)
    s.cloth("PalluBorder", gold, (-0.08 + 0.62 * 0.139, 0.42 - 0.618, 0.083 + 0.043), 0.24, 0.05, parent="Body/Chest",
            rot=(-4, 180, -8), folds=2.0, fold_depth=0.012, sway=0.02)
    s.caps("Shawl", shawl, (0, 0.33, 0.01), 0.185, 0.3, parent="Body/Chest", scale=(1.14, 0.7, 0.76), rough=1.0)
    for side in ("L", "R"):
        for i in range(2):
            s.ring(f"Bangle{side}{i}", gold, (0, -0.23 - i * 0.018, 0), 0.04, 0.047,
                   parent=f"Body/Chest/Shoulder{side}/Elbow{side}", metal=0.9, rough=0.25)
    s.ring("Mangalsutra", gold, (0, 1.42, -0.02), 0.07, 0.074, rot=(70, 0, 0), metal=0.9, rough=0.25)
    face(s, skin=skin, hair=grey, brows=(0.3, 0.3, 0.3), lips=(0.36, 0.16, 0.14), age=0.75)
    h = "Body/Head"
    s.ball("HairTop", grey, (0, 0.17, 0.02), (0.2, 0.15, 0.21), parent=h, rough=1.0)
    s.box("Parting", [c * 0.8 for c in skin], (0, 0.24, -0.04), (0.006, 0.004, 0.09), parent=h, rot=(-20, 0, 0))
    s.ball("Bun", grey, (0, 0.1, 0.12), (0.11, 0.1, 0.08), parent=h, rough=1.0)
    for i in range(10):  # jasmine strand around the bun
        import math
        a = i / 10.0 * math.tau
        s.ball(f"Jasmine{i}", (0.95, 0.94, 0.88), (math.cos(a) * 0.058, 0.1 + math.sin(a) * 0.052, 0.13),
               (0.018, 0.018, 0.018), parent=h, rough=0.9)
    s.ball("Bindi", (0.75, 0.04, 0.04), (0, 0.142, -0.104), (0.012, 0.012, 0.004), parent=h, rough=0.4)
    for side, x in (("L", -1), ("R", 1)):
        s.ball(f"Earring{side}", gold, (x * 0.098, 0.068, -0.0), (0.014, 0.014, 0.014), parent=h, metal=0.9, rough=0.2)
    s.life(stride_rate=6.2, stride_deg=13.0, stoop_deg=3.0)
    s.write("iyer.tscn")


def cameraman():
    s = Scene("Cameraman", "res://scripts/characters/cameraman.gd")
    skin, sweater, trousers, black = (0.36, 0.3, 0.26), (0.36, 0.36, 0.36), (0.1, 0.1, 0.11), (0.03, 0.03, 0.035)
    pose = {"ShoulderR": (60, 0, 0), "ElbowR": (111, 0, 0), "ShoulderL": (75, -30, 0), "ElbowL": (75, 0, 0)}
    skeleton(s, skin=skin, top=sweater, sleeve=sweater, legs=trousers, shoes=black, thin=0.85, arm_pose=pose)
    c = "Body/Chest"
    rib = [x * 0.82 for x in sweater]
    s.cyl("Hem", rib, (0, -0.05, 0), 0.155, 0.155, 0.06, parent=c, scale=(1.0, 1, 0.66), rough=1.0)
    s.cyl("Collar", rib, (0, 1.45, 0), 0.06, 0.07, 0.06, rough=1.0)
    for i in range(6):  # cable-knit ribs down the front
        s.box(f"Rib{i}", rib, (-0.075 + i * 0.03, 0.2, -0.108), (0.008, 0.42, 0.006), parent=c, rough=1.0)
    face(s, skin=skin, hair=(0.04, 0.04, 0.04), age=0.4, eyes=(0.02, 0.02, 0.02))
    s.ball("Hair", (0.04, 0.04, 0.04), (0, 0.15, 0.02), (0.2, 0.15, 0.21), parent="Body/Head", rough=1.0)
    # the VHS shoulder camcorder, over his face
    body_c = (0.08, 0.08, 0.09)
    s.box("Camcorder", body_c, (0.04, 1.64, -0.21), (0.13, 0.16, 0.38), rough=0.45)
    s.box("ShoulderPad", black, (0.06, 1.55, -0.05), (0.1, 0.03, 0.14), rough=0.9)
    s.box("CassetteDoor", [x * 1.4 for x in body_c], (0.106, 1.64, -0.2), (0.004, 0.11, 0.2), rough=0.4)
    s.box("Label", (0.6, 0.6, 0.62), (0.107, 1.69, -0.29), (0.003, 0.018, 0.06), rough=0.4)
    s.box("HandleTop", black, (0.04, 1.755, -0.2), (0.04, 0.025, 0.24), rough=0.6)
    for z in (-0.3, -0.1):
        s.box(f"HandlePost{z}", black, (0.04, 1.73, z), (0.035, 0.04, 0.025), rough=0.6)
    s.cyl("LensBarrel", black, (0.04, 1.63, -0.43), 0.046, 0.05, 0.12, rot=(90, 0, 0), rough=0.3)
    s.cyl("FocusRing", (0.12, 0.12, 0.12), (0.04, 1.63, -0.46), 0.05, 0.05, 0.025, rot=(90, 0, 0), rough=0.9)
    s.cyl("LensHood", black, (0.04, 1.63, -0.51), 0.062, 0.05, 0.05, rot=(90, 0, 0), rough=0.4)
    s.cyl("Glass", (0.02, 0.02, 0.03), (0.04, 1.63, -0.532), 0.042, 0.042, 0.004, rot=(90, 0, 0), rough=0.03, metal=0.6)
    s.cyl("Viewfinder", black, (-0.045, 1.71, -0.17), 0.022, 0.026, 0.16, rot=(90, 0, 0), rough=0.4)
    s.ball("Eyecup", (0.02, 0.02, 0.02), (-0.045, 1.71, -0.08), (0.05, 0.05, 0.03), rough=0.9)
    s.cyl("Mic", black, (0.04, 1.78, -0.37), 0.013, 0.013, 0.1, rot=(90, 0, 0), rough=0.6)
    s.cyl("MicFoam", (0.05, 0.05, 0.05), (0.04, 1.78, -0.435), 0.016, 0.016, 0.035, rot=(90, 0, 0), rough=1.0)
    s.part("RecDot", "SphereMesh", {"radius": "0.012", "height": "0.024"}, (1, 0.1, 0.05), (0.095, 1.7, -0.39),
           emission=(1, 0.05, 0.02), parent=".")
    # in front of the lens, so it reddens what he films, not himself
    s.node("RecLight", "OmniLight3D", {"position": "Vector3(0.095, 1.7, -0.8)", "light_color": "Color(1, 0.08, 0.04, 1)",
                                        "light_energy": "0.35", "omni_range": "1.3", "omni_attenuation": "1.5"})
    # he never blinks (his face is behind the camera anyway); arms stay up while he walks
    s.life(swing_arms=False, blink=False, stride_rate=4.5, stride_deg=16.0)
    s.write("cameraman.tscn")


if __name__ == "__main__":
    deshmukh()
    raghu()
    iyer()
    cameraman()
