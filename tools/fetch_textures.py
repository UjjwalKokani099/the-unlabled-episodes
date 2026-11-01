"""Downloads the CC0 PBR texture sets used by the material library (ambientCG).

Run from the project root:  python tools/fetch_textures.py
Re-running skips sets that are already present. Output:
    assets/materials/textures/<name>/<name>_albedo.jpg / _normal.jpg / _roughness.jpg
    (+ _metallic.jpg when the set has one; decals get a single RGBA _albedo.png)
and assets/materials/CREDITS.md. All sources are CC0 (public domain).
"""
import io
import os
import shutil
import sys
import tempfile
import urllib.request
import zipfile

from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "assets", "materials", "textures")
UA = {"User-Agent": "Mozilla/5.0 (UNLABELED texture fetch)"}
RES = "1K"

# local name: (ambientCG id, purpose)
SETS = {
    # Walls
    "plaster_painted": ("PaintedPlaster017", "clean painted plaster, tinted per building"),
    "plaster_peeling": ("PaintedPlaster014", "peeling white paint over brick"),
    "plaster_peeling_heavy": ("PaintedPlaster016", "badly peeling old plaster"),
    "plaster_damp": ("PaintedPlaster009", "damp, mouldy green-grey wall"),
    "plaster_yellow_peeling": ("PaintedPlaster018", "peeling yellow distemper"),
    "plaster_bare": ("Plaster006", "stained bare plaster"),
    "concrete_rough": ("Concrete012", "rough cast concrete (stairs, parapets)"),
    "concrete_dirty": ("Concrete036", "dirty weathered concrete (water tank, compound wall)"),
    "concrete_dark": ("Concrete032", "dark concrete (terrace roof)"),
    "brick_red": ("Bricks101", "exposed red brick"),
    # Floors
    "floor_mosaic": ("Terrazzo011", "Indian mosaic (terrazzo) flooring"),
    "floor_kota": ("Concrete031", "large slabs, tinted blue-green as Kota stone"),
    "tile_white": ("Tiles002", "white ceramic wall/bathroom tiles"),
    "tile_checker": ("Tiles074", "black and white checked lobby floor"),
    "tile_polished": ("Tiles078", "polished stone-look floor tiles"),
    "ground_pavers": ("PavingStones099", "interlocking concrete paver blocks"),
    "ground_asphalt": ("Asphalt015", "asphalt (parking, lane)"),
    "ground_dirt": ("Ground047", "mossy dirt / unpaved ground"),
    # Metal and wood
    "metal_painted_green": ("PaintedMetal006", "green painted gate metal with rust"),
    "metal_painted_white": ("PaintedMetal010", "chipped white painted metal (meter boxes)"),
    "metal_rust": ("Rust009", "fully rusted iron"),
    "metal_corrugated": ("CorrugatedSteel005", "corrugated steel sheet (parking shed)"),
    "wood_painted_dark": ("PaintedWood005", "dark worn painted wood (old doors)"),
    "wood_varnished": ("PaintedWood006A", "varnished brown door wood"),
    "wood_painted_blue": ("PaintedWood008A", "pale blue painted wood (window frames)"),
    "wood_planks": ("Planks005", "plain wooden planks (furniture)"),
    "paper": ("Paper001", "paper (posters, registers)"),
}
# Grayscale multiply masks (white = untouched) used by the surface shader's leak overlay.
OVERLAYS = {
    "overlay_leaks_a": ("Leaking012C", "rain/leak streak overlay for walls"),
    "overlay_leaks_b": ("Leaking017B", "rain/leak streak overlay for walls"),
}
MAPS = {"Color": "albedo", "NormalGL": "normal", "Roughness": "roughness", "Metalness": "metallic"}


def download(asset_id: str) -> bytes:
    for kind in (f"{RES}-JPG", f"{RES}-PNG"):
        url = f"https://ambientcg.com/get?file={asset_id}_{kind}.zip"
        try:
            req = urllib.request.Request(url, headers=UA)
            with urllib.request.urlopen(req, timeout=120) as r:
                return r.read()
        except Exception as e:  # try the next format
            last = e
    raise RuntimeError(f"{asset_id}: {last}")


def maps_in(zf: zipfile.ZipFile) -> dict:
    found = {}
    for name in zf.namelist():
        base = os.path.splitext(os.path.basename(name))[0]
        for key in list(MAPS) + ["Opacity"]:
            if base.endswith("_" + key):
                found[key] = name
    return found


def fetch_material(name: str, asset_id: str) -> None:
    folder = os.path.join(OUT, name)
    if os.path.exists(os.path.join(folder, f"{name}_albedo.jpg")):
        print("have", name)
        return
    os.makedirs(folder, exist_ok=True)
    zf = zipfile.ZipFile(io.BytesIO(download(asset_id)))
    found = maps_in(zf)
    for key, suffix in MAPS.items():
        if key in found:
            img = Image.open(io.BytesIO(zf.read(found[key])))
            img = img.convert("L") if suffix in ("roughness", "metallic") else img.convert("RGB")
            img.save(os.path.join(folder, f"{name}_{suffix}.jpg"), quality=92)
    print("got ", name, "<-", asset_id, sorted(found))


def fetch_overlay(name: str, asset_id: str) -> None:
    folder = os.path.join(OUT, name)
    if os.path.exists(os.path.join(folder, f"{name}_mask.jpg")):
        print("have", name)
        return
    os.makedirs(folder, exist_ok=True)
    zf = zipfile.ZipFile(io.BytesIO(download(asset_id)))
    found = maps_in(zf)
    mask = Image.open(io.BytesIO(zf.read(found["Color"]))).convert("L")
    # Stretch 148..255 to 0..255 so the shader's strength slider has full range.
    lo, hi = mask.getextrema()
    mask = mask.point(lambda v: int(max(0, min(255, (v - lo) * 255 / max(hi - lo, 1)))))
    mask.save(os.path.join(folder, f"{name}_mask.jpg"), quality=92)
    print("got ", name, "<-", asset_id)


def write_credits() -> None:
    lines = ["# Texture credits", "",
             "All texture sets below are CC0 (public domain) from ambientCG (https://ambientcg.com).",
             "Downloaded at 1K resolution by `tools/fetch_textures.py`.", "",
             "| Local name | ambientCG asset | Used for |", "|---|---|---|"]
    for name, (aid, why) in list(SETS.items()) + list(OVERLAYS.items()):
        lines.append(f"| {name} | [{aid}](https://ambientcg.com/view?id={aid}) | {why} |")
    lines += ["", "Generated decals (posters, cracks, paan stains, stencils) are made by",
              "`tools/gen_decals.py` and are original to this project."]
    with open(os.path.join(ROOT, "assets", "materials", "CREDITS.md"), "w", encoding="utf-8", newline="\n") as f:
        f.write("\n".join(lines) + "\n")


def main() -> None:
    os.makedirs(OUT, exist_ok=True)
    failed = []
    for name, (aid, _) in SETS.items():
        try:
            fetch_material(name, aid)
        except Exception as e:
            failed.append((name, str(e)))
    for name, (aid, _) in OVERLAYS.items():
        try:
            fetch_overlay(name, aid)
        except Exception as e:
            failed.append((name, str(e)))
    write_credits()
    print("failed:", failed or "none")
    sys.exit(1 if failed else 0)


if __name__ == "__main__":
    main()
