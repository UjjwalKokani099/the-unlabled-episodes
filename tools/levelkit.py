"""UNLABELED level kit: writes Godot .tscn levels out of reusable building pieces.

Every tape's level generator imports this. Pieces (all axis-aligned, metres, storey = 3 m):
    lv.box(...)            any box (visual + optional collision)
    wall(...)              a wall with window / door / vent openings; two skins (out / in)
    slab(...)              floor + ceiling skin
    stair_flight(...)      visual steps + smooth ramp collision
    railing(...)           posts + rails (level or sloped)
    window_fill(...)       frame, glass (dark or lit), grill bars
    residential_wing(...)  a whole G+4 Indian housing-society wing (stilt parking, stair core,
                           one flat per floor with balcony, terrace with stair cabin and tank)
Static geometry goes under a StaticBatcher node ("Static") which merges it at runtime.
Collision goes under one StaticBody3D ("Collision").
"""
import math
import os

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
STOREY = 3.0


def r(v: float) -> float:
    return round(v, 4)


def v3(x, y, z) -> str:
    return f"Vector3({r(x)}, {r(y)}, {r(z)})"


class Level:
    def __init__(self, root_name: str, root_script: str | None = None):
        self.ext_res = {}      # path -> (kind, id)
        self.subs = []         # text blocks
        self.nodes = []        # text blocks
        self.names = {}        # parent -> set of child names
        self._box_meshes = {}
        self._box_shapes = {}
        self._mesh_count = 0
        self._shape_count = 0
        props = {}
        if root_script:
            props["script"] = f'ExtResource("{self.ext(root_script, "Script")}")'
        self.nodes.append(self._node_text(root_name, "Node3D", None, props))
        self.add("Static", "Node3D", ".", {"script": f'ExtResource("{self.ext("res://scripts/kit/static_batcher.gd", "Script")}")'})
        self.add("Collision", "StaticBody3D", ".")

    # ------------------------------------------------------------------ resources
    def ext(self, path: str, kind: str) -> str:
        if path not in self.ext_res:
            self.ext_res[path] = (kind, f"{len(self.ext_res) + 1}_r")
        return self.ext_res[path][1]

    def mat(self, name: str) -> str:
        return f'ExtResource("{self.ext(f"res://assets/materials/{name}.tres", "Material")}")'

    def sub(self, kind: str, props: dict, key=None) -> str:
        sid = f"{kind}_{len(self.subs)}"
        lines = [f'[sub_resource type="{kind}" id="{sid}"]'] + [f"{k} = {v}" for k, v in props.items()]
        self.subs.append("\n".join(lines) + "\n")
        return sid

    def _box_mesh(self, size) -> str:
        key = tuple(r(s) for s in size)
        if key not in self._box_meshes:
            self._box_meshes[key] = self.sub("BoxMesh", {"size": v3(*key)})
        return self._box_meshes[key]

    def _box_shape(self, size) -> str:
        key = tuple(r(s) for s in size)
        if key not in self._box_shapes:
            self._box_shapes[key] = self.sub("BoxShape3D", {"size": v3(*key)})
        return self._box_shapes[key]

    # ------------------------------------------------------------------ nodes
    def _node_text(self, name, typ, parent, props, instance=None, groups=None) -> str:
        head = f'[node name="{name}"'
        if typ:
            head += f' type="{typ}"'
        if parent is not None:
            head += f' parent="{parent}"'
        if instance:
            head += f' instance=ExtResource("{instance}")'
        if groups:
            head += " groups=[" + ", ".join(f'"{g}"' for g in groups) + "]"
        return "\n".join([head + "]"] + [f"{k} = {v}" for k, v in props.items()]) + "\n"

    def unique(self, parent: str, base: str) -> str:
        used = self.names.setdefault(parent, set())
        name, n = base, 2
        while name in used:
            name = f"{base}{n}"
            n += 1
        used.add(name)
        return name

    def add(self, name, typ, parent, props=None, instance=None, groups=None) -> str:
        name = self.unique(parent, name)
        self.nodes.append(self._node_text(name, typ, parent, props or {}, instance, groups))
        return name if parent == "." else f"{parent}/{name}"

    def scene(self, name, path, parent, props=None, groups=None) -> str:
        return self.add(name, None, parent, props or {}, instance=self.ext(path, "PackedScene"), groups=groups)

    # ------------------------------------------------------------------ geometry
    def box(self, pos, size, mat: str, collide=True, rot_x=0.0, shadow=True, parent="Static") -> None:
        if min(size) <= 0.0005:
            return
        self._mesh_count += 1
        props = {"position": v3(*pos)}
        if rot_x:
            props["rotation_degrees"] = v3(rot_x, 0, 0)
        props["mesh"] = f'SubResource("{self._box_mesh(size)}")'
        props["material_override"] = self.mat(mat)
        if not shadow:
            props["cast_shadow"] = "0"
        self.nodes.append(self._node_text(f"M{self._mesh_count}", "MeshInstance3D", parent, props))
        if collide:
            self.collider(pos, size)

    def collider(self, pos, size) -> None:
        self._shape_count += 1
        self.nodes.append(self._node_text(f"S{self._shape_count}", "CollisionShape3D", "Collision",
                                          {"position": v3(*pos), "shape": f'SubResource("{self._box_shape(size)}")'}))

    def convex_collider(self, points) -> None:
        self._shape_count += 1
        pts = ", ".join(f"{r(p[0])}, {r(p[1])}, {r(p[2])}" for p in points)
        sid = self.sub("ConvexPolygonShape3D", {"points": f"PackedVector3Array({pts})"})
        self.nodes.append(self._node_text(f"S{self._shape_count}", "CollisionShape3D", "Collision",
                                          {"shape": f'SubResource("{sid}")'}))

    def write(self, path: str) -> None:
        header = ["[gd_scene format=3]", ""]
        for p, (kind, rid) in self.ext_res.items():
            header.append(f'[ext_resource type="{kind}" path="{p}" id="{rid}"]')
        with open(path, "w", encoding="utf-8", newline="\n") as f:
            f.write("\n".join(header) + "\n\n" + "\n".join(self.subs) + "\n" + "\n".join(self.nodes))
        print(f"wrote {os.path.relpath(path, ROOT)}: {self._mesh_count} kit boxes, {self._shape_count} colliders")


# ---------------------------------------------------------------------- walls

def wall(lv: Level, p0, p1, y0, h, t, mat_out, mat_in, out_sign, openings=(), collide=True):
    """Axis-aligned wall between centre-line points p0=(x,z) and p1=(x,z).
    out_sign: +1/-1 = which side (along the perpendicular axis) is "outside".
    openings: dicts with along (centre, absolute coord), w, bottom, top (relative to y0),
    kind ('window' | 'door' | 'vent' | 'hole'), lit (glass material for windows)."""
    along_x = abs(p0[1] - p1[1]) < 1e-6
    a0, a1 = (min(p0[0], p1[0]), max(p0[0], p1[0])) if along_x else (min(p0[1], p1[1]), max(p0[1], p1[1]))
    c = p0[1] if along_x else p0[0]

    def put(a_lo, a_hi, y_lo, y_hi):
        if a_hi - a_lo < 0.01 or y_hi - y_lo < 0.01:
            return
        mid_a, mid_y, length, height = (a_lo + a_hi) / 2, (y_lo + y_hi) / 2, a_hi - a_lo, y_hi - y_lo
        for skin, mat in ((+1, mat_out), (-1, mat_in)):
            off = c + out_sign * skin * t / 4
            if along_x:
                lv.box((mid_a, mid_y, off), (length, height, t / 2), mat, collide=False)
            else:
                lv.box((off, mid_y, mid_a), (t / 2, height, length), mat, collide=False)
        if collide:
            if along_x:
                lv.collider((mid_a, mid_y, c), (length, height, t))
            else:
                lv.collider((c, mid_y, mid_a), (t, height, length))

    ops = sorted(openings, key=lambda o: o["along"])
    cursor = a0
    for o in ops:
        lo, hi = o["along"] - o["w"] / 2, o["along"] + o["w"] / 2
        put(cursor, lo, y0, y0 + h)
        put(lo, hi, y0, y0 + o["bottom"])
        put(lo, hi, y0 + o["top"], y0 + h)
        if o["kind"] in ("window", "vent", "door"):
            window_fill(lv, along_x, c, out_sign, t, o["along"], o["w"], y0 + o["bottom"], y0 + o["top"], o)
        cursor = hi
    put(cursor, a1, y0, y0 + h)


def window_fill(lv, along_x, c, out_sign, t, along, w, y_lo, y_hi, o):
    """Frame (+ glass for windows) (+ grill bars on the outside for windows and vents)."""
    kind = o["kind"]
    frame_mat = o.get("frame", "wood_frame_blue")
    fd = 0.1  # frame depth
    f = 0.06  # frame width

    def at(a, y, depth_off, size_a, size_y, size_d, mat, collide=False):
        if along_x:
            lv.box((a, y, c + depth_off), (size_a, size_y, size_d), mat, collide=collide)
        else:
            lv.box((c + depth_off, y, a), (size_d, size_y, size_a), mat, collide=collide)

    h = y_hi - y_lo
    mid_y = (y_lo + y_hi) / 2
    # frame: sides + top (+ sill for windows)
    at(along - w / 2 + f / 2, mid_y, 0, f, h, fd, frame_mat)
    at(along + w / 2 - f / 2, mid_y, 0, f, h, fd, frame_mat)
    at(along, y_hi - f / 2, 0, w, f, fd, frame_mat)
    if kind == "door":
        return
    at(along, y_lo + f / 2, 0, w, f, fd + 0.04, frame_mat)
    if kind == "window":
        at(along, mid_y, 0, f * 0.6, h - 2 * f, fd * 0.8, frame_mat)  # centre mullion
        glass = o.get("glass", "glass_dark")
        at(along, mid_y, -out_sign * 0.01, w - 2 * f, h - 2 * f, 0.012, glass, collide=True)
    # grill on the outside face
    if o.get("grill", True):
        gx = out_sign * (t / 2 + 0.03)
        bars = max(2, int((w - 0.1) / 0.11))
        for i in range(bars + 1):
            a = along - w / 2 + 0.05 + i * (w - 0.1) / bars
            at(a, mid_y, gx, 0.016, h, 0.016, "metal_gate_green")
        for y in (y_lo + 0.08, mid_y, y_hi - 0.08):
            at(along, y, gx, w, 0.03, 0.008, "metal_gate_green")
        if kind == "vent":
            return


# ---------------------------------------------------------------------- floors / stairs / rails

def slab(lv, x0, x1, z0, z1, y_top, thick, top_mat, bottom_mat, collide=True):
    lv.box(((x0 + x1) / 2, y_top - 0.02, (z0 + z1) / 2), (x1 - x0, 0.04, z1 - z0), top_mat, collide=False)
    lv.box(((x0 + x1) / 2, y_top - thick / 2 - 0.02, (z0 + z1) / 2), (x1 - x0, thick - 0.04, z1 - z0), bottom_mat, collide=False)
    if collide:
        lv.collider(((x0 + x1) / 2, y_top - thick / 2, (z0 + z1) / 2), (x1 - x0, thick, z1 - z0))


def stair_flight(lv, x0, x1, z_start, z_end, y_start, steps, rise, step_mat="floor_kota", under_mat="wall_paint_white"):
    """Steps along Z from z_start to z_end, climbing `steps` x `rise`. Ramp collision."""
    run = (z_end - z_start) / steps
    sign = 1 if run > 0 else -1
    for i in range(steps):
        za, zb = z_start + i * run, z_start + (i + 1) * run
        top = y_start + (i + 1) * rise
        lv.box(((x0 + x1) / 2, top - 0.02, (za + zb) / 2), (x1 - x0, 0.04, abs(run)), step_mat, collide=False)
        lv.box(((x0 + x1) / 2, top - rise / 2 - 0.12, (za + zb) / 2), (x1 - x0, rise + 0.2, abs(run)), under_mat, collide=False)
    y_end = y_start + steps * rise
    lo, th = 0.05, 0.35
    pts = []
    for x in (x0, x1):
        pts += [(x, y_start + lo, z_start), (x, y_end + lo, z_end), (x, y_start - th, z_start), (x, y_end - th, z_end)]
    lv.convex_collider(pts)
    # sloped handrail on the x1 side
    length = math.hypot(z_end - z_start, y_end - y_start)
    angle = math.degrees(math.atan2(y_end - y_start, abs(z_end - z_start)))
    rot = angle if sign < 0 else -angle
    rx = x1 - 0.05
    lv.box((rx, (y_start + y_end) / 2 + 0.95, (z_start + z_end) / 2), (0.05, 0.05, length), "wood_door_varnished", collide=False, rot_x=rot)
    for i in range(0, steps + 1, 3):
        z = z_start + i * run
        y = y_start + i * rise
        lv.box((rx, y + 0.47, z), (0.025, 0.95, 0.025), "metal_gate_green", collide=False)


def railing(lv, p0, p1, y, h=1.0, post_every=1.2, mat="metal_gate_green", collide=True):
    along_x = abs(p0[1] - p1[1]) < 1e-6
    length = abs(p1[0] - p0[0]) if along_x else abs(p1[1] - p0[1])
    cx, cz = (p0[0] + p1[0]) / 2, (p0[1] + p1[1]) / 2
    size_top = (length, 0.05, 0.05) if along_x else (0.05, 0.05, length)
    lv.box((cx, y + h, cz), size_top, mat, collide=False)
    lv.box((cx, y + h * 0.5, cz), size_top, mat, collide=False)
    n = max(1, int(length / post_every))
    for i in range(n + 1):
        f = i / n
        x = p0[0] + (p1[0] - p0[0]) * f
        z = p0[1] + (p1[1] - p0[1]) * f
        lv.box((x, y + h / 2, z), (0.04, h, 0.04), mat, collide=False)
    if collide:
        lv.collider((cx, y + h / 2, cz), (length, h, 0.1) if along_x else (0.1, h, length))


# ---------------------------------------------------------------------- the residential wing

def residential_wing(lv: Level, name: str, ox: float, oz: float, *, letter: str, exterior: str,
                     core_wall: str = "wall_stairwell_mint", lit_floors=(), tv_floors=(),
                     interior_floor: int | None = None, flicker_floors=(), occluders=True,
                     unlocked_doors=(), door_unlock_events=None) -> dict:
    """A G+4 wing: stilt parking (ground), flats on floors 1-4 (one per floor, number
    '<floor><letter>'), terrace with stair cabin + overhead tank. Footprint 12 x 10 m,
    front faces +Z. Returns useful world positions (door spots, balcony, landings...)."""
    W, D, T = 12.0, 10.0, 0.23
    CORE = 3.0                 # stair core width (x 0..3)
    CORE_BACK = 4.2            # stair core depth starts at z 4.2
    LANDING = 8.4              # floor landing from z 8.4 to 10
    MID_Z = 5.6                # mid landing from 4.2 to 5.6
    STEPS, RISE = 10, 0.15
    info = {"letter": letter, "doors": {}, "landings": {}, "balconies": {}}

    def X(x):
        return ox + x

    def Z(z):
        return oz + z

    group = lv.add(name, "Node3D", ".")

    # ---- ground floor: stilt parking, columns, stair entrance
    for x in (3.0, 7.5, 12.0 - 0.18):
        for z in (0.18, 5.0, 10.0 - 0.18):
            lv.box((X(x), STOREY / 2, Z(z)), (0.35, STOREY, 0.35), exterior)
    lv.box((X(W / 2), -0.02, Z(D / 2)), (W, 0.04, D), "concrete_dirty", collide=False)

    # ---- stair core walls, every storey (ground..4) + terrace cabin
    for fl in range(0, 6):
        y = fl * STOREY
        # left (outer) wall of the core, with a vent at each mid-landing
        vent = [{"along": Z(4.9), "w": 0.9, "bottom": 1.9, "top": 2.8, "kind": "vent"}] if fl < 5 else []
        wall(lv, (X(0), Z(CORE_BACK)), (X(0), Z(D)), y, STOREY, T, exterior, core_wall, -1, vent)
        # back wall of the core (only where there is no flat behind: terrace cabin)
        if fl == 5:
            wall(lv, (X(0), Z(CORE_BACK)), (X(CORE), Z(CORE_BACK)), y, STOREY, T, exterior, core_wall, -1)
        # front wall of the core: entrance at ground, tall jaali vent above, door at terrace
        if fl == 0:
            front_ops = [{"along": X(1.5), "w": 2.0, "bottom": 0, "top": 2.6, "kind": "hole"}]
        else:
            front_ops = [{"along": X(1.5), "w": 0.8, "bottom": 1.0, "top": 2.6, "kind": "vent"}]
        wall(lv, (X(0), Z(D)), (X(CORE), Z(D)), y, STOREY, T, exterior, core_wall, +1, front_ops)
        # right wall of the core = wall between core and flat; flat door on floors 1-4
        if fl in (1, 2, 3, 4):
            door_z = (LANDING + D) / 2
            ops = [{"along": Z(door_z), "w": 1.2, "bottom": 0, "top": 2.2, "kind": "door", "frame": "wood_door_dark"}]
            wall(lv, (X(CORE), Z(CORE_BACK)), (X(CORE), Z(D)), y, STOREY, T, "wall_paint_white", core_wall, +1, ops)
            flat = f"{fl}{letter}"
            info["doors"][flat] = lv.scene(f"Door{flat}", "res://scenes/props/door.tscn", group, {
                "position": v3(X(CORE), y, Z(door_z + 0.55)), "rotation_degrees": v3(0, 90, 0),
                "locked": "false" if flat in unlocked_doors else "true",
                "locked_message": '"Locked. Nobody answers."',
                **({"unlock_event": f'&"{door_unlock_events[flat]}"'} if door_unlock_events and flat in door_unlock_events else {})})
            lv.add(f"Plate{flat}", "Label3D", group, {
                "position": v3(X(CORE - T / 2 - 0.012), y + 1.75, Z(door_z + 0.85)), "rotation_degrees": v3(0, -90, 0),
                "pixel_size": "0.0016", "shaded": "true", "modulate": "Color(0.72, 0.55, 0.2, 1)",
                "outline_size": "0", "font_size": "64", "text": f'"{flat}"'})
        elif fl == 0:
            wall(lv, (X(CORE), Z(CORE_BACK)), (X(CORE), Z(D)), y, STOREY, T, exterior, core_wall, +1)
            # under-stair back wall at ground
            wall(lv, (X(0), Z(CORE_BACK)), (X(CORE), Z(CORE_BACK)), y, STOREY, T, exterior, core_wall, -1)
        else:  # terrace cabin: door out to the terrace on the right side
            ops = [{"along": Z(9.0), "w": 1.1, "bottom": 0, "top": 2.15, "kind": "door", "frame": "wood_door_dark"}]
            wall(lv, (X(CORE), Z(CORE_BACK)), (X(CORE), Z(D)), y, STOREY, T, exterior, core_wall, +1, ops)
            info["terrace_door"] = lv.scene("TerraceDoor", "res://scenes/props/door.tscn", group, {
                "position": v3(X(CORE), y, Z(9.0 + 0.55)), "rotation_degrees": v3(0, 90, 0)})
            slab(lv, X(0), X(CORE), Z(LANDING), Z(D), y, 0.15, "floor_kota", "wall_paint_white")

        # landings + flights (from storey fl to fl+1), for fl 0..4
        if fl <= 4:
            slab(lv, X(0), X(CORE), Z(LANDING), Z(D), y, 0.15 if fl else 0.05, "floor_kota", "wall_paint_white")
            lv.add(f"Landing{fl}", "Marker3D", group, {"position": v3(X(1.5), y, Z(9.2))}, groups=["patrol_points"])
            info["landings"][fl] = (X(1.5), y, Z(9.2))
            stair_flight(lv, X(0.12), X(1.42), Z(LANDING), Z(MID_Z), y, STEPS, RISE)
            slab(lv, X(0.12), X(CORE - 0.12), Z(CORE_BACK + 0.05), Z(MID_Z), y + 1.5, 0.15, "floor_kota", "wall_paint_white")
            stair_flight(lv, X(1.58), X(CORE - 0.12), Z(MID_Z), Z(LANDING), y + 1.5, STEPS, RISE)
            # landing ceiling tube light
            lv.scene("Tube", "res://scenes/props/tube_light.tscn", group,
                     {"position": v3(X(1.5), y + STOREY - 0.06, Z(9.3)),
                      "flicker": "0.7" if fl in flicker_floors else "0.0"})
    # terrace cabin roof + overhead water tank on it
    top = 5 * STOREY
    slab(lv, X(0), X(CORE), Z(CORE_BACK), Z(D), top + STOREY, 0.15, "concrete_dark", "wall_paint_white")
    lv.box((X(1.5), top + STOREY + 0.35, Z(7.1)), (2.6, 0.5, 2.6), "concrete_dirty")   # tank stand
    lv.box((X(1.5), top + STOREY + 1.35, Z(7.1)), (2.4, 1.5, 2.4), "concrete_dirty")   # tank
    lv.box((X(1.5), top + STOREY + 2.12, Z(7.1)), (0.6, 0.06, 0.6), "metal_rust")       # manhole lid

    # ---- flats, floors 1-4
    for fl in range(1, 5):
        y = fl * STOREY
        lit = fl in lit_floors
        glass = "glass_lit_tv" if fl in tv_floors else ("glass_lit_warm" if lit else "glass_dark")
        win = lambda along, w=1.2, g=glass: {"along": along, "w": w, "bottom": 0.9, "top": 2.1, "kind": "window", "glass": g}
        inner = "wall_paint_cream" if fl == interior_floor else "wall_paint_white"
        # floor slab over the flat area (+ behind the core)
        slab(lv, X(CORE), X(W), Z(0), Z(D), y, 0.15, "floor_mosaic", "wall_paint_white")
        slab(lv, X(0), X(CORE), Z(0), Z(CORE_BACK), y, 0.15, "floor_mosaic", "wall_paint_white")
        # back wall (z=0) whole width
        wall(lv, (X(0), Z(0)), (X(W), Z(0)), y, STOREY, T, exterior, inner, -1, [win(X(1.5)), win(X(5.5)), win(X(9.5))])
        # right wall (x=W)
        wall(lv, (X(W), Z(0)), (X(W), Z(D)), y, STOREY, T, exterior, inner, +1, [win(Z(2.5), 1.0), win(Z(7.5), 1.0)])
        # left wall behind the core (x=0, z 0..4.2)
        wall(lv, (X(0), Z(0)), (X(0), Z(CORE_BACK)), y, STOREY, T, exterior, inner, -1, [win(Z(2.1), 1.0)])
        # wall between flat and core (back of the core, z=4.2, x 0..3)
        wall(lv, (X(0), Z(CORE_BACK)), (X(CORE), Z(CORE_BACK)), y, STOREY, T, core_wall, inner, +1)
        # front wall (z=D) of the flat: balcony door + window
        bal_door = {"along": X(9.0), "w": 1.1, "bottom": 0, "top": 2.2, "kind": "door", "frame": "wood_frame_blue"}
        wall(lv, (X(CORE), Z(D)), (X(W), Z(D)), y, STOREY, T, exterior, inner, +1, [win(X(5.2)), bal_door])
        # balcony: slab, parapet, grill to the top rail
        slab(lv, X(6.6), X(11.6), Z(D), Z(D + 1.3), y, 0.15, "floor_kota", exterior)
        wall(lv, (X(6.6), Z(D + 1.2)), (X(11.6), Z(D + 1.2)), y, 0.95, 0.12, exterior, exterior, +1)
        wall(lv, (X(11.55), Z(D)), (X(11.55), Z(D + 1.2)), y, 0.95, 0.12, exterior, exterior, +1)
        wall(lv, (X(6.65), Z(D)), (X(6.65), Z(D + 1.2)), y, 0.95, 0.12, exterior, exterior, -1)
        railing(lv, (X(6.6), Z(D + 1.2)), (X(11.6), Z(D + 1.2)), y + 0.95, h=0.6, post_every=0.15, collide=False)
        if fl == 4:  # sunshade (chajja) over the top balcony
            lv.box((X(9.1), y + STOREY + 0.05, Z(D + 0.7)), (5.2, 0.1, 1.4), exterior, collide=False)
        info["balconies"][f"{fl}{letter}"] = (X(9.1), y, Z(D + 0.7))
        # interior partitions for the one explorable flat
        if fl == interior_floor:
            ops_living = [{"along": X(5.25), "w": 1.0, "bottom": 0, "top": 2.15, "kind": "door", "frame": "wood_door_dark"},
                          {"along": X(9.75), "w": 1.0, "bottom": 0, "top": 2.15, "kind": "door", "frame": "wood_door_dark"}]
            wall(lv, (X(CORE), Z(5.0)), (X(W), Z(5.0)), y, STOREY, 0.12, "wall_paint_cream", "wall_paint_cream", +1, ops_living)
            wall(lv, (X(7.5), Z(0)), (X(7.5), Z(5.0)), y, STOREY, 0.12, "wall_paint_cream", "tile_white", +1)
        else:
            # closed flats: occluder so the GPU skips what's behind them
            if occluders:
                occ = lv.sub("BoxOccluder3D", {"size": v3(W - CORE - 0.6, STOREY - 0.4, D - 0.6)})
                lv.add("Occluder", "OccluderInstance3D", group,
                       {"position": v3(X((CORE + W) / 2), y + STOREY / 2, Z(D / 2)), "occluder": f'SubResource("{occ}")'})
    # ---- terrace (roof of floor 4)
    slab(lv, X(CORE), X(W), Z(0), Z(D), top, 0.15, "concrete_dark", "wall_paint_white")
    slab(lv, X(0), X(CORE), Z(0), Z(CORE_BACK), top, 0.15, "concrete_dark", "wall_paint_white")
    for p0, p1, s in (((X(0), Z(0)), (X(W), Z(0)), -1), ((X(W), Z(0)), (X(W), Z(D)), +1),
                      ((X(CORE), Z(D)), (X(W), Z(D)), +1), ((X(0), Z(0)), (X(0), Z(CORE_BACK)), -1)):
        wall(lv, p0, p1, top, 1.0, 0.15, exterior, exterior, s)
    info["terrace"] = (X(7.5), top, Z(5.0))

    # ---- wing name on the core front (English + Devanagari)
    lv.add("WingSign", "Label3D", group, {
        "position": v3(X(1.5), 2.75, Z(D + T / 2 + 0.01)), "pixel_size": "0.006", "shaded": "true",
        "modulate": "Color(0.15, 0.12, 0.1, 1)", "outline_size": "0", "font_size": "48",
        "text": f'"{letter} WING  ·  {letter} विंग"'})
    return info


# ---------------------------------------------------------------------- shared level setup

def night_environment(lv: Level, fog_density=0.012, moon=True) -> None:
    sky_mat = lv.sub("ShaderMaterial", {"shader": f'ExtResource("{lv.ext("res://shaders/sky_city_night.gdshader", "Shader")}")'})
    sky = lv.sub("Sky", {"sky_material": f'SubResource("{sky_mat}")'})
    env = lv.sub("Environment", {
        "background_mode": "2", "sky": f'SubResource("{sky}")',
        "ambient_light_source": "2", "ambient_light_color": "Color(0.35, 0.4, 0.55, 1)",
        "ambient_light_energy": "0.08", "tonemap_mode": "4", "tonemap_exposure": "1.15",
        "ssao_enabled": "true", "ssao_radius": "1.2", "ssao_intensity": "2.0",
        "ssil_enabled": "true", "ssil_radius": "3.0", "ssil_intensity": "0.7",
        "glow_enabled": "true", "glow_intensity": "0.7", "glow_bloom": "0.04", "glow_hdr_threshold": "0.9",
        "fog_enabled": "true", "fog_light_color": "Color(0.06, 0.045, 0.035, 1)", "fog_density": "0.006",
        "volumetric_fog_enabled": "true", "volumetric_fog_density": str(fog_density),
        "volumetric_fog_albedo": "Color(0.9, 0.85, 0.8, 1)", "volumetric_fog_length": "64.0",
    })
    lv.add("WorldEnvironment", "WorldEnvironment", ".", {"environment": f'SubResource("{env}")'})
    if moon:
        lv.add("Moon", "DirectionalLight3D", ".", {
            "rotation_degrees": v3(-38, 35, 0), "light_color": "Color(0.55, 0.65, 0.95, 1)",
            "light_energy": "0.12", "shadow_enabled": "true", "directional_shadow_mode": "1",
            "directional_shadow_max_distance": "60.0", "light_volumetric_fog_energy": "0.3"})


def sodium_lamp(lv: Level, x, z, height=6.0, facing_x=1.0, shadow=False, parent=".") -> None:
    """Street lamp post: pole, arm, lamp head, orange light (fades out with distance)."""
    lv.box((x, height / 2, z), (0.12, height, 0.12), "metal_rust")
    lv.box((x + facing_x * 0.6, height - 0.05, z), (1.2, 0.08, 0.08), "metal_rust", collide=False)
    lv.box((x + facing_x * 1.15, height - 0.15, z), (0.45, 0.12, 0.22), "metal_meter_white", collide=False)
    lv.box((x + facing_x * 1.15, height - 0.23, z), (0.36, 0.04, 0.16), "glass_sodium", collide=False, shadow=False)
    lv.add("SodiumLight", "OmniLight3D", parent, {
        "position": v3(x + facing_x * 1.15, height - 0.4, z), "light_color": "Color(1, 0.55, 0.2, 1)",
        "light_energy": "2.2", "light_size": "0.2", "omni_range": "16.0", "omni_attenuation": "1.4",
        "shadow_enabled": "true" if shadow else "false", "light_volumetric_fog_energy": "1.5",
        "distance_fade_enabled": "true", "distance_fade_begin": "55.0", "distance_fade_length": "15.0"})


def player_rig(lv: Level, x, z, yaw_deg=0.0, y=0.0, flashlight=True, debug=True) -> None:
    lv.scene("Player", "res://scenes/player/player.tscn", ".", {
        "position": v3(x, y, z), "rotation_degrees": v3(0, yaw_deg, 0),
        "flashlight_on_start": "true" if flashlight else "false"})
    lv.scene("Camcorder", "res://ui/hud/camcorder.tscn", ".")
    lv.scene("HUD", "res://ui/hud/hud.tscn", ".")
    if debug:
        lv.add("DebugOverlay", "CanvasLayer", ".", {"layer": "20", "script": f'ExtResource("{lv.ext("res://scripts/ui/debug_overlay.gd", "Script")}")'})
        lv.add("Label", "Label", "DebugOverlay", {
            "offset_left": "70.0", "offset_top": "96.0", "offset_right": "870.0", "offset_bottom": "260.0",
            "theme_override_colors/font_color": "Color(0.85, 0.85, 0.85, 1)",
            "theme_override_colors/font_outline_color": "Color(0, 0, 0, 1)",
            "theme_override_constants/outline_size": "4", "theme_override_font_sizes/font_size": "14"})


def benchmark_points(lv: Level, points) -> None:
    lv.add("BenchmarkPoints", "Node3D", ".")
    for i, (x, y, z) in enumerate(points):
        lv.add(f"P{i}", "Marker3D", "BenchmarkPoints", {"position": v3(x, y, z)}, groups=["benchmark_points"])
