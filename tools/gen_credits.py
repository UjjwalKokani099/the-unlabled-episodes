"""Builds data/credits.json (the credits roll in the main menu) from data/credits_header.json
plus every asset credit file: assets/fonts/CREDITS.md, assets/models/CREDITS.md,
assets/materials/CREDITS.md and docs/audio_sources.md. Re-run after adding assets:
    python tools/gen_credits.py
"""
import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent


def table_rows(md: str) -> list[list[str]]:
    """Body rows of the first markdown table (header + separator skipped)."""
    rows, seen_sep = [], False
    for line in md.splitlines():
        if not line.startswith("|"):
            if seen_sep and rows:
                break
            continue
        cells = [c.strip() for c in line.strip().strip("|").split("|")]
        if all(re.fullmatch(r"-+", c) for c in cells):
            seen_sep = True
            continue
        if seen_sep:
            rows.append(cells)
    return rows


def plain(text: str) -> str:
    """[label](url) -> label."""
    return re.sub(r"\[([^\]]+)\]\([^)]*\)", r"\1", text)


def main() -> None:
    data = json.loads((ROOT / "data" / "credits_header.json").read_text(encoding="utf-8"))
    sections = list(data["sections"])

    fonts = table_rows((ROOT / "assets" / "fonts" / "CREDITS.md").read_text(encoding="utf-8"))
    sections.append({"title": "Fonts", "lines": [f"{r[1]} ({r[2].split(' (')[0]})" for r in fonts]})

    models = table_rows((ROOT / "assets" / "models" / "CREDITS.md").read_text(encoding="utf-8"))
    authors = sorted({a.strip() for r in models for a in r[2].split(",")})
    sections.append({"title": "3D models - Poly Haven (CC0)",
                     "lines": [f"{r[1]} by {r[2]}" for r in models] + ["", "Thank you: " + ", ".join(authors)]})

    textures = table_rows((ROOT / "assets" / "materials" / "CREDITS.md").read_text(encoding="utf-8"))
    sections.append({"title": "Textures - ambientCG (CC0)",
                     "lines": [plain(r[1]) for r in textures]})

    audio = (ROOT / "docs" / "audio_sources.md").read_text(encoding="utf-8")
    third_party = [r for r in table_rows(audio) if len(r) > 2 and "original" not in " ".join(r).lower()]
    lines = ["Original sound design (synthesised for this game)"]
    lines += [f"{r[0]} - {r[2]}" for r in third_party]
    sections.append({"title": "Sound", "lines": lines})

    sections.append({"title": "", "lines": ["Thank you for watching."]})
    out = {"studio": data["studio"], "presents": data["presents"], "sections": sections}
    (ROOT / "data" / "credits.json").write_text(json.dumps(out, indent="\t", ensure_ascii=False) + "\n", encoding="utf-8")
    print(f"data/credits.json: {len(sections)} sections, {sum(len(s['lines']) for s in sections)} lines")


if __name__ == "__main__":
    main()
