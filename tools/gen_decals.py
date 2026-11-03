"""Makes the decal textures and their drop-in scenes.

1. Ages the clean posters rendered by tools/gen_posters.gd (tools/_build/posters/*.png):
   sun-fade, paper grain, stains, fold creases, torn edges, missing corners.
2. Draws procedural decals: paan (betel) spit stains, a ceiling/wall water stain, cracks,
   hand grime.
3. Writes assets/decals/<name>.png and assets/decals/<name>.tscn (a Node3D whose Decal
   projects along -Z: put the node on a wall surface with +Z pointing out of the wall).

Run from the project root:  python tools/gen_decals.py   (deterministic: fixed seeds)
"""
import math
import os
import random

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
RAW = os.path.join(ROOT, "tools", "_build", "posters")
OUT = os.path.join(ROOT, "assets", "decals")
SCENES = os.path.join(ROOT, "assets", "decals")
PAPER = os.path.join(ROOT, "assets", "materials", "textures", "paper", "paper_albedo.jpg")

# name: width in metres (height follows the image aspect)
SIZES = {}


def smooth_noise(w: int, h: int, scale: int, rng: np.random.Generator) -> np.ndarray:
    small = rng.random((max(2, h // scale), max(2, w // scale)))
    img = Image.fromarray((small * 255).astype(np.uint8)).resize((w, h), Image.BICUBIC)
    return np.asarray(img).astype(np.float32) / 255.0


def fbm(w: int, h: int, rng: np.random.Generator, scales=(64, 24, 8)) -> np.ndarray:
    total = np.zeros((h, w), np.float32)
    amp, norm = 1.0, 0.0
    for s in scales:
        total += smooth_noise(w, h, s, rng) * amp
        norm += amp
        amp *= 0.5
    return total / norm


# --------------------------------------------------------------------------- posters

def age_poster(name: str, fade: float, seed: int, width_m: float) -> None:
    rng = np.random.default_rng(seed)
    src = Image.open(os.path.join(RAW, name + ".png")).convert("RGBA")
    w, h = src.size
    rgb = np.asarray(src).astype(np.float32)[..., :3] / 255.0

    # Paper grain from the CC0 paper texture.
    paper = Image.open(PAPER).convert("L").resize((w, h))
    grain = np.asarray(paper).astype(np.float32) / 255.0
    grain = 0.85 + 0.3 * (grain - grain.mean())
    rgb *= grain[..., None]

    # Sun fade: wash toward a yellowed paper tone, lose saturation.
    yellowed = np.array([0.93, 0.88, 0.72], np.float32)
    lum = rgb.mean(axis=2, keepdims=True)
    rgb = rgb * (1 - fade * 0.6) + lum * fade * 0.6
    rgb = rgb * (1 - fade * 0.35) + yellowed * fade * 0.35

    # Brown stains and a darker bottom edge (rain splash).
    stains = fbm(w, h, rng, (90, 30)) > 0.68
    stain_amt = Image.fromarray((stains * 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(6))
    stain_amt = np.asarray(stain_amt).astype(np.float32) / 255.0 * 0.35
    rgb *= (1 - stain_amt[..., None] * np.array([0.3, 0.45, 0.7], np.float32))
    bottom = np.clip((np.arange(h)[:, None] / h - 0.8) / 0.2, 0, 1) * fbm(w, h, rng, (40, 12))
    rgb *= (1 - bottom[..., None] * 0.35)

    # Fold creases: one horizontal, one vertical, light ridge + dark valley.
    for _ in range(2):
        if rng.random() < 0.85:
            pos = int(h * rng.uniform(0.35, 0.65))
            rgb[pos:pos + 2, :] *= 0.82
            rgb[pos + 2:pos + 4, :] = np.minimum(rgb[pos + 2:pos + 4, :] * 1.08, 1.0)
        pos = int(w * rng.uniform(0.4, 0.6))
        rgb[:, pos:pos + 2] *= 0.85

    # Torn, ragged border and a missing corner.
    alpha = np.ones((h, w), np.float32)
    edge = fbm(w, h, rng, (20, 6))
    margin = 6 + edge * 22
    yy, xx = np.mgrid[0:h, 0:w]
    dist = np.minimum(np.minimum(xx, w - 1 - xx), np.minimum(yy, h - 1 - yy))
    alpha *= np.clip((dist - margin * 0.4) / 3.0, 0, 1)
    corner = rng.integers(0, 4)
    cx = 0 if corner in (0, 2) else w
    cy = 0 if corner in (0, 1) else h
    r = rng.uniform(0.18, 0.32) * min(w, h)
    torn = np.hypot(xx - cx, yy - cy) < r * (0.8 + 0.4 * edge)
    alpha[torn] = 0.0

    out = np.dstack([np.clip(rgb, 0, 1), alpha])
    save(name, out, width_m)


def age_stencil(name: str, seed: int, width_m: float) -> None:
    rng = np.random.default_rng(seed)
    src = Image.open(os.path.join(RAW, name + ".png")).convert("RGBA")
    arr = np.asarray(src).astype(np.float32) / 255.0
    w, h = src.size
    # Patchy spray paint: erode alpha with noise, soften edges, add a few drips.
    erosion = fbm(w, h, rng, (30, 10, 4))
    alpha = arr[..., 3] * np.clip((erosion - 0.1) * 3.5, 0, 1) * 0.92
    alpha_img = Image.fromarray((alpha * 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(0.8))
    draw = ImageDraw.Draw(alpha_img)
    for _ in range(7):
        x = int(rng.uniform(0.05, 0.95) * w)
        ys = np.nonzero(arr[:, x, 3] > 0.5)[0]
        if ys.size:
            y0 = int(ys.max())
            draw.line([(x, y0), (x, y0 + int(rng.uniform(8, 30)))], fill=140, width=int(rng.uniform(3, 5)))
    alpha = np.asarray(alpha_img).astype(np.float32) / 255.0
    rgb = np.full((h, w, 3), 0.05, np.float32)
    save(name, np.dstack([rgb, alpha]), width_m)


# --------------------------------------------------------------------------- procedural

def paan_stain(name: str, seed: int, width_m: float) -> None:
    rng = random.Random(seed)
    size = 512
    alpha = Image.new("L", (size, size), 0)
    d = ImageDraw.Draw(alpha)
    cx, cy = size * 0.5, size * 0.42
    # Main splat
    for _ in range(40):
        a = rng.uniform(0, math.tau)
        dist = abs(rng.gauss(0, 55))
        r = rng.uniform(6, 34) * (1 - min(dist / 200, 0.8))
        x, y = cx + math.cos(a) * dist, cy + math.sin(a) * dist * 0.8
        d.ellipse([x - r, y - r, x + r, y + r], fill=rng.randint(150, 235))
    # Flecks
    for _ in range(120):
        a = rng.uniform(0, math.tau)
        dist = rng.uniform(60, 230)
        r = rng.uniform(1, 5)
        x, y = cx + math.cos(a) * dist, cy + math.sin(a) * dist * 0.7
        d.ellipse([x - r, y - r, x + r, y + r], fill=rng.randint(120, 220))
    # Drips running down
    for _ in range(7):
        x = cx + rng.uniform(-60, 60)
        y = cy + rng.uniform(0, 30)
        length = rng.uniform(60, 200)
        wdt = rng.uniform(3, 8)
        d.line([(x, y), (x + rng.uniform(-4, 4), y + length)], fill=rng.randint(140, 210), width=int(wdt))
        d.ellipse([x - wdt, y + length - wdt, x + wdt, y + length + wdt * 1.4], fill=200)
    alpha = alpha.filter(ImageFilter.GaussianBlur(1.6))
    a = np.asarray(alpha).astype(np.float32) / 255.0
    nrng = np.random.default_rng(seed)
    tone = fbm(size, size, nrng, (40, 10))
    # Dried paan is a dark rust-brown red, not bright red (that reads as blood).
    rgb = np.dstack([0.3 + 0.08 * tone, 0.09 + 0.03 * tone, 0.05 + 0.02 * tone])
    save(name, np.dstack([rgb, a * 0.78]), width_m)


def water_stain(name: str, seed: int, width_m: float) -> None:
    rng = np.random.default_rng(seed)
    size = 768
    yy, xx = np.mgrid[0:size, 0:size] / size - 0.5
    shape = fbm(size, size, rng, (120, 40, 12))
    radius = np.hypot(xx, yy * 1.15) + (shape - 0.5) * 0.25
    body = np.clip((0.38 - radius) / 0.08, 0, 1)
    rings = np.zeros_like(radius)
    for r0 in (0.36, 0.3, 0.22):
        rings += np.exp(-((radius - r0) / 0.008) ** 2) * 0.8
    alpha = np.clip(body * (0.25 + 0.25 * shape) + rings * body.clip(0.2, 1), 0, 0.85)
    rgb = np.dstack([np.full_like(alpha, 0.45), np.full_like(alpha, 0.36), np.full_like(alpha, 0.2)])
    save(name, np.dstack([rgb, alpha]), width_m)


def crack(name: str, seed: int, width_m: float) -> None:
    rng = random.Random(seed)
    w, h = 512, 768
    alpha = Image.new("L", (w, h), 0)
    d = ImageDraw.Draw(alpha)

    def branch(x, y, angle, length, width, depth):
        while length > 0 and width > 0.6:
            step = rng.uniform(6, 14)
            angle += rng.gauss(0, 0.2)
            angle += (math.pi / 2 - angle) * 0.08  # cracks mostly run downward
            nx, ny = x + math.cos(angle) * step, y + math.sin(angle) * step
            d.line([(x, y), (nx, ny)], fill=255, width=max(1, int(width)))
            x, y = nx, ny
            length -= step
            width *= 0.99
            if depth < 2 and rng.random() < 0.035:
                branch(x, y, angle + rng.choice([-1, 1]) * rng.uniform(0.5, 1.0), length * 0.3, width * 0.55, depth + 1)

    branch(w * 0.5, 20, math.pi / 2, h * 1.3, 7.0, 0)
    alpha = alpha.filter(ImageFilter.GaussianBlur(0.7))
    a = np.asarray(alpha).astype(np.float32) / 255.0
    # Faint dirty halo around the crack line.
    halo = np.asarray(alpha.filter(ImageFilter.GaussianBlur(6))).astype(np.float32) / 255.0
    a = np.clip(a * 0.95 + halo * 0.35, 0, 1)
    rgb = np.dstack([np.full_like(a, 0.12), np.full_like(a, 0.1), np.full_like(a, 0.08)])
    save(name, np.dstack([rgb, a]), width_m)


def hand_grime(name: str, seed: int, width_m: float) -> None:
    rng = np.random.default_rng(seed)
    size = 384
    yy, xx = np.mgrid[0:size, 0:size] / size - 0.5
    blob = np.clip(1 - np.hypot(xx * 1.2, yy) / 0.45, 0, 1) ** 1.5
    alpha = blob * (0.4 + 0.6 * fbm(size, size, rng, (30, 8))) * 0.55
    rgb = np.dstack([np.full_like(alpha, 0.18), np.full_like(alpha, 0.15), np.full_like(alpha, 0.12)])
    save(name, np.dstack([rgb, alpha]), width_m)


# --------------------------------------------------------------------------- output

def save(name: str, rgba: np.ndarray, width_m: float) -> None:
    os.makedirs(OUT, exist_ok=True)
    img = Image.fromarray((np.clip(rgba, 0, 1) * 255).astype(np.uint8), "RGBA")
    img.save(os.path.join(OUT, name + ".png"))
    SIZES[name] = (width_m, width_m * img.height / img.width)


def write_scenes() -> None:
    os.makedirs(SCENES, exist_ok=True)
    for name, (w, h) in SIZES.items():
        text = f'''[gd_scene format=3]

[ext_resource type="Texture2D" path="res://assets/decals/{name}.png" id="1_tex"]

[node name="Decal_{name}" type="Node3D"]

[node name="Decal" type="Decal" parent="."]
rotation_degrees = Vector3(90, 0, 0)
size = Vector3({w:.3f}, 0.3, {h:.3f})
texture_albedo = ExtResource("1_tex")
normal_fade = 0.5
upper_fade = 0.05
lower_fade = 0.05
'''
        with open(os.path.join(SCENES, name + ".tscn"), "w", encoding="utf-8", newline="\n") as f:
            f.write(text)


def main() -> None:
    age_poster("notice_water", fade=0.25, seed=11, width_m=0.42)
    age_poster("tuition", fade=0.45, seed=12, width_m=0.4)
    age_poster("room_rent", fade=0.35, seed=13, width_m=0.38)
    age_poster("ganesh", fade=0.7, seed=14, width_m=0.45)
    age_poster("lost_dog", fade=0.3, seed=15, width_m=0.36)
    age_stencil("stencil_no_bills", seed=16, width_m=1.3)
    paan_stain("paan_a", seed=21, width_m=0.5)
    paan_stain("paan_b", seed=22, width_m=0.45)
    water_stain("water_stain", seed=31, width_m=1.1)
    crack("crack_a", seed=41, width_m=0.6)
    crack("crack_b", seed=42, width_m=0.5)
    hand_grime("hand_grime", seed=51, width_m=0.35)
    write_scenes()
    print("decals:", ", ".join(SIZES))


if __name__ == "__main__":
    main()
