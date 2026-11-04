"""Blender character builder (run headless, after tools/blender/fetch_makehuman.sh):

    blender -b --factory-startup --python tools/blender/build_characters.py [-- name ...]

Each character starts from the CC0 MakeHuman base mesh, shaped with MakeHuman's macro targets
(gender, age, muscle, weight, height, proportions, ethnicity blend), converted to metres and
Godot axes (-Z forward, feet at y=0). Clothing = material zones on the body (pushed out a few
mm, with soft folds) plus lathe garments (kurta, jacket, saree, pallu). MakeHuman's default
skeleton weights are folded onto the game's bones, named like the pivots tools/
gen_characters.py builds (Pelvis, Chest, Neck, Head, EyelidL/R, ShoulderL/R, ElbowL/R,
HipL/R, KneeL/R). systems/characters/skinned_body.gd copies the pivots onto the bones every
frame, so CharacterLife and NPC head tracking drive these meshes unchanged.

Writes assets/characters/meshes/<name>.glb and <name>.json (pivot positions + height, read by
gen_characters.py). Preview: tools/blender/preview.py.
"""
import json
import math
import os
import sys

import bmesh
import bpy
import numpy as np
from mathutils import Vector

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
OUT = os.path.join(ROOT, "assets", "characters", "meshes")
MH = os.path.join(ROOT, "tools", "_build", "makehuman", "makehuman", "data")


def g2b(p):
    """Godot (x, y up, z back) -> Blender (x, -z, y)."""
    return Vector((float(p[0]), float(-p[2]), float(p[1])))


def smoothstep(a, b, x):
    t = np.clip((x - a) / (b - a), 0.0, 1.0)
    return t * t * (3 - 2 * t)


# ------------------------------------------------------------------------ MakeHuman data

def load_obj():
    """base.obj -> verts (N,3) in MH units, faces [(group, [v...], [uv...])], uvs."""
    verts, uvs, faces = [], [], []
    group = "body"
    with open(os.path.join(MH, "3dobjs", "base.obj")) as f:
        for line in f:
            if line.startswith("v "):
                verts.append([float(x) for x in line.split()[1:4]])
            elif line.startswith("vt "):
                uvs.append([float(x) for x in line.split()[1:3]])
            elif line.startswith("g "):
                group = line.split()[1]
            elif line.startswith("f "):
                vi, ti = [], []
                for tok in line.split()[1:]:
                    parts = tok.split("/")
                    vi.append(int(parts[0]) - 1)
                    ti.append(int(parts[1]) - 1 if len(parts) > 1 and parts[1] else -1)
                faces.append((group, vi, ti))
    return np.array(verts), faces, np.array(uvs)


_target_cache = {}


def target(path):
    if path not in _target_cache:
        full = os.path.join(MH, "targets", "macrodetails", path)
        rows = [l.split() for l in open(full) if l.strip() and not l.startswith("#")]
        idx = np.array([int(r[0]) for r in rows], dtype=np.int64)
        d = np.array([[float(x) for x in r[1:4]] for r in rows], dtype=float).reshape(-1, 3)
        _target_cache[path] = (idx, d)
    return _target_cache[path]


def split(v, lo, hi, mid=0.5):
    """Slider -> {name: weight}: below mid blends lo<->average, above average<->hi."""
    if v < mid:
        return {lo: (mid - v) / mid, "average": v / mid}
    return {"average": 1 - (v - mid) / (1 - mid), hi: (v - mid) / (1 - mid)}


def age_weights(a):
    if a < 0.1875:
        return {"baby": 1 - a / 0.1875, "child": a / 0.1875}
    if a < 0.5:
        t = (a - 0.1875) / (0.5 - 0.1875)
        return {"child": 1 - t, "young": t}
    return {"young": 1 - (a - 0.5) * 2, "old": (a - 0.5) * 2}


def age_slider(years):
    if years >= 25:
        return 0.5 + (years - 25) / 65 * 0.5
    if years >= 11:
        return 0.1875 + (years - 11) / 14 * (0.5 - 0.1875)
    return max(years - 1, 0) / 10 * 0.1875


def apply_macros(verts, c):
    v = verts.copy()
    gender = {"male": c["gender"], "female": 1 - c["gender"]}
    age = age_weights(age_slider(c["age_years"]))
    muscle = {k + "muscle": w for k, w in split(c.get("muscle", 0.5), "min", "max").items()}
    weight = {k + "weight": w for k, w in split(c.get("weight", 0.5), "min", "max").items()}
    races = c.get("race", {"african": 0.3, "asian": 0.2, "caucasian": 0.5})

    def add(path, w):
        if w > 1e-4:
            idx, d = target(path)
            v[idx] += d * w

    for g, gw in gender.items():
        for a, aw in age.items():
            for r, rw in races.items():
                add(f"{r}-{g}-{a}.target", gw * aw * rw)
            for m, mw in muscle.items():
                for wt, ww in weight.items():
                    add(f"universal-{g}-{a}-{m}-{wt}.target", gw * aw * mw * ww)
                    h = c.get("height", 0.5)
                    if h != 0.5:
                        hn = "maxheight" if h > 0.5 else "minheight"
                        add(f"height/{g}-{a}-{m}-{wt}-{hn}.target", gw * aw * mw * ww * abs(h - 0.5) * 2)
                    p = c.get("proportions", 0.5)
                    if a != "baby" and p != 0.5:
                        pn = "idealproportions" if p > 0.5 else "uncommonproportions"
                        add(f"proportions/{g}-{a}-{m}-{wt}-{pn}.target", gw * aw * mw * ww * abs(p - 0.5) * 2)
    return v


def to_game(verts, ground):
    """MH (decimetres, +Z forward) -> metres, -Z forward, feet on y=0."""
    out = verts * 0.1
    out[:, 0] *= -1
    out[:, 2] *= -1
    out[:, 1] -= ground * 0.1
    return out


# ------------------------------------------------------------------------ skeleton

BONE_MAP = {
    "Pelvis": ["root", "spine05", "spine04", "pelvis.L", "pelvis.R"],
    "Chest": ["spine03", "spine02", "spine01", "breast.L", "breast.R", "clavicle.L", "clavicle.R"],
    "Neck": ["neck01", "neck02", "neck03"],
    "EyelidL": ["orbicularis03.L"],
    "EyelidR": ["orbicularis03.R"],
}
for _s in ("L", "R"):
    BONE_MAP[f"Shoulder{_s}"] = [f"shoulder01.{_s}", f"upperarm01.{_s}", f"upperarm02.{_s}"]
    BONE_MAP[f"Elbow{_s}"] = [f"lowerarm01.{_s}", f"lowerarm02.{_s}", f"wrist.{_s}"] + \
        [f"metacarpal{i}.{_s}" for i in range(1, 5)] + [f"finger{i}-{j}.{_s}" for i in range(1, 6) for j in range(1, 4)]
    BONE_MAP[f"Hip{_s}"] = [f"upperleg01.{_s}", f"upperleg02.{_s}"]
    BONE_MAP[f"Knee{_s}"] = [f"lowerleg01.{_s}", f"lowerleg02.{_s}", f"foot.{_s}"] + \
        [f"toe{i}-{j}.{_s}" for i in range(1, 6) for j in range(1, 4)]
# Everything else (face, jaw, tongue, eyes, lower lids) goes to Head.
PARENTS = {"Pelvis": None, "Chest": "Pelvis", "Neck": "Chest", "Head": "Neck", "EyelidL": "Head", "EyelidR": "Head",
           "ShoulderL": "Chest", "ShoulderR": "Chest", "ElbowL": "ShoulderL", "ElbowR": "ShoulderR",
           "HipL": "Pelvis", "HipR": "Pelvis", "KneeL": "HipL", "KneeR": "HipR"}
# Where each game bone sits: the head joint of this MakeHuman bone (eyelids pivot on the eye).
BONE_AT = {"Pelvis": "spine05", "Chest": "spine03", "Neck": "neck01", "Head": "head", "EyelidL": "eye.L",
           "EyelidR": "eye.R", "ShoulderL": "upperarm01.L", "ShoulderR": "upperarm01.R", "ElbowL": "lowerarm01.L",
           "ElbowR": "lowerarm01.R", "HipL": "upperleg01.L", "HipR": "upperleg01.R", "KneeL": "lowerleg01.L",
           "KneeR": "lowerleg01.R"}


def game_weights(n_verts):
    """(n_verts, bones) weight matrix from MakeHuman's default weights."""
    mhw = json.load(open(os.path.join(MH, "rigs", "default_weights.mhw")))["weights"]
    bones = list(PARENTS)
    lookup = {b: game for game, mh in BONE_MAP.items() for b in mh}
    W = np.zeros((n_verts, len(bones)))
    for mh_bone, pairs in mhw.items():
        col = bones.index(lookup.get(mh_bone, "Head"))
        for vi, w in pairs:
            W[vi, col] += w
    return bones, W


def joints(verts):
    sk = json.load(open(os.path.join(MH, "rigs", "default.mhskel")))
    return {name: verts[idx].mean(axis=0) for name, idx in sk["joints"].items()}


# ------------------------------------------------------------------------ materials

def srgb_to_linear(c):
    return tuple(((x + 0.055) / 1.055) ** 2.4 if x > 0.04045 else x / 12.92 for x in c)


def material(name, color, rough=0.8, metal=0.0):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    bsdf = m.node_tree.nodes["Principled BSDF"]
    bsdf.inputs["Base Color"].default_value = (*srgb_to_linear(color), 1.0)
    bsdf.inputs["Roughness"].default_value = rough
    bsdf.inputs["Metallic"].default_value = metal
    return m


# ------------------------------------------------------------------------ pose

def rotation_between(a, b):
    a = a / np.linalg.norm(a)
    b = b / np.linalg.norm(b)
    v = np.cross(a, b)
    s = np.linalg.norm(v)
    cth = float(np.dot(a, b))
    if s < 1e-8:
        return np.eye(3)
    k = np.array([[0, -v[2], v[1]], [v[2], 0, -v[0]], [-v[1], v[0], 0]])
    return np.eye(3) + k + k @ k * ((1 - cth) / (s * s))


def repose(verts, J, W, bones, c):
    """MakeHuman's A-pose -> arms hanging at the sides, legs straight: the rest pose the
    game's pivots assume. Linear-blend skinning with the arm/leg weights, so the armpits
    and hips bend smoothly."""
    col = {b: i for i, b in enumerate(bones)}
    out = verts.copy()
    Jn = dict(J)
    for side, sx in (("L", -1.0), ("R", 1.0)):
        steps = (
            # upper arm down to the side, then the forearm straight on (slight bend kept)
            (f"upperarm01.{side}", f"lowerarm01.{side}", (f"Shoulder{side}", f"Elbow{side}"),
             np.array([sx * c.get("arm_out", 0.1), -1.0, 0.04]),
             ("upperarm", "lowerarm", "wrist", "finger", "metacarpal")),
            (f"lowerarm01.{side}", f"wrist.{side}", (f"Elbow{side}",),
             np.array([sx * c.get("arm_out", 0.1) * 0.5, -1.0, -0.12]),
             ("lowerarm", "wrist", "finger", "metacarpal")),
            (f"upperleg01.{side}", f"foot.{side}", (f"Hip{side}", f"Knee{side}"),
             np.array([sx * 0.02, -1.0, 0.0]), ("upperleg", "lowerleg", "foot", "toe")),
        )
        for root, tip, grp, want, parts in steps:
            cpos = Jn[f"{root}____head"]
            R = rotation_between(Jn[f"{tip}____head"] - cpos, want)
            w = sum(W[:, col[g]] for g in grp)
            rotated = (out - cpos) @ R.T + cpos
            out = out + w[:, None] * (rotated - out)
            for name, jp in list(Jn.items()):
                if name.split("____")[0].endswith("." + side) and name.startswith(parts):
                    Jn[name] = (jp - cpos) @ R.T + cpos
    return out, Jn


# ------------------------------------------------------------------------ zones

CLOTH = ("top", "legs")


def zone_faces(c, verts, faces, W, bones, J):
    """Zone per face: skin (head included: painted with vertex colours), top, legs, shoes,
    eye, iris."""
    col = {b: i for i, b in enumerate(bones)}
    arm = W[:, [col["ShoulderL"], col["ShoulderR"], col["ElbowL"], col["ElbowR"]]].sum(axis=1)
    forearm = W[:, [col["ElbowL"], col["ElbowR"]]].sum(axis=1)
    leg = W[:, [col["HipL"], col["HipR"], col["KneeL"], col["KneeR"]]].sum(axis=1)
    head = W[:, [col["Head"], col["EyelidL"], col["EyelidR"]]].sum(axis=1)
    neck = W[:, col["Neck"]]
    L = lines(c, J)
    eye = {s: J[f"eye.{s}____head"] for s in ("L", "R")}
    head_c = J["head____head"]
    zone = []
    for group, vi, _ in faces:
        p = verts[vi].mean(axis=0)
        if group in ("helper-l-eye", "helper-r-eye"):
            e = eye["L" if "-l-" in group else "R"]
            zone.append("iris" if e[2] - p[2] > c.get("iris_depth", 0.0098) else "eye")
            continue
        if head[vi].mean() > 0.6:
            zone.append("skin")
            continue
        if leg[vi].mean() > 0.5 or (p[1] < L["waist"] and arm[vi].mean() < 0.5):
            if p[1] < L["shoe"]:
                zone.append("foot")
            else:
                zone.append("legs")
            continue
        if arm[vi].mean() > 0.5:
            covered = p[1] > L["sleeve"] and not (c.get("sleeve", "short") == "short" and forearm[vi].mean() > 0.5)
            zone.append("top" if covered else "skin")
            continue
        if p[1] > L["neck_base"] + 0.015:
            zone.append("skin")
            continue
        # V neck: open collar down to `collar_depth` below the neck base
        v_depth = c.get("collar_depth", 0.08) * max(0.0, 1.0 - abs(p[0]) / 0.065)
        collar = c.get("open_collar", True) and p[2] < head_c[2] and p[1] > L["neck_base"] - v_depth
        zone.append("skin" if neck[vi].mean() > 0.45 or collar else "top")
    return zone


def lines(c, J):
    """Heights of the clothing seams."""
    shoulder_y = J["upperarm01.L____head"][1]
    elbow_y = J["lowerarm01.L____head"][1]
    wrist_y = J["wrist.L____head"][1]
    sleeve = c.get("sleeve", "short")
    return {
        "waist": J["spine03____head"][1] + c.get("waist_offset", -0.02),
        "shoe": J["foot.L____head"][1] + 0.03,
        "sleeve": {"short": shoulder_y - (shoulder_y - elbow_y) * 0.55, "elbow": elbow_y - 0.03,
                   "full": wrist_y + 0.035, "none": shoulder_y + 1.0}[sleeve],
        "neck_base": J["neck01____head"][1] - 0.01,
    }


def snap_seams(verts, faces, zone, c, J):
    """Vertices on a seam between two zones move onto the seam's line: straight hems."""
    L = lines(c, J)
    zones_of = {}
    for (_, vi, _), zn in zip(faces, zone):
        for v in vi:
            zones_of.setdefault(v, set()).add(zn)
    out = verts.copy()
    for v, zs in zones_of.items():
        if len(zs) < 2:
            continue
        y = out[v, 1]
        if zs >= {"top", "legs"}:
            out[v, 1] = L["waist"]
        elif "foot" in zs and "legs" in zs:
            out[v, 1] = L["shoe"]
        elif zs >= {"top", "skin"} and abs(y - L["sleeve"]) < 0.025 and abs(out[v, 0]) > 0.15:
            out[v, 1] = L["sleeve"]
    return out


def vertex_normals(verts, faces):
    n = np.zeros_like(verts)
    for _, vi, _ in faces:
        p0, p1, p2 = verts[vi[0]], verts[vi[1]], verts[vi[2]]
        n[vi] += np.cross(p1 - p0, p2 - p0)
    ln = np.linalg.norm(n, axis=1)
    ln[ln == 0] = 1
    return n / ln[:, None]


def push_cloth(verts, normals, faces, zone, c, J):
    """Clothes stand off the skin with soft folds; trouser legs widen towards the ankle."""
    off = np.zeros(len(verts))
    x, y, z = verts[:, 0], verts[:, 1], verts[:, 2]
    fold = 0.0018 * np.sin(y * 85.0 + x * 18.0) * np.sin(y * 29.0 - z * 37.0)
    knee_y = J["lowerleg01.L____head"][1]
    flare = c.get("trouser_flare", 0.016) * smoothstep(knee_y + 0.1, J["foot.L____head"][1], y)
    for (_, vi, _), zn in zip(faces, zone):
        if zn == "top":
            off[vi] = np.maximum(off[vi], c.get("cloth_offset", 0.006) + fold[vi])
        elif zn == "legs":
            off[vi] = np.maximum(off[vi], c.get("cloth_offset", 0.006) + 0.003 + fold[vi] + flare[vi])
    # cloth meets the skin at its edges (no see-through gap): seam vertices stay put,
    # their neighbours lift halfway
    zones_of = {}
    for (_, vi, _), zn in zip(faces, zone):
        for v in vi:
            zones_of.setdefault(v, set()).add(zn in CLOTH)
    seam = {v for v, k in zones_of.items() if len(k) == 2}
    near = set()
    for _, vi, _ in faces:
        if seam.intersection(vi):
            near.update(vi)
    for v in near - seam:
        off[v] *= 0.5
    for v in seam:
        off[v] = 0.0
    return verts + normals * off[:, None]


# ------------------------------------------------------------------------ face paint

def face_paint(c, verts, normals, J, head_w):
    """Vertex colours (linear) for the skin + head, and the hair's swelling. Every mask is
    smooth, so the hairline, brows, lips and stubble have soft edges at any mesh density."""
    skin = np.array(srgb_to_linear(c["colors"]["skin"]))
    hair = np.array(srgb_to_linear(c["colors"]["hair"]))
    brow_c = np.array(srgb_to_linear(c.get("brow_color", c["colors"]["hair"])))
    n = len(verts)
    colors = np.tile(skin, (n, 1))
    x, y, z = verts[:, 0], verts[:, 1], verts[:, 2]
    eye = {s: J[f"eye.{s}____head"] for s in ("L", "R")}
    ey = (eye["L"][1] + eye["R"][1]) / 2
    ez = min(eye["L"][2], eye["R"][2])
    hz = J["head____head"][2]
    h = np.clip(head_w, 0, 1)
    front = smoothstep(ez + 0.045, ez + 0.015, z)       # 1 on the face
    back = smoothstep(hz + 0.0, hz + 0.04, z)             # 1 behind the ears
    ax = np.abs(x)
    style = c.get("hair", "short")
    # hairline: forehead (receding at the temples) -> above the ears -> nape
    front_line = ey + c.get("hair_line", 0.062) - 0.022 * smoothstep(0.03, 0.065, ax)
    side_line = ey + 0.03 * (1 - back) - 0.06 * back
    line = front * front_line + (1 - front) * side_line
    m_hair = smoothstep(line - 0.004, line + 0.006, y) * h
    if style == "bald_crown":
        crown = smoothstep(ey + 0.055, ey + 0.085, y) * smoothstep(hz + 0.08, hz + 0.02, z)
        m_hair *= 1 - crown
        m_hair *= 1 - smoothstep(ey + 0.03, ey + 0.05, y) * front
    if style == "none":
        m_hair *= 0
    # ears stay bare
    ear = smoothstep(0.055, 0.07, ax) * smoothstep(ey + 0.025, ey + 0.015, y) * smoothstep(ey - 0.07, ey - 0.05, y) \
        * (1 - back)
    m_hair *= 1 - ear
    # brows: an arch over each eye
    m_brow = np.zeros(n)
    for s in ("L", "R"):
        ex = eye[s][0]
        dx = (x - ex) / 0.024
        arch = ey + 0.017 + 0.004 * (1 - dx * dx) - 0.003 * np.clip(-np.sign(ex) * (x - ex) / 0.024, 0, 1)
        m_brow = np.maximum(m_brow, np.exp(-dx ** 4) * np.exp(-((y - arch) / 0.0045) ** 2))
    m_brow *= front * h * c.get("brow_amount", 1.0)
    # lips, cheeks, under-eye, stubble / moustache (men)
    mouth_y = ey + c.get("mouth_offset", -0.063)
    m_lips = np.exp(-((x / 0.022) ** 2 + ((y - mouth_y) / 0.0085) ** 2) ** 2) * front * h
    m_cheek = np.exp(-(((ax - 0.04) / 0.02) ** 2 + ((y - ey + 0.03) / 0.02) ** 2)) * front * h
    m_under = np.exp(-(((ax - 0.032) / 0.014) ** 2 + ((y - ey + 0.014) / 0.006) ** 2)) * front * h
    jaw = smoothstep(ey - 0.04, ey - 0.06, y) * smoothstep(ey - 0.14, ey - 0.11, y)
    m_stubble = jaw * smoothstep(0.075, 0.05, ax) * (1 - back) * h * c.get("stubble", 0.0)
    m_stubble *= 1 - m_lips
    m_tache = np.exp(-((x / 0.028) ** 4 + ((y - mouth_y - 0.012) / 0.0055) ** 2)) * front * h * c.get("moustache", 0.0)

    def mix(base, col, m):
        return base * (1 - m[:, None]) + col * m[:, None]
    colors = mix(colors, skin * np.array([1.08, 0.86, 0.84]), m_cheek * 0.25)
    colors = mix(colors, skin * 0.78, m_under * (0.2 + 0.4 * c.get("tired", 0.3)))
    colors = mix(colors, skin * np.array([0.82, 0.62, 0.62]), m_lips * 0.7)
    colors = mix(colors, hair * 0.9 + skin * 0.1, m_stubble * 0.45)
    colors = mix(colors, hair, m_tache)
    colors = mix(colors, brow_c, m_brow * 0.92)
    colors = mix(colors, hair, m_hair)
    swell = m_hair * c.get("hair_thickness", 0.007) + m_tache * 0.0025 + m_brow * 0.0008
    return colors, normals * swell[:, None]

# ------------------------------------------------------------------------ garments

def apply_modifiers(ob):
    dg = bpy.context.evaluated_depsgraph_get()
    me = bpy.data.meshes.new_from_object(ob.evaluated_get(dg))
    old = ob.data
    ob.modifiers.clear()
    ob.data = me
    bpy.data.meshes.remove(old)


def link(name, me):
    ob = bpy.data.objects.new(name, me)
    bpy.context.collection.objects.link(ob)
    return ob


def lathe(name, profile, centre_z, segs=28, ripple=None):
    """Garment tube around the y axis: profile = [(y, half_width, half_depth)], top to bottom.
    `ripple(angle, y)` adds radial folds (angle pi = front, -z)."""
    bm = bmesh.new()
    rings = []
    for y, rx, rz in profile:
        ring = []
        for i in range(segs):
            a = i / segs * math.tau
            k = 1.0 + (ripple(a, y) if ripple else 0.0)
            ring.append(bm.verts.new(g2b((math.sin(a) * rx * k, y, centre_z + math.cos(a) * rz * k))))
        rings.append(ring)
    for r0, r1 in zip(rings, rings[1:]):
        for i in range(segs):
            j = (i + 1) % segs
            bm.faces.new((r0[i], r0[j], r1[j], r1[i]))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    ob = link(name, me)
    sol = ob.modifiers.new("solid", "SOLIDIFY")
    sol.thickness = 0.005
    sub = ob.modifiers.new("sub", "SUBSURF")
    sub.levels = 1
    apply_modifiers(ob)
    for poly in ob.data.polygons:
        poly.use_smooth = True
    return ob


LEGS = None
TORSO = None  # set per build: mask of torso-weighted vertices (arms and legs excluded)


def body_width(verts, y, band=0.015, legs=False):
    """(half-width, half-depth, centre z) of the torso at height y (with the legs if asked)."""
    m = np.abs(verts[:, 1] - y) < band
    m &= TORSO | LEGS if legs else TORSO
    if not m.any():
        return 0.15, 0.1, 0.0
    pts = verts[m]
    return (float(np.abs(pts[:, 0]).max()), float((pts[:, 2].max() - pts[:, 2].min()) / 2),
            float((pts[:, 2].max() + pts[:, 2].min()) / 2))


def kurta(c, verts, J, mats):
    """The kurta's skirt: from the waist (where the body's own top ends) to below the knee."""
    waist = lines(c, J)["waist"] + 0.02
    knee = J["lowerleg01.L____head"][1]
    hip = J["upperleg01.L____head"][1]
    rx_h, rz_h, cz = body_width(verts, hip - 0.04, legs=True)
    prof = []
    for y in np.linspace(waist, knee - 0.08, 10):
        if y > hip:
            rx, rz, _ = body_width(verts, float(y))
        else:
            grow = 1.0 + 0.35 * (hip - y)
            rx, rz = rx_h * grow, rz_h * grow
        prof.append((float(y), rx + 0.014, rz + 0.014))
    ob = lathe("kurta", prof, cz, ripple=lambda a, y: 0.03 * math.sin(a * 9) * float(smoothstep(hip, knee, y)))
    ob.data.materials.append(mats["top"])
    return ob


def nehru_jacket(c, verts, J, mats):
    top = J["neck01____head"][1] - 0.035
    bottom = lines(c, J)["waist"] - 0.06
    prof = []
    for y in np.linspace(top, bottom, 10):
        rx, rz, cz = body_width(verts, float(y))
        prof.append((float(y), rx + 0.03, rz + 0.03))
    ob = lathe("jacket", prof, body_width(verts, float((top + bottom) / 2))[2])
    ob.data.materials.append(mats["jacket"])
    return ob


def saree(c, verts, J, mats):
    waist = lines(c, J)["waist"] + 0.03
    hip = J["upperleg01.L____head"][1]
    knee = J["lowerleg01.L____head"][1]

    def pleats(a, y):
        front = math.exp(-((a - math.pi) ** 2) / (2 * 0.3 ** 2))
        return 0.06 * front * math.sin(a * 30) * float(smoothstep(hip, 0.25, y))
    rx_w, rz_w, cz = body_width(verts, waist)
    rx_h, rz_h, _ = body_width(verts, hip - 0.05, legs=True)
    prof = [(waist, rx_w + 0.008, rz_w + 0.008), (hip - 0.05, rx_h + 0.012, rz_h + 0.012),
            (knee, rx_h + 0.02, rz_h + 0.025), (0.12, rx_h + 0.03, rz_h + 0.04), (0.015, rx_h + 0.032, rz_h + 0.042)]
    ob = lathe("saree", prof, cz, ripple=pleats)
    ob.data.materials.append(mats["saree"])
    ob.data.materials.append(mats["border"])
    for poly in ob.data.polygons:
        if poly.center.z < 0.09:  # blender z is up
            poly.material_index = 1
    return ob


def pallu(c, verts, J, mats):
    """The saree's loose end: from the right hip across the chest, over the left shoulder
    and down the back, lying close on the blouse."""
    sh = J["upperarm01.L____head"]
    waist = lines(c, J)["waist"] + 0.03
    pts = []
    for t in np.linspace(0, 1, 9):          # front: right hip -> left shoulder
        x = -sh[0] * (0.75 - 1.6 * t) * 1.0
        y = waist + (sh[1] + 0.02 - waist) * t
        rx, rz, cz = body_width(verts, float(min(y, sh[1] - 0.02)))
        pts.append((x * 0.9, y, cz - rz - 0.012))
    for t in np.linspace(0.15, 1, 7):        # back: down from the left shoulder
        y = sh[1] + 0.02 - (sh[1] + 0.02 - (waist - 0.3)) * t
        rx, rz, cz = body_width(verts, float(min(y, sh[1] - 0.02)), legs=y < waist)
        pts.append((sh[0] * 0.8, y, cz + rz + 0.012))
    bm = bmesh.new()
    rows = []
    for i, p in enumerate(pts):
        nxt, prv = pts[min(i + 1, len(pts) - 1)], pts[max(i - 1, 0)]
        tang = (Vector(nxt) - Vector(prv)).normalized()
        normal = Vector((0, 0, -1 if i < 9 else 1))
        side = tang.cross(normal).normalized()
        w = 0.09 if i < 9 else 0.12
        rows.append([bm.verts.new(g2b(Vector(p) + side * k * w)) for k in (-1, -0.5, 0, 0.5, 1)])
    for r0, r1 in zip(rows, rows[1:]):
        for k in range(4):
            bm.faces.new((r0[k], r0[k + 1], r1[k + 1], r1[k]))
    me = bpy.data.meshes.new("pallu")
    bm.to_mesh(me)
    bm.free()
    ob = link("pallu", me)
    sol = ob.modifiers.new("solid", "SOLIDIFY")
    sol.thickness = 0.004
    sub = ob.modifiers.new("sub", "SUBSURF")
    sub.levels = 1
    apply_modifiers(ob)
    for poly in ob.data.polygons:
        poly.use_smooth = True
    ob.data.materials.append(mats["saree"])
    return ob


def bun(c, verts, J, mats):
    h = J["head____head"]
    e = J["eye.L____head"]
    bm = bmesh.new()
    bmesh.ops.create_uvsphere(bm, u_segments=20, v_segments=14, radius=1.0)
    for v in bm.verts:
        v.co = g2b((v.co.x * 0.04, e[1] - 0.015 + v.co.z * 0.034, e[2] + 0.205 - v.co.y * 0.03))
    me = bpy.data.meshes.new("bun")
    bm.to_mesh(me)
    bm.free()
    ob = link("bun", me)
    for poly in ob.data.polygons:
        poly.use_smooth = True
    ob.data.materials.append(mats["hair"])
    ob["bone"] = "Head"
    return ob


# ------------------------------------------------------------------------ build

def make_part(name, verts, faces, idx, zone_names, mats, colors=None, uvs=None):
    """A mesh from faces[idx] with one material per zone name; returns (object, order) where
    order maps the part's vertices to the source vertex indices."""
    vmap, order = {}, []
    sel = [faces[i] for i in idx]
    for _, vi, _ in sel:
        for v in vi:
            if v not in vmap:
                vmap[v] = len(order)
                order.append(v)
    me = bpy.data.meshes.new(name)
    me.from_pydata([tuple(g2b(verts[v])) for v in order], [], [[vmap[v] for v in vi] for _, vi, _ in sel])
    used = []
    for i in idx:
        if zone_names[i] not in used:
            used.append(zone_names[i])
    for z in used:
        me.materials.append(mats[z])
    for poly, i in zip(me.polygons, idx):
        poly.material_index = used.index(zone_names[i])
        poly.use_smooth = True
    if uvs is not None:
        uv = me.uv_layers.new(name="UVMap")
        li = 0
        for _, _, ti in sel:
            for t in ti:
                uv.data[li].uv = uvs[t] if t >= 0 else (0.0, 0.0)
                li += 1
    if colors is not None:
        attr = me.color_attributes.new("Color", "FLOAT_COLOR", "POINT")
        for k, v in enumerate(order):
            attr.data[k].color = (*colors[v], 1.0)
    return link(name, me), order


def skin_part(ob, order, W, bones, arm):
    for b in bones:
        ob.vertex_groups.new(name=b)
    for new_i, old_i in enumerate(order):
        w = W[old_i]
        top = np.argsort(-w)[:4]
        tot = w[top].sum()
        if tot <= 0:
            ob.vertex_groups["Head"].add([new_i], 1.0, "REPLACE")
            continue
        for k in top:
            if w[k] > 0.002:
                ob.vertex_groups[bones[k]].add([new_i], float(w[k] / tot), "REPLACE")
    m = ob.modifiers.new("rig", "ARMATURE")
    m.object = arm
    ob.parent = arm


def decimate(ob, ratio, protect=None):
    """Fewer triangles; vertices in group `protect` (weight 1) are kept."""
    dec = ob.modifiers.new("dec", "DECIMATE")
    dec.ratio = ratio
    if protect:
        dec.vertex_group = protect
        dec.invert_vertex_group = True
        dec.vertex_group_factor = 1.0
    dec.use_symmetry = True
    dec.symmetry_axis = "X"
    rig = [m for m in ob.modifiers if m.type == "ARMATURE"]
    for m in rig:
        ob.modifiers.move(ob.modifiers.find(m.name), len(ob.modifiers) - 1)
        m.show_viewport = False
    dg = bpy.context.evaluated_depsgraph_get()
    me = bpy.data.meshes.new_from_object(ob.evaluated_get(dg), preserve_all_data_layers=True, depsgraph=dg)
    old = ob.data
    ob.modifiers.remove(dec)
    ob.data = me
    bpy.data.meshes.remove(old)
    for m in rig:
        m.show_viewport = True
    for poly in ob.data.polygons:
        poly.use_smooth = True


def bake_skin(ob, c, size=1024):
    """The painted vertex colours -> a UV texture (works the same on every renderer and
    compresses like any texture); the mesh then carries no vertex colours. Rasterised here
    with numpy (Cycles baking returns black in the headless Linux build)."""
    me = ob.data
    me.calc_loop_triangles()
    uv_layer = me.uv_layers.active.data
    col = me.color_attributes["Color"].data
    tex = np.zeros((size, size, 3))
    filled = np.zeros((size, size), bool)
    for tri in me.loop_triangles:
        uv = np.array([uv_layer[l].uv for l in tri.loops]) * size - 0.5
        cl = np.array([col[v].color[:3] for v in tri.vertices])
        x0, y0 = np.floor(uv.min(axis=0)).astype(int)
        x1, y1 = np.ceil(uv.max(axis=0)).astype(int)
        x0, y0 = max(x0, 0), max(y0, 0)
        x1, y1 = min(x1, size - 1), min(y1, size - 1)
        if x1 < x0 or y1 < y0:
            continue
        gx, gy = np.meshgrid(np.arange(x0, x1 + 1), np.arange(y0, y1 + 1))
        (ax, ay), (bx, by), (cx, cy) = uv
        den = (by - cy) * (ax - cx) + (cx - bx) * (ay - cy)
        if abs(den) < 1e-12:
            continue
        w0 = ((by - cy) * (gx - cx) + (cx - bx) * (gy - cy)) / den
        w1 = ((cy - ay) * (gx - cx) + (ax - cx) * (gy - cy)) / den
        w2 = 1 - w0 - w1
        inside = (w0 >= -0.02) & (w1 >= -0.02) & (w2 >= -0.02)
        if not inside.any():
            continue
        rgb = w0[..., None] * cl[0] + w1[..., None] * cl[1] + w2[..., None] * cl[2]
        ys, xs = gy[inside], gx[inside]
        tex[ys, xs] = rgb[inside]
        filled[ys, xs] = True
    # pad the islands so mip-maps and filtering never pull in black
    for _ in range(12):
        grow = ~filled
        acc = np.zeros_like(tex)
        cnt = np.zeros((size, size))
        for dy, dx in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            sh_t = np.roll(tex, (dy, dx), axis=(0, 1))
            sh_f = np.roll(filled, (dy, dx), axis=(0, 1))
            acc += sh_t * sh_f[..., None]
            cnt += sh_f
        newly = grow & (cnt > 0)
        tex[newly] = acc[newly] / cnt[newly][:, None]
        filled |= newly
    srgb = np.where(tex <= 0.0031308, tex * 12.92, 1.055 * np.power(np.clip(tex, 0, None), 1 / 2.4) - 0.055)
    img = bpy.data.images.new(f"{c['file']}_skin", size, size)
    rgba = np.concatenate([np.clip(srgb, 0, 1), np.ones((size, size, 1))], axis=2)
    img.pixels = rgba.ravel()
    os.makedirs(os.path.join(ROOT, "tools", "_build", "bakes"), exist_ok=True)
    img.filepath_raw = os.path.join(ROOT, "tools", "_build", "bakes", f"{c['file']}_skin.png")
    img.file_format = "PNG"
    img.save()
    mat = me.materials[0]
    nt = mat.node_tree
    node = nt.nodes.new("ShaderNodeTexImage")
    node.image = img
    nt.links.new(node.outputs["Color"], nt.nodes["Principled BSDF"].inputs["Base Color"])
    me.color_attributes.remove(me.color_attributes["Color"])


def shoe(c, verts, faces, zone, side_sign, mats, J):
    """A shoe (or chappal sole) around one foot: the convex hull of the foot, rounded."""
    foot = sorted({v for (_, vi, _), zn in zip(faces, zone) if zn == "foot" for v in vi
                   if np.sign(verts[v, 0]) == side_sign})
    pts = verts[foot]
    if c.get("chappals"):
        pts = pts[pts[:, 1] < 0.03].copy()
        pts = np.vstack([pts * [1.04, 0, 1.04], pts * [1.04, 0, 1.04] + [0, 0.012, 0]])
        pts[:, 0] += (pts[:, 0] - pts[:, 0].mean()) * 0.06
    else:
        ctr = pts.mean(axis=0)
        pts = ctr + (pts - ctr) * 1.08 + [0, 0.002, 0]
        pts[:, 1] = np.maximum(pts[:, 1], 0.0)
    bm = bmesh.new()
    for p in pts:
        bm.verts.new(g2b(p))
    bmesh.ops.convex_hull(bm, input=bm.verts)
    me = bpy.data.meshes.new("shoe")
    bm.to_mesh(me)
    bm.free()
    ob = link(f"shoe{'L' if side_sign < 0 else 'R'}", me)
    sub = ob.modifiers.new("sub", "SUBSURF")
    sub.levels = 1
    apply_modifiers(ob)
    for poly in ob.data.polygons:
        poly.use_smooth = True
    ob.data.materials.append(mats["shoes"])
    ob["bone"] = f"Knee{'L' if side_sign < 0 else 'R'}"
    return ob


def build(c):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    raw, faces, uvs = load_obj()
    shaped = apply_macros(raw, c)
    body_v = sorted({v for g, vi, _ in faces if g == "body" for v in vi})
    ground = shaped[body_v, 1].min()
    verts = to_game(shaped, ground)
    J = {k: to_game(v[None, :], ground)[0] for k, v in joints(shaped).items()}
    faces = [f for f in faces if f[0] in ("body", "helper-l-eye", "helper-r-eye")]
    bones, W = game_weights(len(verts))
    verts, J = repose(verts, J, W, bones, c)
    ground2 = verts[body_v, 1].min()
    verts[:, 1] -= ground2
    J = {k: v - np.array([0, ground2, 0]) for k, v in J.items()}
    zone = zone_faces(c, verts, faces, W, bones, J)
    verts = snap_seams(verts, faces, zone, c, J)
    normals = vertex_normals(verts, faces)
    head_w = W[:, [bones.index(b) for b in ("Head", "EyelidL", "EyelidR")]].sum(axis=1)
    colors, swell = face_paint(c, verts, normals, J, head_w)
    skin_verts = verts + swell
    cloth_verts = push_cloth(verts, normals, faces, zone, c, J)

    cols = c["colors"]
    mats = {
        "skin": material(f"{c['name']}_skin", (1.0, 1.0, 1.0), 0.55),
        "top": material(f"{c['name']}_top", cols["top"], c.get("top_rough", 0.9)),
        "legs": material(f"{c['name']}_legs", cols["legs"], 0.85),
        "shoes": material(f"{c['name']}_shoes", cols["shoes"], 0.5),
        "eye": material(f"{c['name']}_eye", (0.78, 0.76, 0.72), 0.15),
        "iris": material(f"{c['name']}_iris", c.get("iris", (0.1, 0.07, 0.05)), 0.1),
        "hair": material(f"{c['name']}_hair", cols["hair"], 0.95),
    }
    for k, v in c.get("extra_colors", {}).items():
        mats[k] = material(f"{c['name']}_{k}", v[0], v[1])

    # --- armature
    arm_data = bpy.data.armatures.new(c["name"] + "_rig")
    arm = link(c["name"], arm_data)
    bpy.context.view_layer.objects.active = arm
    bpy.ops.object.mode_set(mode="EDIT")
    pos = {b: J[f"{BONE_AT[b]}____head"] for b in BONE_AT}
    for b in PARENTS:
        eb = arm_data.edit_bones.new(b)
        eb.head = g2b(pos[b])
        eb.tail = g2b(pos[b] + np.array([0.0, 0.05, 0.0]))
    for b, p in PARENTS.items():
        if p:
            arm_data.edit_bones[b].parent = arm_data.edit_bones[p]
    bpy.ops.object.mode_set(mode="OBJECT")

    # --- parts: skin (vertex-coloured), clothes, eyes; feet hide inside shoes
    idx_skin = [i for i, z in enumerate(zone) if z == "skin" or (z == "foot" and c.get("chappals"))]
    idx_cloth = [i for i, z in enumerate(zone) if z in CLOTH]
    idx_eyes = [i for i, z in enumerate(zone) if z in ("eye", "iris")]
    zone_mat = ["skin" if z == "foot" else z for z in zone]
    skin, o_skin = make_part(c["name"] + "_skin", skin_verts, faces, idx_skin, zone_mat, mats, colors, uvs)
    cloth, o_cloth = make_part(c["name"] + "_clothes", cloth_verts, faces, idx_cloth, zone_mat, mats)
    eyes, o_eyes = make_part(c["name"] + "_eyes", verts, faces, idx_eyes, zone_mat, mats)
    for ob, order in ((skin, o_skin), (cloth, o_cloth), (eyes, o_eyes)):
        skin_part(ob, order, W, bones, arm)
    # lighter: keep the face (and hands) dense
    keep = skin.vertex_groups.new(name="_keep")
    hcols = [bones.index(b) for b in ("Head", "EyelidL", "EyelidR", "ElbowL", "ElbowR")]
    for new_i, old_i in enumerate(o_skin):
        keep.add([new_i], float(min(1.0, W[old_i, hcols[:3]].sum() * 1.0)), "REPLACE")
    decimate(skin, c.get("skin_detail", 0.5), "_keep")
    skin.vertex_groups.remove(skin.vertex_groups["_keep"])
    bake_skin(skin, c)
    decimate(cloth, c.get("cloth_detail", 0.3))

    # --- garments, shoes and rigid extras
    hip_y = J["upperleg01.L____head"][1]
    waist_y = J["spine03____head"][1]
    shoulder_y = J["upperarm01.L____head"][1]
    global TORSO, LEGS
    tcols = [bones.index(b) for b in ("Pelvis", "Chest", "Neck")]
    lcols = [bones.index(b) for b in ("HipL", "HipR", "KneeL", "KneeR")]
    TORSO = W[:, tcols].sum(axis=1) > 0.5
    LEGS = W[:, lcols].sum(axis=1) > 0.5
    extras = [fn(c, cloth_verts, J, mats) for fn in c.get("garments", [])]
    extras += [shoe(c, verts, faces, zone, s, mats, J) for s in (-1.0, 1.0)]
    for g in extras:
        for b in bones:
            g.vertex_groups.new(name=b)
        for v in g.data.vertices:
            x, y = v.co.x, v.co.z
            if g.get("bone"):
                g.vertex_groups[g["bone"]].add([v.index], 1.0, "REPLACE")
                continue
            side = "L" if x < 0 else "R"
            if y > waist_y:
                up = float(smoothstep(waist_y, waist_y + 0.15, y))
                sh = 0.3 * float(smoothstep(shoulder_y - 0.06, shoulder_y, y)) * float(smoothstep(0.1, 0.15, abs(x)))
                g.vertex_groups["Chest"].add([v.index], up * (1 - sh), "REPLACE")
                g.vertex_groups["Pelvis"].add([v.index], 1 - up, "REPLACE")
                if sh > 0:
                    g.vertex_groups[f"Shoulder{side}"].add([v.index], sh, "REPLACE")
            else:
                swing = float(smoothstep(hip_y, hip_y - 0.5, y)) * 0.45 * float(smoothstep(0.0, 0.08, abs(x)))
                g.vertex_groups["Pelvis"].add([v.index], 1 - swing, "REPLACE")
                g.vertex_groups[f"Hip{side}"].add([v.index], swing, "REPLACE")
        m = g.modifiers.new("rig", "ARMATURE")
        m.object = arm
        g.parent = arm

    os.makedirs(OUT, exist_ok=True)
    path = os.path.join(OUT, c["file"] + ".glb")
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.export_scene.gltf(filepath=path, export_format="GLB", use_selection=True, export_skins=True,
                              export_animations=False, export_yup=True, export_apply=False,
                              export_colors=False, export_image_format="AUTO")
    def front_z(y, xr=0.06):
        m = (np.abs(cloth_verts[:, 1] - y) < 0.012) & (np.abs(cloth_verts[:, 0]) < xr) & TORSO
        return round(float(cloth_verts[m, 2].min()), 4) if m.any() else 0.0
    waist = lines(c, J)["waist"]
    chest_y = float(J["upperarm01.L____head"][1] - 0.1)
    headv = np.where(head_w > 0.9)[0]
    temple = headv[np.abs(skin_verts[headv, 1] - (J["eye.L____head"][1] + 0.045)) < 0.008]
    head_half_width = round(float(np.abs(skin_verts[temple, 0]).max()), 4)
    eye_mid = (J["eye.L____head"] + J["eye.R____head"]) / 2
    anchors = {
        "eye": [round(float(x), 4) for x in eye_mid],
        "chest_y": round(chest_y, 4), "chest_front_z": front_z(chest_y, 0.11),
        "waist_y": round(float(waist), 4), "waist_front_z": front_z(waist),
        "waist_half_width": round(body_width(cloth_verts, float(waist))[0], 4),
        "waist_half_depth": round(body_width(cloth_verts, float(waist))[1], 4),
        "shoulder_top_y": round(float(J["upperarm01.L____head"][1] + 0.045), 4),
        "crown_y": round(float(skin_verts[body_v, 1].max()), 4),
        "head_half_width": head_half_width,
        "head_back_z": round(float(skin_verts[headv, 2].max()), 4),
        "chest_half_width": round(body_width(cloth_verts, chest_y)[0], 4),
        "chest_back_z": round(body_width(cloth_verts, chest_y)[2] + body_width(cloth_verts, chest_y)[1], 4),
        "waist_back_z": round(body_width(cloth_verts, float(waist))[2] + body_width(cloth_verts, float(waist))[1], 4),
        "wrist_y": round(float(J["wrist.L____head"][1]), 4),
    }
    info = {"anchors": anchors, "pivots": {b: [round(float(x), 4) for x in pos[b]] for b in pos},
            "height": round(float(skin_verts[body_v, 1].max()), 3),
            "eye_y": round(float(J["eye.L____head"][1]), 4)}
    with open(os.path.join(OUT, c["file"] + ".json"), "w") as f:
        json.dump(info, f, indent=1)
    tris = sum(len(p.vertices) - 2 for o in [skin, cloth, eyes] + extras for p in o.data.polygons)
    print(f"BUILT {path}  ~{tris} tris  height {info['height']} m")


SOUTH_ASIAN = {"caucasian": 0.45, "african": 0.3, "asian": 0.25}

CHARACTERS = {
    "raghu": dict(name="Raghu", file="raghu", gender=1.0, age_years=52, muscle=0.55, weight=0.6, height=0.4,
                  race=SOUTH_ASIAN, hair="short", sleeve="short", moustache=1.0, stubble=0.5, tired=0.6,
                  colors={"skin": (0.38, 0.26, 0.18), "top": (0.47, 0.41, 0.27), "legs": (0.36, 0.31, 0.2),
                          "shoes": (0.05, 0.045, 0.04), "hair": (0.1, 0.09, 0.09)}),
    "deshmukh": dict(name="Deshmukh", file="deshmukh", gender=1.0, age_years=72, muscle=0.3, weight=0.62,
                     height=0.35, race=SOUTH_ASIAN, hair="bald_crown", sleeve="full", chappals=True,
                     brow_color=(0.75, 0.75, 0.73),
                     colors={"skin": (0.47, 0.33, 0.24), "top": (0.86, 0.85, 0.8), "legs": (0.86, 0.85, 0.8),
                             "shoes": (0.3, 0.2, 0.12), "hair": (0.82, 0.82, 0.8)},
                     extra_colors={"jacket": ((0.28, 0.27, 0.25), 0.8)}, garments=[kurta, nehru_jacket]),
    "iyer": dict(name="Iyer", file="iyer", gender=0.0, age_years=63, muscle=0.35, weight=0.6, height=0.3,
                 race=SOUTH_ASIAN, hair="short", hair_line=0.07, hair_thickness=0.011, sleeve="short",
                 chappals=True, brow_amount=0.8,
                 colors={"skin": (0.45, 0.31, 0.22), "top": (0.42, 0.08, 0.12), "legs": (0.1, 0.3, 0.2),
                         "shoes": (0.25, 0.15, 0.1), "hair": (0.42, 0.41, 0.4)},
                 extra_colors={"saree": ((0.1, 0.3, 0.2), 0.7), "border": ((0.8, 0.62, 0.22), 0.35)},
                 garments=[saree, pallu, bun]),
    "cameraman": dict(name="Cameraman", file="cameraman", gender=1.0, age_years=40, muscle=0.35, weight=0.25,
                      height=0.6, race=SOUTH_ASIAN, hair="short", sleeve="full", open_collar=False,
                      stubble=0.8, tired=0.9,
                      iris=(0.02, 0.02, 0.02), cloth_offset=0.009, top_rough=1.0,
                      colors={"skin": (0.36, 0.3, 0.26), "top": (0.36, 0.36, 0.36), "legs": (0.1, 0.1, 0.11),
                              "shoes": (0.03, 0.03, 0.035), "hair": (0.04, 0.04, 0.04)}),
}


if __name__ == "__main__":
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    for key in argv or CHARACTERS:
        build(CHARACTERS[key])
