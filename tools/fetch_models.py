"""Downloads the CC0 3D models used for set dressing (Poly Haven, glTF, 1K textures).

Run from the project root:  python tools/fetch_models.py
Re-running skips models that are already present. Output:
    assets/models/<id>/<id>.gltf + .bin + textures/*.jpg
and assets/models/CREDITS.md. All Poly Haven assets are CC0 (public domain).
Afterwards: `--import`, `python tools/configure_texture_imports.py`, `--import` again.

Small props get their textures shrunk to 512 px (they never fill the screen), which keeps
the web build (iPad) download small. Godot imports a .gltf as a scene: instance it.
Every model's real size (metres, from Poly Haven) is printed so generators can place it.
"""
import io
import json
import os
import sys
import urllib.request

from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "assets", "models")
UA = {"User-Agent": "Mozilla/5.0 (UNLABELED model fetch)"}
API = "https://api.polyhaven.com"

# Poly Haven id: (texture size in px, where it is used)
MODELS = {
    # Nikhil's room (present day)
    "plastic_monobloc_chair_01": (1024, "hub desk chair, cabin chair"),
    "ceiling_fan": (1024, "hub ceiling fan"),
    "television_02": (1024, "hub CRT TV body"),
    "classic_laptop": (512, "Nikhil's laptop"),
    "desk_lamp_arm_01": (512, "desk lamp"),
    "wall_clock": (512, "wall clocks"),
    "cardboard_box_01": (512, "boxes on the almirah"),
    "vintage_suitcase": (512, "suitcase on the almirah"),
    "plastic_jerrycan": (512, "water can"),
    "plastic_broom": (512, "broom in the corner"),
    "metal_trash_can": (512, "dustbin"),
    "alarm_clock_01": (512, "bedside alarm clock"),
    "plastic_thermos": (512, "flask on the desk"),
    "portable_cassette_player": (512, "Nikhil collects old media"),
    # Tape 1: Shanti Vihar, 1998
    "wooden_stool_01": (512, "the cabin stool that moves"),
    "security_camera_01": (512, "CCTV cameras on the wings"),
    "clipboard": (512, "duty roster in the cabin"),
    "metal_jug": (512, "water jug in the cabin"),
    "vintage_flashlight": (512, "torch on the cabin table"),
    "power_box_01": (1024, "meter room / wall junction boxes"),
    "utility_box_01": (512, "electrical boxes on walls"),
    "covered_car": (1024, "car under a cover in the parking"),
    "old_tyre": (512, "parking clutter"),
    "plastic_crate_01": (512, "parking clutter"),
    "trashbag": (512, "garbage by the compound wall"),
    "can_rusted": (512, "litter"),
}


def get_json(url: str):
    with urllib.request.urlopen(urllib.request.Request(url, headers=UA), timeout=60) as r:
        return json.load(r)


def download(url: str) -> bytes:
    with urllib.request.urlopen(urllib.request.Request(url, headers=UA), timeout=120) as r:
        return r.read()


def fetch(model_id: str, tex_px: int) -> dict:
    folder = os.path.join(OUT, model_id)
    info = get_json(f"{API}/info/{model_id}")
    gltf_path = os.path.join(folder, f"{model_id}.gltf")
    if not os.path.exists(gltf_path):
        files = get_json(f"{API}/files/{model_id}")["gltf"]["1k"]["gltf"]
        os.makedirs(folder, exist_ok=True)
        for rel, entry in files["include"].items():
            data = download(entry["url"])
            dest = os.path.join(folder, rel)
            os.makedirs(os.path.dirname(dest), exist_ok=True)
            if tex_px < 1024 and rel.lower().endswith((".jpg", ".png")):
                img = Image.open(io.BytesIO(data))
                if max(img.size) > tex_px:
                    img = img.resize((tex_px, tex_px * img.size[1] // img.size[0]), Image.LANCZOS)
                    out = io.BytesIO()
                    img.save(out, "JPEG" if rel.lower().endswith(".jpg") else "PNG", quality=90)
                    data = out.getvalue()
            with open(dest, "wb") as f:
                f.write(data)
        # The 1k .gltf names its files *_1k.*; keep that text, just store it under a stable name.
        with open(gltf_path, "wb") as f:
            f.write(download(files["url"]))
        print(f"  got {model_id}")
    dims = [d / 1000.0 for d in info.get("dimensions", [0, 0, 0])]
    return {"name": info.get("name", model_id), "authors": ", ".join(info.get("authors", {}).keys()), "dims": dims}


def main() -> None:
    only = set(sys.argv[1:])
    credits = ["# 3D model credits", "", "All models from [Poly Haven](https://polyhaven.com) (CC0).", "",
               "| Folder | Model | Author(s) | Size (m, x/y/z as listed) | Used for |", "|---|---|---|---|---|"]
    for model_id, (px, purpose) in MODELS.items():
        if only and model_id not in only:
            continue
        meta = fetch(model_id, px)
        d = meta["dims"]
        print(f"{model_id:28s} {d[0]:.2f} x {d[1]:.2f} x {d[2]:.2f} m")
        credits.append(f"| {model_id} | {meta['name']} | {meta['authors']} | {d[0]:.2f} / {d[1]:.2f} / {d[2]:.2f} | {purpose} |")
    if not only:
        with open(os.path.join(OUT, "CREDITS.md"), "w", encoding="utf-8", newline="\n") as f:
            f.write("\n".join(credits) + "\n")


if __name__ == "__main__":
    main()
