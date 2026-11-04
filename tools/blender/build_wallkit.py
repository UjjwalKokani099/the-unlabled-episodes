"""Blender wall kit (run headless):

    blender -b --factory-startup --python tools/blender/build_wallkit.py

Builds every piece listed in assets/models/wallkit/pieces.json (the level kit adds the
sizes the generators ask for: run the generators, then this, then the generators again)
as assets/models/wallkit/<piece>.obj. Godot imports OBJ as a plain Mesh; tools/levelkit.py
places each piece through one MultiMesh per (piece, material), so hundreds of windows cost
a few draw calls. Every piece is one surface: the level gives it its material (wall paint
for the concrete parts, frame paint, grill metal), so world-space weathering carries on.

Piece frame (Godot axes): x along the wall, y up from the opening's bottom, +z = outside,
z = 0 the wall's centre plane. Names: <kind>_<w cm>x<h cm>_t<thickness cm>.
Kinds: winframe (moulded frame + two casement shutters), grill (Indian MS grill with an arched
middle band), ventgrill (diamond lattice), masonry (plaster surround, sill with drip, lintel
band, sloped chajja sunshade), doorframe (chaukhat with stepped moulding), vent (frame only),
pipe (one storey of drain pipe with socket collar and wall clamp), pipeshoe (bottom bend).
"""
import json
import math
import os

import bmesh
import bpy
from mathutils import Matrix, Vector

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
KIT = os.path.join(ROOT, "assets", "models", "wallkit")


def g2b(x, y, z):
    return Vector((x, -z, y))


# ------------------------------------------------------------------------- geometry

class Piece:
    def __init__(self):
        self.bm = bmesh.new()

    def box(self, centre, size, bevel=0.004):
        """Axis-aligned box (godot axes), edges softened later by the bevel pass."""
        cx, cy, cz = centre
        sx, sy, sz = (s / 2 for s in size)
        verts = [self.bm.verts.new(g2b(cx + dx * sx, cy + dy * sy, cz + dz * sz))
                 for dx in (-1, 1) for dy in (-1, 1) for dz in (-1, 1)]
        idx = [(0, 1, 3, 2), (4, 6, 7, 5), (0, 4, 5, 1), (2, 3, 7, 6), (0, 2, 6, 4), (1, 5, 7, 3)]
        for f in idx:
            self.bm.faces.new([verts[i] for i in f])

    def prism(self, profile, x0, x1):
        """Extrude a (y, z) profile polygon along x from x0 to x1."""
        a = [self.bm.verts.new(g2b(x0, y, z)) for y, z in profile]
        b = [self.bm.verts.new(g2b(x1, y, z)) for y, z in profile]
        n = len(profile)
        self.bm.faces.new(a[::-1])
        self.bm.faces.new(b)
        for i in range(n):
            j = (i + 1) % n
            self.bm.faces.new((a[i], a[j], b[j], b[i]))

    def cylinder(self, p0, p1, r, segs=10):
        p0, p1 = Vector(p0), Vector(p1)
        axis = (p1 - p0).normalized()
        ref = Vector((1, 0, 0)) if abs(axis.x) < 0.9 else Vector((0, 0, 1))
        u = axis.cross(ref).normalized()
        w = axis.cross(u)
        rings = []
        for p in (p0, p1):
            rings.append([self.bm.verts.new(g2b(*(p + (u * math.cos(a) + w * math.sin(a)) * r)))
                          for a in (i / segs * math.tau for i in range(segs))])
        self.bm.faces.new(rings[0][::-1])
        self.bm.faces.new(rings[1])
        for i in range(segs):
            j = (i + 1) % segs
            self.bm.faces.new((rings[0][i], rings[0][j], rings[1][j], rings[1][i]))

    def arc_bar(self, centre, radius, a0, a1, r, z, segs=10):
        """A round bar bent along an arc in the x/y plane at depth z (godot axes)."""
        pts = [Vector((centre[0] + math.cos(a) * radius, centre[1] + math.sin(a) * radius, z))
               for a in (a0 + (a1 - a0) * i / segs for i in range(segs + 1))]
        for p, q in zip(pts, pts[1:]):
            self.cylinder(p, q, r, 4)

    def finish(self, name, bevel=0.004):
        me = bpy.data.meshes.new(name)
        self.bm.normal_update()
        bmesh.ops.recalc_face_normals(self.bm, faces=self.bm.faces)
        self.bm.to_mesh(me)
        self.bm.free()
        ob = bpy.data.objects.new(name, me)
        bpy.context.collection.objects.link(ob)
        if bevel > 0:
            bv = ob.modifiers.new("bevel", "BEVEL")
            bv.width = bevel
            bv.segments = 1
            bv.limit_method = "ANGLE"
            bv.angle_limit = math.radians(50)
        ws = ob.modifiers.new("ws", "WEIGHTED_NORMAL")
        ws.keep_sharp = True
        return ob


# ------------------------------------------------------------------------- pieces

def winframe(w, h, t):
    """Moulded frame set in the outer half of the wall + two closed casement shutters with a
    glazing bar each (the glass pane is the level kit's own box)."""
    p = Piece()
    f, d = 0.065, 0.1        # frame face width, depth
    zc = 0.0                 # centred on the wall plane (the level's glass sits at ~0)
    # frame: jambs, head, sill rail (with a stepped stop on the inside)
    for sx in (-1, 1):
        p.box((sx * (w / 2 - f / 2), h / 2, zc), (f, h, d))
        p.box((sx * (w / 2 - f - 0.006), h / 2, zc - d / 2 + 0.012), (0.012, h - 2 * f, 0.024))
    p.box((0, h - f / 2, zc), (w, f, d))
    p.box((0, f / 2, zc), (w, f, d + 0.03))
    # two shutters: stiles, rails, a glazing bar
    leaf_w = (w - 2 * f) / 2
    s, lz = 0.045, zc + 0.03
    for k in (-1, 1):
        cx = k * leaf_w / 2
        for sx in (-1, 1):
            p.box((cx + sx * (leaf_w / 2 - s / 2), h / 2, lz), (s, h - 2 * f, 0.04))
        for y in (f + s / 2, h - f - s / 2):
            p.box((cx, y, lz), (leaf_w - 2 * s, s, 0.04))
        p.box((cx, h / 2, lz), (leaf_w - 2 * s, 0.025, 0.03))
        p.box((cx + k * -1 * (leaf_w / 2 - s - 0.02), h / 2 - 0.05, lz + 0.03), (0.012, 0.07, 0.02))  # handle
    return p.finish(f"winframe_{int(w * 100)}x{int(h * 100)}_t{int(t * 100)}")


def grill(w, h, t):
    """Indian mild-steel window grill on the outside face: flat-bar frame, round verticals and
    a band of half-round arches across the middle."""
    p = Piece()
    z = t / 2 + 0.035
    fb = 0.025
    for sx in (-1, 1):
        p.box((sx * (w / 2 - fb / 2), h / 2, z), (fb, h, 0.006), bevel=0)
    for y in (fb / 2, h - fb / 2, h * 0.42, h * 0.58):
        p.box((0, y, z), (w, fb, 0.006), bevel=0)
    bars = max(3, int(round((w - 0.1) / 0.12)))
    step = (w - 2 * fb) / bars
    for i in range(1, bars):
        x = -w / 2 + fb + i * step
        p.cylinder((x, fb, z), (x, h * 0.42, z), 0.006, 5)
        p.cylinder((x, h * 0.58, z), (x, h - fb, z), 0.006, 5)
    # arches between the two middle flats
    for i in range(bars):
        x0 = -w / 2 + fb + i * step
        p.arc_bar((x0 + step / 2, h * 0.42), step / 2 - 0.004, 0.0, math.pi, 0.005, z, segs=6)
    # wall lugs
    for sx in (-1, 1):
        for y in (0.1, h - 0.1):
            p.box((sx * (w / 2 + 0.02), y, z - 0.015), (0.05, 0.02, 0.006), bevel=0)
    return p.finish(f"grill_{int(w * 100)}x{int(h * 100)}_t{int(t * 100)}", bevel=0)


def ventgrill(w, h, t):
    """Diamond lattice of flat bars (stairwell vents)."""
    p = Piece()
    z = t / 2 + 0.02
    fb = 0.03
    for sx in (-1, 1):
        p.box((sx * (w / 2 - fb / 2), h / 2, z), (fb, h, 0.008), bevel=0)
    for sy in (fb / 2, h - fb / 2):
        p.box((0, sy, z), (w, fb, 0.008), bevel=0)
    cell = 0.14
    n = int((w + h) / cell) + 2
    for k in range(-n, n + 1):
        for sign in (1, -1):
            # line x = sign*(y - h/2) + k*cell, clipped to the frame
            pts = []
            for y in (fb, h - fb):
                x = sign * (y - h / 2) + k * cell
                pts.append((x, y))
            (xa, ya), (xb, yb) = pts
            lo, hi = -w / 2 + fb, w / 2 - fb
            def clip(xa, ya, xb, yb):
                if xa == xb:
                    return None
                ts = []
                for xc in (lo, hi):
                    tt = (xc - xa) / (xb - xa)
                    ts.append(tt)
                t0, t1 = max(0.0, min(ts)), min(1.0, max(ts))
                if t1 <= t0:
                    return None
                return (xa + (xb - xa) * t0, ya + (yb - ya) * t0, xa + (xb - xa) * t1, ya + (yb - ya) * t1)
            seg = clip(xa, ya, xb, yb)
            if seg:
                x0, y0, x1, y1 = seg
                ln = math.hypot(x1 - x0, y1 - y0)
                if ln < 0.02:
                    continue
                cx, cy = (x0 + x1) / 2, (y0 + y1) / 2
                ang = math.atan2(y1 - y0, x1 - x0)
                b = bmesh.new()
                pc = Piece()
                pc.bm = b
                pc.box((0, 0, 0), (ln, 0.02, 0.006), bevel=0)
                bmesh.ops.transform(b, matrix=Matrix.Rotation(ang, 4, "Y") if False else Matrix.Rotation(-ang, 4, Vector((0, 1, 0))),
                                    verts=b.verts)
                bmesh.ops.translate(b, vec=g2b(cx, cy, z), verts=b.verts)
                me = bpy.data.meshes.new("tmp")
                b.to_mesh(me)
                b.free()
                p.bm.from_mesh(me)
                bpy.data.meshes.remove(me)
    return p.finish(f"ventgrill_{int(w * 100)}x{int(h * 100)}_t{int(t * 100)}", bevel=0)


def masonry(w, h, t, chajja=True):
    """Outside plaster work around a window: a slightly proud surround, a projecting sill with
    a sloped top and a drip groove, a lintel band and a sloped chajja sunshade."""
    p = Piece()
    face = t / 2
    band = 0.075
    # surround (proud 1.2 cm)
    for sx in (-1, 1):
        p.box((sx * (w / 2 + band / 2), h / 2, face + 0.006), (band, h + 2 * band, 0.012))
    p.box((0, h + band / 2, face + 0.006), (w + 2 * band, band, 0.012))
    # sill: sloped top, drip lip underneath
    sill = [(-0.075, face - 0.04), (-0.075, face + 0.07), (-0.06, face + 0.075), (0.0, face + 0.06),
            (0.012, face - 0.04)]
    p.prism(sill, -w / 2 - 0.1, w / 2 + 0.1)
    p.box((0, -0.072, face + 0.06), (w + 0.2, 0.012, 0.012))
    if chajja:
        # lintel band + sloped sunshade with an upturned front lip
        top = h + band
        p.box((0, top + 0.06, face + 0.01), (w + 0.5, 0.12, 0.02))
        sh = [(top + 0.12, face), (top + 0.12, face + 0.04), (top + 0.07, face + 0.5),
              (top + 0.04, face + 0.5), (top + 0.04, face + 0.02), (top + 0.02, face)]
        p.prism(sh, -w / 2 - 0.22, w / 2 + 0.22)
        p.box((0, top + 0.08, face + 0.49), (w + 0.44, 0.05, 0.03))
    return p.finish(f"masonry_{int(w * 100)}x{int(h * 100)}_t{int(t * 100)}", bevel=0.006)


def doorframe(w, h, t):
    """Chaukhat: jambs and head with a stepped moulding on both faces, a stop bead."""
    p = Piece()
    f = 0.09
    d = min(t, 0.14)
    for sx in (-1, 1):
        x = sx * (w / 2 - f / 2)
        p.box((x, h / 2, 0), (f, h, d))
        for face in (-1, 1):   # architrave steps on both faces
            p.box((sx * (w / 2 + 0.025), (h + 0.05) / 2, face * (t / 2 + 0.008)), (0.07, h + 0.05, 0.016))
            p.box((sx * (w / 2 + 0.045), (h + 0.05) / 2, face * (t / 2 + 0.018)), (0.03, h + 0.05, 0.012))
        p.box((sx * (w / 2 - f - 0.008), h / 2, 0.0), (0.016, h - f, 0.03))
    p.box((0, h - f / 2, 0), (w, f, d))
    for face in (-1, 1):
        p.box((0, h + 0.025, face * (t / 2 + 0.008)), (w + 0.19, 0.07, 0.016))
        p.box((0, h + 0.045, face * (t / 2 + 0.018)), (w + 0.15, 0.03, 0.012))
    return p.finish(f"doorframe_{int(w * 100)}x{int(h * 100)}_t{int(t * 100)}", bevel=0.004)


def ventframe(w, h, t):
    """Plain frame for vents and the hub's jaali window."""
    p = Piece()
    f, d = 0.06, 0.1
    for sx in (-1, 1):
        p.box((sx * (w / 2 - f / 2), h / 2, 0), (f, h, d))
    p.box((0, h - f / 2, 0), (w, f, d))
    p.box((0, f / 2, 0), (w, f, d + 0.03))
    return p.finish(f"vent_{int(w * 100)}x{int(h * 100)}_t{int(t * 100)}", bevel=0.004)


def pipe(h, t):
    """One storey of drain pipe 6 cm off the wall: the pipe, a socket collar at the top and a
    clamp with its bracket at mid height (origin: foot of the run, on the wall face)."""
    p = Piece()
    r, off = 0.055, 0.06 + 0.055
    z = t / 2 + off
    p.cylinder((0, 0, z), (0, h, z), r, 14)
    p.cylinder((0, h - 0.12, z), (0, h, z), r + 0.012, 14)          # socket
    p.cylinder((0, h * 0.5 - 0.02, z), (0, h * 0.5 + 0.02, z), r + 0.008, 14)  # clamp ring
    p.box((0, h * 0.5, t / 2 + off / 2), (0.03, 0.03, off), bevel=0.003)          # bracket
    return p.finish(f"pipe_{int(h * 100)}x0_t{int(t * 100)}", bevel=0)


def pipeshoe(t):
    """Foot of a drain pipe: a 45 degree shoe throwing water away from the wall."""
    p = Piece()
    r, off = 0.055, 0.115
    z = t / 2 + off
    p.cylinder((0, 0.25, z), (0, 0.12, z), r, 14)
    p.cylinder((0, 0.12, z), (0, 0.04, z + 0.12), r, 14)
    p.cylinder((0, 0.25, z), (0, 0.33, z), r + 0.012, 14)
    return p.finish(f"pipeshoe_0x0_t{int(t * 100)}", bevel=0)


BUILDERS = {"winframe": winframe, "grill": grill, "ventgrill": ventgrill, "masonry": masonry,
            "doorframe": doorframe, "vent": ventframe}


def build(name):
    kind, dims, th = name.split("_")
    w, h = (int(v) / 100 for v in dims.split("x"))
    t = int(th[1:]) / 100
    bpy.ops.wm.read_factory_settings(use_empty=True)
    if kind == "pipe":
        ob = pipe(w, t)
    elif kind == "pipeshoe":
        ob = pipeshoe(t)
    elif kind == "sill":
        ob = masonry(w, h, t, chajja=False)
    else:
        ob = BUILDERS[kind](w, h, t)
    ob.name = name
    bpy.context.view_layer.objects.active = ob
    ob.select_set(True)
    path = os.path.join(KIT, name + ".obj")
    bpy.ops.wm.obj_export(filepath=path, export_selected_objects=True, export_materials=False,
                          export_uv=False, export_normals=True, apply_modifiers=True,
                          forward_axis="NEGATIVE_Z", up_axis="Y")
    tris = sum(len(p.vertices) - 2 for p in ob.evaluated_get(bpy.context.evaluated_depsgraph_get()).data.polygons)
    return tris


if __name__ == "__main__":
    manifest = json.load(open(os.path.join(KIT, "pieces.json")))
    os.makedirs(KIT, exist_ok=True)
    for name in sorted(manifest["pieces"]):
        print(f"KIT {name}: ~{build(name)} tris")
