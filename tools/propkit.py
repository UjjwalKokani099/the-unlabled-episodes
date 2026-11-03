"""Set dressing kit: everyday Indian household / building clutter built from primitives.

Used by the level generators (tools/gen_*.py) on top of levelkit. Everything here is static
decoration: it goes under `Static` (merged by StaticBatcher) unless a parent is given, and
only big furniture gets collision. Props face -Z by default (their front is -Z) and take a
yaw in degrees; positions are the prop's origin ON the floor/surface it stands on.

Why: grounded horror lives on clutter. A room with a bed and a desk reads as a test level;
the same room with a bucket and mug, chappals by the door, clothes on a line, a steel
almirah and a calendar on the wall reads as somebody's life.
"""
import math

from levelkit import Level, v3

# Plain colour materials (sub-resources, cached per level): name -> StandardMaterial3D props.
COLOURS = {
    "plastic_white": {"albedo_color": "Color(0.86, 0.85, 0.8, 1)", "roughness": "0.55"},
    "plastic_red": {"albedo_color": "Color(0.62, 0.08, 0.06, 1)", "roughness": "0.5"},
    "plastic_blue": {"albedo_color": "Color(0.12, 0.32, 0.62, 1)", "roughness": "0.35"},
    "plastic_green": {"albedo_color": "Color(0.18, 0.42, 0.22, 1)", "roughness": "0.5"},
    "water_can": {"albedo_color": "Color(0.35, 0.55, 0.8, 0.75)", "roughness": "0.15",
                  "transparency": "1", "metallic_specular": "0.8"},
    "steel": {"albedo_color": "Color(0.72, 0.72, 0.7, 1)", "metallic": "0.9", "roughness": "0.28"},
    "almirah": {"albedo_color": "Color(0.36, 0.42, 0.38, 1)", "metallic": "0.4", "roughness": "0.45"},
    "black": {"albedo_color": "Color(0.04, 0.04, 0.045, 1)", "roughness": "0.6"},
    "rubber": {"albedo_color": "Color(0.09, 0.08, 0.07, 1)", "roughness": "0.9"},
    "cable": {"albedo_color": "Color(0.08, 0.08, 0.08, 1)", "roughness": "0.5"},
    "broom": {"albedo_color": "Color(0.55, 0.45, 0.25, 1)", "roughness": "1.0"},
    "cloth_maroon": {"albedo_color": "Color(0.36, 0.07, 0.09, 1)", "roughness": "1.0"},
    "cloth_check": {"albedo_color": "Color(0.25, 0.3, 0.45, 1)", "roughness": "1.0"},
    "cloth_khaki": {"albedo_color": "Color(0.5, 0.45, 0.33, 1)", "roughness": "1.0"},
    "cloth_towel": {"albedo_color": "Color(0.75, 0.62, 0.42, 1)", "roughness": "1.0"},
    "cloth_grey": {"albedo_color": "Color(0.32, 0.32, 0.34, 1)", "roughness": "1.0"},
    "blanket": {"albedo_color": "Color(0.3, 0.09, 0.08, 1)", "roughness": "1.0"},
    "dust_sheet": {"albedo_color": "Color(0.6, 0.58, 0.53, 1)", "roughness": "1.0"},
    "pillow": {"albedo_color": "Color(0.78, 0.76, 0.7, 1)", "roughness": "0.95"},
    "newsprint": {"albedo_color": "Color(0.72, 0.7, 0.62, 1)", "roughness": "0.95"},
    "calendar_red": {"albedo_color": "Color(0.7, 0.1, 0.08, 1)", "roughness": "0.8"},
    "brass": {"albedo_color": "Color(0.65, 0.5, 0.22, 1)", "metallic": "0.85", "roughness": "0.35"},
    "mirror": {"albedo_color": "Color(0.42, 0.46, 0.5, 1)", "metallic": "0.5", "roughness": "0.12"},
    "lampshade": {"albedo_color": "Color(0.9, 0.78, 0.55, 1)", "roughness": "0.9",
                  "emission_enabled": "true", "emission": "Color(1, 0.7, 0.4, 1)",
                  "emission_energy_multiplier": "0.6"},
    "bulb_warm": {"albedo_color": "Color(1, 0.9, 0.7, 1)", "emission_enabled": "true",
                  "emission": "Color(1, 0.75, 0.45, 1)", "emission_energy_multiplier": "6.0"},
    "terracotta": {"albedo_color": "Color(0.55, 0.27, 0.16, 1)", "roughness": "0.95"},
    "bamboo": {"albedo_color": "Color(0.42, 0.3, 0.16, 1)", "roughness": "0.8"},
    "led_red": {"albedo_color": "Color(0.9, 0.05, 0.03, 1)", "emission_enabled": "true",
                "emission": "Color(1, 0.05, 0.02, 1)", "emission_energy_multiplier": "3.0"},
}


# Cloth colour + (vertical, horizontal) stripe counts for the clothesline (`mat` names).
CLOTH_LOOKS = {
    "cloth_check": ((0.22, 0.27, 0.42), (9.0, 12.0)),
    "cloth_towel": ((0.78, 0.66, 0.46), (0.0, 0.0)),
    "cloth_grey": ((0.26, 0.26, 0.29), (0.0, 0.0)),
    "cloth_khaki": ((0.5, 0.45, 0.33), (0.0, 0.0)),
    "cloth_maroon": ((0.4, 0.08, 0.1), (0.0, 0.0)),
}


class Props:
    """Wraps a Level: adds colour materials and rotated primitives."""

    def __init__(self, lv: Level, parent: str = "Static"):
        self.lv = lv
        self.parent = parent
        self._mats = {}
        self._meshes = {}
        self._n = 0

    # ------------------------------------------------------------------ materials
    def m(self, name: str) -> str:
        """Material reference: a COLOURS entry or a library material (assets/materials)."""
        if name in COLOURS:
            if name not in self._mats:
                self._mats[name] = self.lv.sub("StandardMaterial3D", COLOURS[name])
            return f'SubResource("{self._mats[name]}")'
        return self.lv.mat(name)

    # ------------------------------------------------------------------ primitives
    def _mesh(self, kind: str, dims: tuple) -> str:
        key = (kind,) + tuple(round(d, 4) for d in dims)
        if key not in self._meshes:
            if kind == "box":
                props = {"size": v3(*dims)}
            elif kind == "sphere":
                props = {"radius": "0.5", "height": "1.0", "radial_segments": "20", "rings": "10"}
            else:  # cyl: top radius, bottom radius, height, segments
                props = {"top_radius": str(dims[0]), "bottom_radius": str(dims[1]),
                         "height": str(dims[2]), "radial_segments": str(int(dims[3])), "rings": "1"}
            self._meshes[key] = self.lv.sub("BoxMesh" if kind == "box" else "CylinderMesh", props)
        return self._meshes[key]

    def _put(self, kind, dims, pos, mat, rot=(0, 0, 0), parent=None, shadow=True) -> str:
        self._n += 1
        props = {"position": v3(*pos)}
        if any(rot):
            props["rotation_degrees"] = v3(*rot)
        props["mesh"] = f'SubResource("{self._mesh(kind, dims)}")'
        props["material_override"] = self.m(mat)
        if not shadow:
            props["cast_shadow"] = "0"
        return self.lv.add(f"P{self._n}", "MeshInstance3D", parent or self.parent, props)

    def box(self, pos, size, mat, rot=(0, 0, 0), parent=None, shadow=True):
        return self._put("box", tuple(size), pos, mat, rot, parent, shadow)

    def soft(self, pos, size, mat, rot=(0, 0, 0), parent=None, shadow=True):
        """Squashed sphere: pillows, folded quilts, sacks (soft shapes boxes can't do)."""
        self._n += 1
        props = {"position": v3(*pos), "rotation_degrees": v3(*rot), "scale": v3(*size),
                 "mesh": f'SubResource("{self._mesh("sphere", (1,))}")', "material_override": self.m(mat)}
        if not shadow:
            props["cast_shadow"] = "0"
        return self.lv.add(f"P{self._n}", "MeshInstance3D", parent or self.parent, props)

    def cyl(self, pos, r_top, r_bot, h, mat, rot=(0, 0, 0), seg=12, parent=None, shadow=True):
        return self._put("cyl", (r_top, r_bot, h, seg), pos, mat, rot, parent, shadow)

    # ------------------------------------------------------------------ helpers
    @staticmethod
    def at(origin, yaw, local):
        """World position of `local` (x, y, z) in a frame at `origin` turned `yaw` degrees."""
        a = math.radians(yaw)
        x, y, z = local
        return (origin[0] + x * math.cos(a) + z * math.sin(a), origin[1] + y,
                origin[2] - x * math.sin(a) + z * math.cos(a))

    def part(self, origin, yaw, kind, local, dims, mat, rot=(0, 0, 0), shadow=True):
        pos = self.at(origin, yaw, local)
        r = (rot[0], rot[1] + yaw, rot[2])
        if kind == "box":
            return self.box(pos, dims, mat, r, shadow=shadow)
        return self.cyl(pos, *dims[:3], mat, r, seg=dims[3] if len(dims) > 3 else 12, shadow=shadow)

    # ------------------------------------------------------------------ real models
    def model(self, name, pos, yaw=0.0, pitch=0.0, roll=0.0, scale=1.0, parent=None, collide=None,
              surface="concrete", node_name=None, script="res://scripts/props/prop_model.gd", **opts):
        """Instance assets/models/<name>/<name>.gltf (CC0, tools/fetch_models.py).
        Same facing convention as the primitives: the model's front ends up along -Z
        after `yaw` (glTF fronts are +Z, so the instance is turned 180 degrees).
        collide = (size_x, size_y, size_z) box centred size_y/2 above `pos` (axis-aligned
        before yaw; only 0/90/180/270 yaws keep it exact). Extra keyword options are
        PropModel exports (hide_parts, render_layers, visibility_end, cast_shadows...)."""
        if parent is None:
            parent = self._models_parent()
        props = {"script": f'ExtResource("{self.lv.ext(script, "Script")}")',
                 "position": v3(*pos), "rotation_degrees": v3(pitch, yaw + 180.0, roll)}
        if scale != 1.0:
            props["scale"] = v3(scale, scale, scale)
        for k, val in opts.items():
            if isinstance(val, bool):
                props[k] = "true" if val else "false"
            elif isinstance(val, (list, tuple)):
                props[k] = "PackedStringArray(" + ", ".join(f'"{x}"' for x in val) + ")"
            else:
                props[k] = str(val)
        path = self.lv.scene(node_name or "".join(w.title() for w in name.split("_")), f"res://assets/models/{name}/{name}.gltf",
                             parent, props)
        if collide:
            sx, sy, sz = collide
            if round(yaw) % 180 != 0:
                sx, sz = sz, sx
            self.lv.collider((pos[0], pos[1] + sy / 2, pos[2]), (sx, sy, sz), surface)
        return path

    # ================================================================== furniture
    def plastic_chair(self, o, yaw=0.0, mat="plastic_white", collide=True):
        """Monobloc chair: seat 0.45 m high, faces -Z."""
        P = lambda *a, **k: self.part(o, yaw, *a, **k)  # noqa: E731
        P("box", (0, 0.44, 0), (0.46, 0.035, 0.44), mat)
        P("box", (0, 0.72, 0.21), (0.44, 0.5, 0.03), mat, rot=(-10, 0, 0))
        for sx in (-1, 1):
            for sz in (-1, 1):
                P("box", (sx * 0.2, 0.22, sz * 0.19), (0.04, 0.45, 0.04), mat, rot=(sz * -5, 0, sx * 5))
            P("box", (sx * 0.23, 0.6, 0.0), (0.03, 0.03, 0.4), mat)  # arm rests
        if collide:
            self.lv.collider(self.at(o, yaw, (0, 0.23, 0)), (0.46, 0.46, 0.44), "soft")

    def steel_almirah(self, o, yaw=0.0, w=0.9, h=1.8, d=0.5, top=True):
        """Godrej-style steel cupboard, doors face -Z."""
        P = lambda *a, **k: self.part(o, yaw, *a, **k)  # noqa: E731
        P("box", (0, h / 2 + 0.06, 0), (w, h, d), "almirah")
        P("box", (0, h / 2 + 0.06, -d / 2 - 0.004), (0.006, h - 0.1, 0.008), "black")   # door gap
        P("box", (0.05, h * 0.55, -d / 2 - 0.02), (0.02, 0.18, 0.03), "steel")            # handle
        P("box", (0.08, h * 0.62, -d / 2 - 0.01), (0.03, 0.03, 0.02), "brass")            # lock
        for sx in (-1, 1):
            P("box", (sx * (w / 2 - 0.05), 0.03, 0), (0.06, 0.06, d - 0.05), "rubber")
        if top:
            P("box", (0, h + 0.18, 0.02), (w * 0.7, 0.22, d * 0.8), "cardboard")          # box on top
            P("box", (0.15, h + 0.33, 0.05), (0.4, 0.08, 0.3), "metal_trunk_blue")        # old suitcase
        self.lv.collider(self.at(o, yaw, (0, h / 2 + 0.06, 0)), (w, h, d) if yaw % 180 == 0 else (d, h, w), "metal")

    def bucket_and_mug(self, o, mat="plastic_red"):
        self.cyl((o[0], o[1] + 0.17, o[2]), 0.16, 0.12, 0.34, mat, seg=16)
        self.cyl((o[0], o[1] + 0.33, o[2]), 0.145, 0.145, 0.01, "water_can", seg=16, shadow=False)  # water
        self.cyl((o[0] + 0.24, o[1] + 0.07, o[2] + 0.05), 0.06, 0.055, 0.14, "plastic_blue", seg=10)  # mug
        self.box((o[0] + 0.31, o[1] + 0.08, o[2] + 0.05), (0.03, 0.08, 0.02), "plastic_blue")

    def water_can(self, o):
        """20 litre water can on the floor."""
        self.cyl((o[0], o[1] + 0.25, o[2]), 0.14, 0.14, 0.42, "water_can", seg=14)
        self.cyl((o[0], o[1] + 0.49, o[2]), 0.04, 0.12, 0.08, "water_can", seg=12)
        self.cyl((o[0], o[1] + 0.55, o[2]), 0.035, 0.035, 0.04, "plastic_blue", seg=8)

    def broom(self, o, lean_yaw=0.0):
        """Jhadu leaning against a wall: o = foot on the floor."""
        self.part(o, lean_yaw, "cyl", (0, 0.32, -0.08), (0.035, 0.09, 0.62, 8), "broom", rot=(-14, 0, 0))
        self.part(o, lean_yaw, "cyl", (0, 0.72, -0.17), (0.03, 0.03, 0.2, 8), "plastic_red", rot=(-14, 0, 0))

    def chappals(self, o, yaw=0.0, mat="rubber"):
        for i, sx in enumerate((-0.07, 0.08)):
            self.part(o, yaw + (8 if i else -5), "box", (sx, 0.012, 0.01 * i), (0.1, 0.022, 0.26), mat)
            self.part(o, yaw + (8 if i else -5), "box", (sx, 0.03, -0.04 + 0.01 * i), (0.09, 0.012, 0.03), "plastic_blue")

    def newspaper_stack(self, o, yaw=0.0, n=9):
        for i in range(n):
            self.part(o, yaw + (i * 37 % 11) - 5, "box", (0, 0.006 + i * 0.012, 0), (0.3, 0.012, 0.4), "newsprint")

    def doormat(self, o, yaw=0.0):
        self.part(o, yaw, "box", (0, 0.006, 0), (0.6, 0.012, 0.4), "fabric_curtain", shadow=False)

    def suitcase_flat(self, o, yaw=0.0):
        self.part(o, yaw, "box", (0, 0.1, 0), (0.7, 0.2, 0.48), "plastic_blue")
        self.part(o, yaw, "box", (0, 0.205, 0), (0.25, 0.02, 0.03), "black")

    # ================================================================== on tables
    def tumbler(self, o):
        self.cyl((o[0], o[1] + 0.055, o[2]), 0.035, 0.03, 0.11, "steel", seg=12)

    def bottle(self, o, mat="water_can"):
        self.cyl((o[0], o[1] + 0.11, o[2]), 0.035, 0.035, 0.22, mat, seg=10)
        self.cyl((o[0], o[1] + 0.25, o[2]), 0.014, 0.035, 0.06, mat, seg=10)
        self.cyl((o[0], o[1] + 0.29, o[2]), 0.015, 0.015, 0.02, "plastic_blue", seg=8)

    def books(self, o, yaw=0.0, n=4):
        mats = ("cloth_maroon", "newsprint", "cloth_check", "cardboard", "wood_door_dark")
        y = 0.0
        for i in range(n):
            h = 0.02 + (i % 3) * 0.008
            self.part(o, yaw + (i * 13 % 9) - 4, "box", (0, y + h / 2, 0), (0.2, h, 0.27 - i * 0.01), mats[i % len(mats)])
            y += h

    def pen_stand(self, o):
        self.cyl((o[0], o[1] + 0.05, o[2]), 0.035, 0.035, 0.1, "black", seg=10)
        for i, (dx, dz) in enumerate(((0.01, 0), (-0.01, 0.01), (0, -0.012))):
            self.cyl((o[0] + dx, o[1] + 0.12, o[2] + dz), 0.004, 0.004, 0.14, ("plastic_blue", "plastic_red", "black")[i],
                     rot=(dz * 400, 0, dx * 400), seg=6)

    def extension_board(self, o, yaw=0.0):
        self.part(o, yaw, "box", (0, 0.02, 0), (0.28, 0.04, 0.08), "plastic_white")
        self.part(o, yaw, "box", (0.11, 0.042, 0), (0.025, 0.006, 0.02), "led_red", shadow=False)

    def desk_lamp(self, o, yaw=0.0):
        """Table lamp with a cloth shade. Returns the local light position for an OmniLight."""
        P = lambda *a, **k: self.part(o, yaw, *a, **k)  # noqa: E731
        P("cyl", (0, 0.015, 0), (0.08, 0.09, 0.03, 14), "black")
        P("cyl", (0, 0.2, 0), (0.012, 0.012, 0.36, 8), "brass")
        P("cyl", (0, 0.4, 0), (0.09, 0.14, 0.18, 16), "lampshade", shadow=False)
        P("cyl", (0, 0.37, 0), (0.025, 0.025, 0.05, 8), "bulb_warm", shadow=False)
        return self.at(o, yaw, (0, 0.33, 0))

    def mosquito_coil(self, o):
        self.cyl((o[0], o[1] + 0.005, o[2]), 0.06, 0.06, 0.01, "steel", seg=10)
        self.cyl((o[0], o[1] + 0.015, o[2]), 0.055, 0.055, 0.008, "plastic_green", seg=14)

    # ================================================================== walls
    def calendar(self, o, yaw=0.0):
        """Wall calendar: o = centre on the wall surface, front facing -Z after yaw."""
        self.part(o, yaw, "box", (0, 0.12, -0.004), (0.32, 0.12, 0.006), "calendar_red", shadow=False)
        self.part(o, yaw, "box", (0, -0.1, -0.004), (0.32, 0.32, 0.005), "paper", shadow=False)
        for row in range(4):
            self.part(o, yaw, "box", (0, -0.0 - row * 0.065, -0.008), (0.26, 0.004, 0.002), "black", shadow=False)

    def wall_clock(self, o, yaw=0.0):
        self.part(o, yaw, "cyl", (0, 0, -0.02), (0.14, 0.14, 0.04, 20), "plastic_white", rot=(90, 0, 0))
        self.part(o, yaw, "cyl", (0, 0, -0.025), (0.15, 0.15, 0.03, 20), "black", rot=(90, 0, 0))
        self.part(o, yaw, "box", (0.03, 0.02, -0.045), (0.07, 0.008, 0.004), "black", rot=(0, 0, 30), shadow=False)
        self.part(o, yaw, "box", (0, 0.05, -0.046), (0.006, 0.1, 0.004), "black", shadow=False)

    def mirror(self, o, yaw=0.0, w=0.35, h=0.5):
        self.part(o, yaw, "box", (0, 0, -0.012), (w + 0.04, h + 0.04, 0.02), "wood_door_dark")
        self.part(o, yaw, "box", (0, 0, -0.024), (w, h, 0.004), "mirror", shadow=False)
        self.part(o, yaw, "box", (0, -h / 2 - 0.06, -0.06), (w, 0.02, 0.1), "plastic_white")  # small shelf
        self.part(o, yaw, "cyl", (-0.1, -h / 2 - 0.0, -0.06), (0.025, 0.025, 0.1, 8), "plastic_green")  # oil bottle
        self.part(o, yaw, "box", (0.06, -h / 2 - 0.04, -0.06), (0.15, 0.015, 0.03), "black")  # comb

    def switchboard(self, o, yaw=0.0, n=4):
        """Modular switch plate (the real switch, if any, is a separate LightSwitch)."""
        self.part(o, yaw, "box", (0, 0, -0.01), (0.07 * n + 0.04, 0.12, 0.02), "plastic_white")
        for i in range(n):
            self.part(o, yaw, "box", (-0.07 * (n - 1) / 2 + i * 0.07, 0.02, -0.022), (0.03, 0.045, 0.008), "plastic_white")
        self.part(o, yaw, "box", (0, -0.035, -0.022), (0.05, 0.03, 0.006), "black")  # socket

    def wire(self, a, b, r=0.005):
        """Straight surface-run cable from a to b."""
        d = (b[0] - a[0], b[1] - a[1], b[2] - a[2])
        length = math.sqrt(sum(c * c for c in d))
        mid = tuple((a[i] + b[i]) / 2 for i in range(3))
        yaw = math.degrees(math.atan2(d[0], d[2]))
        pitch = math.degrees(math.atan2(math.hypot(d[0], d[2]), d[1]))
        self.cyl(mid, r, r, length, "cable", rot=(pitch, yaw, 0), seg=5, shadow=False)

    def _models_parent(self):
        """One un-batched "Props" node per level, shared by every Props helper."""
        if getattr(self.lv, "props_node", None) is None:
            self.lv.props_node = self.lv.add("Props", "Node3D", ".")
        return self.lv.props_node

    def cloth(self, top_centre, w, h, colour, yaw=0.0, stripes=(0.0, 0.0), stripe_colour=(0.8, 0.78, 0.7),
              folds=3.0, fold_depth=0.025, gather=0.0, sway=0.03, tilt=0.0, name="Cloth"):
        """Hanging fabric (shaders/cloth.gdshader): a w x h panel hung from its top edge at
        `top_centre`, its face toward -Z after `yaw` (both sides render). Not batched."""
        def c(t):
            return f"Color({t[0]}, {t[1]}, {t[2]}, 1)"
        mat = self.lv.sub("ShaderMaterial", {
            "shader": f'ExtResource("{self.lv.ext("res://shaders/cloth.gdshader", "Shader")}")',
            "shader_parameter/albedo": c(colour), "shader_parameter/stripe_color": c(stripe_colour),
            "shader_parameter/stripes": f"Vector2({stripes[0]}, {stripes[1]})",
            "shader_parameter/size": f"Vector2({w}, {h})", "shader_parameter/folds": str(folds),
            "shader_parameter/fold_depth": str(fold_depth), "shader_parameter/gather": str(gather),
            "shader_parameter/sway": str(sway)})
        mesh = self.lv.sub("QuadMesh", {"size": f"Vector2({w}, {h})", "subdivide_width": str(max(4, int(w * 24))),
                                        "subdivide_depth": str(max(4, int(h * 16))),
                                        "center_offset": f"Vector3(0, {-h / 2}, 0)"})
        # QuadMesh faces +Z; turn 180 so the kit's "front is -Z after yaw" holds.
        return self.lv.add(name, "MeshInstance3D", self._models_parent(), {
            "position": v3(*top_centre), "rotation_degrees": v3(tilt, yaw + 180.0, 0),
            "mesh": f'SubResource("{mesh}")', "material_override": f'SubResource("{mat}")'})

    def dust_sheet(self, centre, size, yaw=0.0, colour=(0.6, 0.58, 0.53)):
        """Furniture under a dust sheet: a colliding core with a soft top, cloth skirts falling
        to the floor on all four sides (with folds). `centre`/`size` = the furniture box."""
        cx, cy, cz = centre
        sx, sy, sz = size
        top = cy + sy / 2
        self.part((cx, cy, cz), yaw, "box", (0, 0, 0), (sx - 0.04, sy - 0.02, sz - 0.04), "dust_sheet")
        self.lv.collider((cx, cy, cz), (sx, sy, sz) if round(yaw) % 180 == 0 else (sz, sy, sx), "soft")
        self.soft(self.at((cx, top - 0.01, cz), yaw, (0, 0, 0)), (sx + 0.02, 0.06, sz + 0.02), "dust_sheet", rot=(0, yaw, 0))
        h = sy + 0.02
        for side, (lx, lz, w, face) in enumerate(((0, -sz / 2 - 0.012, sx + 0.06, 0), (0, sz / 2 + 0.012, sx + 0.06, 180),
                                                    (-sx / 2 - 0.012, 0, sz + 0.06, 90), (sx / 2 + 0.012, 0, sz + 0.06, -90))):
            pos = self.at((cx, top, cz), yaw, (lx, 0, lz))
            self.cloth(pos, w, h, colour, yaw=yaw + face, folds=max(2.0, w * 4.0), fold_depth=0.02, gather=0.3,
                       sway=0.0, name="DustSheet")

    def clothesline(self, a, b, items, sag=0.04):
        """Nylon line from a to b with clothes hanging: items = [(t 0..1, kind, mat)]."""
        self.wire(a, b, 0.003)
        yaw = math.degrees(math.atan2(b[0] - a[0], b[2] - a[2])) - 90
        for t, kind, mat in items:
            p = tuple(a[i] + (b[i] - a[i]) * t for i in range(3))
            p = (p[0], p[1] - sag * 4 * t * (1 - t), p[2])
            colour, stripes = CLOTH_LOOKS.get(mat, ((0.4, 0.4, 0.4), (0.0, 0.0)))
            if kind == "shirt":
                self.cloth(p, 0.5, 0.62, colour, yaw=yaw, stripes=stripes, folds=2.5, fold_depth=0.018, name="Shirt")
            elif kind == "towel":
                self.cloth(p, 0.38, 0.72, colour, yaw=yaw, stripes=(0.0, 1.5), stripe_colour=(0.6, 0.15, 0.1),
                           folds=2.0, fold_depth=0.012, name="Towel")
            else:  # trousers / dupatta
                self.cloth(p, 0.34, 0.95, colour, yaw=yaw, stripes=stripes, folds=1.5, fold_depth=0.02, name="Trousers")

    def hooks_with_bag(self, o, yaw=0.0):
        self.part(o, yaw, "box", (0, 0, -0.03), (0.3, 0.03, 0.03), "wood_door_dark")
        self.part(o, yaw, "box", (-0.08, -0.25, -0.08), (0.3, 0.42, 0.12), "cloth_grey", rot=(-6, 0, 0))   # backpack
        self.part(o, yaw, "box", (0.1, -0.4, -0.05), (0.32, 0.75, 0.03), "cloth_khaki", rot=(-3, 0, 3))    # jacket

    # ================================================================== 1990s / watchman
    def matka(self, o):
        """Clay water pot on a ring stand, steel plate lid and a tumbler on top."""
        self.cyl((o[0], o[1] + 0.04, o[2]), 0.13, 0.15, 0.08, "metal_rust", seg=12)
        self.cyl((o[0], o[1] + 0.2, o[2]), 0.2, 0.13, 0.26, "terracotta", seg=16)
        self.cyl((o[0], o[1] + 0.4, o[2]), 0.11, 0.2, 0.14, "terracotta", seg=16)
        self.cyl((o[0], o[1] + 0.48, o[2]), 0.13, 0.13, 0.01, "steel", seg=16)
        self.tumbler((o[0] + 0.03, o[1] + 0.485, o[2]))

    def tiffin(self, o):
        """Stacked steel lunch box."""
        for i in range(3):
            self.cyl((o[0], o[1] + 0.045 + i * 0.085, o[2]), 0.075, 0.075, 0.08, "steel", seg=14)
        self.box((o[0], o[1] + 0.3, o[2]), (0.02, 0.06, 0.16), "steel")

    def radio(self, o, yaw=0.0):
        """Transistor radio, speaker facing -Z."""
        self.part(o, yaw, "box", (0, 0.06, 0), (0.2, 0.12, 0.07), "wood_door_dark")
        self.part(o, yaw, "box", (-0.04, 0.06, -0.036), (0.09, 0.08, 0.004), "black", shadow=False)
        self.part(o, yaw, "box", (0.06, 0.08, -0.036), (0.05, 0.015, 0.004), "brass", shadow=False)
        self.part(o, yaw, "cyl", (0.08, 0.24, 0.02), (0.003, 0.003, 0.3, 4), "steel", rot=(0, 0, -20), shadow=False)

    def lathi(self, o, lean_yaw=0.0):
        """Watchman's bamboo stick leaning on a wall: o = foot on the floor."""
        self.part(o, lean_yaw, "cyl", (0, 0.66, -0.12), (0.016, 0.018, 1.35, 8), "bamboo", rot=(-10, 0, 0))

    def notices(self, o, yaw=0.0, n=3):
        """Sheets of paper pasted on a wall (circulars, a duty roster)."""
        for i in range(n):
            self.part(o, yaw, "box", ((i - (n - 1) / 2) * 0.26, (i % 2) * 0.05, -0.004),
                      (0.21, 0.29, 0.003), "paper" if i % 2 == 0 else "newsprint", rot=(0, 0, (i * 7 % 5) - 2), shadow=False)

