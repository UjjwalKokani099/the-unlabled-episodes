"""Sets 3D-friendly import options on every texture under assets/materials and assets/decals.

Godot imports new images as lossless 2D textures. For 3D surfaces we want VRAM compression
(fast, low memory), mipmaps (no shimmering at a distance) and normal-map mode for *_normal.
Run from the project root after new textures arrive:

    <console exe> --headless --path . --import      # creates the .import files
    python tools/configure_texture_imports.py       # rewrites their options
    <console exe> --headless --path . --import      # reimports with the new options
"""
import glob
import os
import re

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
FOLDERS = ["assets/materials", "assets/decals"]


def set_param(text: str, key: str, value: str) -> str:
    pattern = re.compile(rf"^{re.escape(key)}=.*$", re.M)
    if pattern.search(text):
        return pattern.sub(f"{key}={value}", text)
    return text.replace("[params]\n", f"[params]\n\n{key}={value}\n", 1)


def main() -> None:
    changed = 0
    for folder in FOLDERS:
        for path in glob.glob(os.path.join(ROOT, folder, "**", "*.import"), recursive=True):
            source = path[:-len(".import")]
            if not source.lower().endswith((".jpg", ".jpeg", ".png")):
                continue
            with open(path, encoding="utf-8") as f:
                text = f.read()
            if 'importer="texture"' not in text:
                continue
            new = text
            is_normal = source.lower().endswith(("_normal.jpg", "_normal.png"))
            is_decal = "assets/decals" in source.replace("\\", "/")
            new = set_param(new, "compress/mode", "2")  # VRAM compressed
            new = set_param(new, "mipmaps/generate", "true")
            new = set_param(new, "detect_3d/compress_to", "0")
            new = set_param(new, "compress/normal_map", "1" if is_normal else "2")
            new = set_param(new, "process/fix_alpha_border", "true" if is_decal else "false")
            if new != text:
                with open(path, "w", encoding="utf-8", newline="\n") as f:
                    f.write(new)
                # Delete the old imported copies so Godot re-imports with the new options.
                for dest in re.findall(r'^dest_files=\[(.*)\]$', text, re.M):
                    for res_path in re.findall(r'"res://([^"]+)"', dest):
                        full = os.path.join(ROOT, res_path)
                        if os.path.exists(full):
                            os.remove(full)
                for res_path in re.findall(r'^path[^=]*="res://([^"]+)"', text, re.M):
                    full = os.path.join(ROOT, res_path)
                    if os.path.exists(full):
                        os.remove(full)
                changed += 1
    print(f"configured {changed} textures")


if __name__ == "__main__":
    main()
