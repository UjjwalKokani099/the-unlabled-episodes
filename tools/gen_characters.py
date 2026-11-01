"""Builds the low-poly stand-in characters (primitive meshes, -Z = forward, feet at y=0):
scenes/characters/deshmukh.tscn  - Mr. Deshmukh of 4B (white kurta-pajama, grey hair, glasses)
scenes/characters/raghu.tscn     - Raghu the watchman (khaki uniform, cap, moustache)
scenes/characters/cameraman.tscn - the Cameraman (thin, grey sweater, shoulder camcorder over
                                   his face, blinking red REC light; scripts/characters/cameraman.gd)
scenes/characters/iyer.tscn      - Mrs. Iyer of 2C (saree, shawl, grey bun, bindi)
They are placeholders until real models exist; keep node names (Body, Body/Head, RecDot,
RecLight). Body/Head is a pivot at the top of the neck: NPC head tracking turns it.
Run: python tools/gen_characters.py
"""
import os

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "scenes", "characters")

SKIN = (0.42, 0.29, 0.21)
HEAD_Y = 1.52  # Body/Head pivot height (top of the neck)


def col(c):
    return f"Color({c[0]}, {c[1]}, {c[2]}, 1)"


class Scene:
    def __init__(self, root, script=None):
        self.ext, self.subs, self.nodes, self.mats = [], [], [], {}
        self.n = 0
        props = {}
        if script:
            self.ext.append(f'[ext_resource type="Script" path="{script}" id="1_script"]')
            props["script"] = 'ExtResource("1_script")'
        self.nodes.append(self._node(root, "Node3D", None, props))
        self.nodes.append(self._node("Body", "Node3D", ".", {}))

    def _node(self, name, typ, parent, props):
        head = f'[node name="{name}" type="{typ}"' + (f' parent="{parent}"' if parent else "") + "]"
        return "\n".join([head] + [f"{k} = {v}" for k, v in props.items()])

    def sub(self, typ, props):
        self.n += 1
        sid = f"{typ}_{self.n}"
        self.subs.append("\n".join([f'[sub_resource type="{typ}" id="{sid}"]'] + [f"{k} = {v}" for k, v in props.items()]))
        return sid

    def mat(self, color, rough=0.85, emission=None):
        key = (color, rough, emission)
        if key not in self.mats:
            props = {"albedo_color": col(color), "roughness": str(rough)}
            if emission:
                props.update({"emission_enabled": "true", "emission": col(emission), "emission_energy_multiplier": "6.0"})
            self.mats[key] = self.sub("StandardMaterial3D", props)
        return self.mats[key]

    def part(self, name, mesh_type, mesh_props, color, pos, rot=(0, 0, 0), scale=(1, 1, 1), rough=0.85, emission=None,
             parent="Body"):
        mesh = self.sub(mesh_type, mesh_props)
        props = {"position": f"Vector3({pos[0]}, {pos[1]}, {pos[2]})"}
        if rot != (0, 0, 0):
            props["rotation_degrees"] = f"Vector3({rot[0]}, {rot[1]}, {rot[2]})"
        if scale != (1, 1, 1):
            props["scale"] = f"Vector3({scale[0]}, {scale[1]}, {scale[2]})"
        props["mesh"] = f'SubResource("{mesh}")'
        props["material_override"] = f'SubResource("{self.mat(color, rough, emission)}")'
        self.nodes.append(self._node(name, "MeshInstance3D", parent, props))

    def head_part(self, name, mesh_type, mesh_props, color, world_pos, **kw):
        """A part that turns with the head: given in character space, stored under Body/Head."""
        x, y, z = world_pos
        self.part(name, mesh_type, mesh_props, color, (x, round(y - HEAD_Y, 4), z), parent="Body/Head", **kw)

    def node(self, name, typ, props, parent="."):
        self.nodes.append(self._node(name, typ, parent, props))

    def write(self, filename):
        os.makedirs(OUT, exist_ok=True)
        text = "\n\n".join(["[gd_scene format=3]"] + self.ext + self.subs + self.nodes) + "\n"
        with open(os.path.join(OUT, filename), "w", encoding="utf-8", newline="\n") as f:
            f.write(text)
        print("wrote", filename)


def capsule(r, h):
    return {"radius": str(r), "height": str(h), "radial_segments": "10", "rings": "3"}


def body(s, top, legs, shoes, hair, thin=1.0, arms=True):
    s.part("LegL", "CapsuleMesh", capsule(0.075, 0.88), legs, (-0.1, 0.44, 0))
    s.part("LegR", "CapsuleMesh", capsule(0.075, 0.88), legs, (0.1, 0.44, 0))
    s.part("FootL", "BoxMesh", {"size": "Vector3(0.1, 0.06, 0.25)"}, shoes, (-0.1, 0.03, -0.05))
    s.part("FootR", "BoxMesh", {"size": "Vector3(0.1, 0.06, 0.25)"}, shoes, (0.1, 0.03, -0.05))
    s.part("Torso", "CapsuleMesh", capsule(0.17, 0.66), top, (0, 1.18, 0), scale=(1.05 * thin, 1, 0.68))
    if arms:
        for side, x in (("L", -0.235 * thin), ("R", 0.235 * thin)):
            s.part(f"Arm{side}", "CapsuleMesh", capsule(0.05, 0.66), top, (x, 1.13, 0), rot=(0, 0, 4 if x < 0 else -4))
            s.part(f"Hand{side}", "SphereMesh", {"radius": "0.045", "height": "0.09"}, SKIN, (x * 1.06, 0.79, 0))
    s.part("Neck", "CylinderMesh", {"top_radius": "0.045", "bottom_radius": "0.05", "height": "0.1"}, SKIN, (0, 1.5, 0))
    s.node("Head", "Node3D", {"position": f"Vector3(0, {HEAD_Y}, 0)"}, parent="Body")
    s.head_part("Skull", "SphereMesh", {"radius": "0.105", "height": "0.24"}, SKIN, (0, 1.62, 0))
    s.head_part("Hair", "SphereMesh", {"radius": "0.112", "height": "0.112", "is_hemisphere": "true"}, hair, (0, 1.64, 0.012))
    s.head_part("Nose", "BoxMesh", {"size": "Vector3(0.03, 0.05, 0.04)"}, SKIN, (0, 1.6, -0.105))


def deshmukh():
    s = Scene("Deshmukh")
    white, grey = (0.86, 0.85, 0.8), (0.62, 0.62, 0.6)
    body(s, white, white, (0.3, 0.2, 0.12), grey)
    s.part("Kurta", "CylinderMesh", {"top_radius": "0.18", "bottom_radius": "0.22", "height": "0.72", "radial_segments": "12"},
           white, (0, 0.98, 0), scale=(1, 1, 0.72))
    s.head_part("Glasses", "BoxMesh", {"size": "Vector3(0.17, 0.035, 0.012)"}, (0.05, 0.04, 0.03), (0, 1.635, -0.104), rough=0.3)
    s.write("deshmukh.tscn")


def raghu():
    s = Scene("Raghu")
    khaki, dark = (0.45, 0.39, 0.25), (0.33, 0.28, 0.18)
    body(s, khaki, khaki, (0.08, 0.06, 0.05), (0.06, 0.05, 0.05))
    s.part("Belt", "BoxMesh", {"size": "Vector3(0.37, 0.05, 0.25)"}, (0.08, 0.06, 0.05), (0, 0.9, 0))
    s.head_part("Cap", "CylinderMesh", {"top_radius": "0.11", "bottom_radius": "0.115", "height": "0.07"}, dark, (0, 1.715, 0.005))
    s.head_part("Brim", "BoxMesh", {"size": "Vector3(0.17, 0.012, 0.08)"}, dark, (0, 1.69, -0.11))
    s.head_part("Moustache", "BoxMesh", {"size": "Vector3(0.075, 0.016, 0.012)"}, (0.05, 0.04, 0.04), (0, 1.575, -0.1))
    s.write("raghu.tscn")


def iyer():
    s = Scene("Iyer")
    blouse, saree, shawl = (0.42, 0.08, 0.12), (0.12, 0.32, 0.22), (0.55, 0.5, 0.42)
    body(s, blouse, saree, (0.25, 0.15, 0.1), (0.5, 0.5, 0.5))
    s.part("Saree", "CylinderMesh", {"top_radius": "0.19", "bottom_radius": "0.27", "height": "0.98", "radial_segments": "14"},
           saree, (0, 0.49, 0), scale=(1, 1, 0.8))
    s.part("Pallu", "BoxMesh", {"size": "Vector3(0.2, 0.62, 0.02)"}, saree, (0.04, 1.2, -0.12), rot=(0, 0, 32))
    s.part("Shawl", "CapsuleMesh", capsule(0.19, 0.44), shawl, (0, 1.3, 0.005), scale=(1.12, 1, 0.74))
    s.head_part("Bun", "SphereMesh", {"radius": "0.06", "height": "0.12"}, (0.5, 0.5, 0.5), (0, 1.63, 0.11))
    s.head_part("Bindi", "SphereMesh", {"radius": "0.008", "height": "0.016"}, (0.8, 0.05, 0.05), (0, 1.665, -0.103))
    s.write("iyer.tscn")


def cameraman():
    s = Scene("Cameraman", "res://scripts/characters/cameraman.gd")
    sweater, trousers, black = (0.36, 0.36, 0.36), (0.1, 0.1, 0.11), (0.03, 0.03, 0.035)
    body(s, sweater, trousers, black, (0.04, 0.04, 0.04), thin=0.85, arms=False)
    # arms up, holding the camcorder on his right shoulder, over his face
    s.part("ArmR", "CapsuleMesh", capsule(0.048, 0.36), sweater, (0.2, 1.35, -0.02), rot=(-10, 0, 0))
    s.part("ForearmR", "CapsuleMesh", capsule(0.044, 0.34), sweater, (0.15, 1.5, -0.14), rot=(55, 0, 20))
    s.part("ArmL", "CapsuleMesh", capsule(0.048, 0.36), sweater, (-0.2, 1.35, -0.02), rot=(-10, 0, 0))
    s.part("ForearmL", "CapsuleMesh", capsule(0.044, 0.36), sweater, (-0.08, 1.5, -0.2), rot=(65, 0, -40))
    s.part("Camcorder", "BoxMesh", {"size": "Vector3(0.13, 0.15, 0.36)"}, (0.08, 0.08, 0.09), (0.04, 1.64, -0.21), rough=0.5)
    s.part("Eyepiece", "BoxMesh", {"size": "Vector3(0.1, 0.07, 0.08)"}, black, (-0.03, 1.665, -0.07))
    s.part("Handle", "BoxMesh", {"size": "Vector3(0.05, 0.04, 0.22)"}, black, (0.04, 1.74, -0.2))
    s.part("Lens", "CylinderMesh", {"top_radius": "0.045", "bottom_radius": "0.05", "height": "0.1"}, black,
           (0.04, 1.63, -0.43), rot=(90, 0, 0), rough=0.25)
    s.part("RecDot", "SphereMesh", {"radius": "0.018", "height": "0.036"}, (1, 0.1, 0.05), (0.095, 1.7, -0.39),
           emission=(1, 0.05, 0.02), parent=".")
    # in front of the lens, so it reddens what he films, not himself
    s.node("RecLight", "OmniLight3D", {"position": "Vector3(0.095, 1.7, -0.8)", "light_color": "Color(1, 0.08, 0.04, 1)",
                                        "light_energy": "0.35", "omni_range": "1.3", "omni_attenuation": "1.5"})
    s.write("cameraman.tscn")


if __name__ == "__main__":
    deshmukh()
    raghu()
    iyer()
    cameraman()
