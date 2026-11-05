"""The voice script: every spoken line in the game, with the id the game plays it under.

    python tools/voice_lines.py                 # writes data/voice/lines.json + docs/voice_script.md
    python tools/voice_lines.py --install DIR   # TTS/recorded files in DIR -> assets/audio/voice/<id>.ogg

Sources (all read statically, nothing to keep in sync by hand):
- dialogue files data/dialogue/**.json: id "<file>/<node>" (or the node's "voice"),
- sequences data/sequences/**.json: say/think steps (their "voice", else the auto id),
- tape/hub/intro scripts: OPENING lists (<tape>/opening_N), VO_BEATS (<tape>/vo_<event>),
  ARRIVAL_THOUGHTS, _say(...) / _think(...) / _think_once(...) with literal text.
Lines without an explicit id get Subtitles.auto_voice_id(text) = "auto/" + md5(text)[:12]
(ui/hud/subtitles.gd), so a recording is picked up as soon as its file exists.

Install: for each line, DIR/<id with "/" -> "__">.(wav|mp3|ogg|flac) is converted with ffmpeg
to OGG Vorbis at -16 LUFS (radio/phone voices band-limited like a handset) into
assets/audio/voice/<id>.ogg; then run Godot --import.
"""
import argparse
import glob
import hashlib
import json
import os
import re
import shutil
import subprocess
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT_JSON = os.path.join(ROOT, "data", "voice", "lines.json")
OUT_MD = os.path.join(ROOT, "docs", "voice_script.md")
VOICE_DIR = os.path.join(ROOT, "assets", "audio", "voice")

# Who thinks/narrates in each place (think lines have no speaker in the game).
PROTAGONIST = {"chapter_01": "RAGHU", "tape01": "RAGHU", "chapter_02": "SALIM", "tape02": "SALIM",
               "hub": "NIKHIL", "intro": "NIKHIL"}
TAPE_OF = {"chapter_01": "Tape 1: The Watchman", "tape01": "Tape 1: The Watchman",
           "chapter_02": "Tape 2: The Toll Booth", "tape02": "Tape 2: The Toll Booth",
           "hub": "Nikhil's room", "intro": "Intro"}
# Casting notes for TTS / actors. "filter" = how --install treats the file.
CASTING = {
    "RAGHU": {"who": "Raghu, 52, night watchman, Mumbai 1998. Narrates from beyond (already dead): calm, low, tired, "
                     "Indian English, slow. Live lines in the tape: plain, a little nervous.", "filter": "none"},
    "SALIM": {"who": "Salim, 34, toll booth operator, 2001. Narration: flat, matter-of-fact, Indian English; "
                     "live lines quieter, unsettled.", "filter": "none"},
    "NIKHIL": {"who": "Nikhil, mid-20s, present day, alone in a rented room. Inner monologue: soft, wry, "
                      "close to the mic, Indian English.", "filter": "none"},
    "DESHMUKH": {"who": "Mr. Deshmukh, 70s, retired, polite, too calm. Knows things he shouldn't.", "filter": "none"},
    "MRS. IYER": {"who": "Mrs. Iyer, 60s, South Indian, warm, chatty, tired.", "filter": "none"},
    "SECRETARY": {"who": "Society secretary, 50s, woken at 3 AM, irritated then frightened. Landline phone.",
                  "filter": "phone"},
    "PILLAI (RADIO)": {"who": "Pillai, toll supervisor, 50s, bored authority. Over a wireless set.", "filter": "radio"},
    "RADIO": {"who": "Unknown voice on the radio. Very calm, slightly too close. Heavily filtered.", "filter": "radio"},
    "Vendor": {"who": "Street vendor, 40s, Hindi. Speak only the Hindi part (the bracket is the subtitle "
                      "translation).", "filter": "none"},
    "MAA": {"who": "Nikhil's mother, 50s, on the phone from home town: loving, worried, Hindi-English mix.",
            "filter": "phone"},
}
# Narration uses the same voice as the character's live lines.
CASTING["RAGHU (V.O.)"] = dict(CASTING["RAGHU"])
CASTING["SALIM (V.O.)"] = dict(CASTING["SALIM"])
CASTING["MR. DESHMUKH"] = CASTING.pop("DESHMUKH")


def auto_id(text: str) -> str:
    return "auto/" + hashlib.md5(text.encode("utf-8")).hexdigest()[:12]


def plain(text: str) -> str:
    return re.sub(r"\[/?[a-z]+[^\]]*\]", "", text).strip()


def spoken(text: str) -> str:
    """What the voice says: no BBCode, no bracketed translation/stage direction."""
    t = plain(text)
    t = re.sub(r"\s*\([^)]*\)\s*$", "", t) if not t.startswith("(") else t
    return t.strip()


def gd_unescape(s: str) -> str:
    return s.encode("utf-8").decode("unicode_escape").encode("latin-1").decode("utf-8")


STR = r'"((?:[^"\\]|\\.)*)"'


def place_of(path: str) -> str:
    for key in PROTAGONIST:
        if f"/{key}/" in path.replace("\\", "/") or path.replace("\\", "/").endswith(f"/{key}"):
            return key
    return "hub"


def add(lines, seen, line_id, speaker, text, source, place, kind="line"):
    if not text or line_id in seen:
        return
    if plain(text).startswith("(") and plain(text).endswith(")"):
        kind = "sound"  # stage direction like "(slow breathing)": a sound effect, not a voice line
    seen.add(line_id)
    lines.append({"id": line_id, "speaker": speaker or PROTAGONIST.get(place, "NIKHIL"), "text": text,
                  "speak": spoken(text), "kind": kind, "place": TAPE_OF.get(place, place), "source": source})


def from_dialogue(lines, seen):
    for path in sorted(glob.glob(os.path.join(ROOT, "data", "dialogue", "**", "*.json"), recursive=True)):
        data = json.load(open(path, encoding="utf-8"))
        stem = os.path.splitext(os.path.basename(path))[0]
        place = place_of(os.path.dirname(path))
        for node_id, node in data.get("nodes", {}).items():
            if "text" not in node:
                continue
            line_id = node.get("voice", f"{stem}/{node_id}")
            add(lines, seen, line_id, node.get("speaker", ""), node["text"], os.path.relpath(path, ROOT), place)


def from_sequences(lines, seen):
    def walk(steps, path, place):
        for s in steps:
            if s.get("do") in ("say", "think") and s.get("text"):
                add(lines, seen, s.get("voice") or auto_id(s["text"]),
                    s.get("speaker", "") if s["do"] == "say" else "", s["text"], os.path.relpath(path, ROOT), place,
                    "line" if s["do"] == "say" else "thought")
            for key in ("then", "else", "steps"):
                if isinstance(s.get(key), list):
                    walk(s[key], path, place)
    for path in sorted(glob.glob(os.path.join(ROOT, "data", "sequences", "**", "*.json"), recursive=True)):
        data = json.load(open(path, encoding="utf-8"))
        walk(data.get("steps", []), path, place_of(os.path.dirname(path)))


def from_scripts(lines, seen):
    paths = sorted(glob.glob(os.path.join(ROOT, "chapters", "**", "*.gd"), recursive=True))
    for path in paths:
        src = open(path, encoding="utf-8").read()
        rel = os.path.relpath(path, ROOT)
        place = place_of(os.path.dirname(os.path.dirname(path)) if path.endswith(".gd") else path)
        consts = {m.group(1): gd_unescape(m.group(2)) for m in re.finditer(r"const (\w+) := " + STR, src)}
        tape = (re.search(r'"(t\d)/opening_', src) or re.search(r'"(t\d)/vo_', src))
        tape = tape.group(1) if tape else None
        vo = consts.get("VO", "")
        m = re.search(r"const OPENING := \[(.*?)\n\]", src, re.S)
        if m and tape:
            for i, t in enumerate(re.findall(r"\[\s*" + STR + r"\s*,", m.group(1))):
                add(lines, seen, f"{tape}/opening_{i + 1}", vo, gd_unescape(t), rel, place)
        m = re.search(r"const VO_BEATS := \{(.*?)\n\}", src, re.S)
        if m and tape:
            for ev, t in re.findall(r'&"(\w+)":\s*\[[^,]+,\s*' + STR, m.group(1)):
                add(lines, seen, f"{tape}/vo_{ev}", vo, gd_unescape(t), rel, place)
        m = re.search(r"const ARRIVAL_THOUGHTS := \{(.*?)\n\}", src, re.S)
        if m:
            for t in re.findall(r"\[\s*" + STR + r"\s*,", m.group(1)):
                add(lines, seen, auto_id(gd_unescape(t)), "", gd_unescape(t), rel, place, "thought")
        for sp, t, rest in re.findall(r'_say(?:\.bind)?\(\s*(\w+|"[^"]*")\s*,\s*' + STR + r"([^)\n]*)\)", src):
            speaker = consts.get(sp, sp.strip('"'))
            text = gd_unescape(t)
            explicit = re.search(STR + r"\s*$", rest.strip())
            line_id = explicit.group(1) if explicit and "/" in explicit.group(1) else auto_id(text)
            add(lines, seen, line_id, speaker, text, rel, place)
        for t in re.findall(r"_think(?:\.bind)?\(\s*" + STR, src) + re.findall(r"_think_once\([^,]+,\s*" + STR, src):
            text = gd_unescape(t)
            add(lines, seen, auto_id(text), "", text, rel, place, "thought")


def build():
    lines, seen = [], set()
    from_scripts(lines, seen)
    from_sequences(lines, seen)
    from_dialogue(lines, seen)
    voiced = [ln for ln in lines if ln["kind"] != "sound"]
    for ln in lines:
        ln["file"] = f"assets/audio/voice/{ln['id']}.ogg"
        ln["recorded"] = os.path.exists(os.path.join(ROOT, ln["file"]))
    os.makedirs(os.path.dirname(OUT_JSON), exist_ok=True)
    data = {"_format": "Generated by tools/voice_lines.py: every spoken line. speak = what the voice says "
                       "(subtitle text without BBCode/translations). Do not edit: edit the source and re-run.",
            "casting": CASTING, "lines": lines}
    json.dump(data, open(OUT_JSON, "w", encoding="utf-8"), indent="\t", ensure_ascii=False)
    md = ["# Voice script", "", "Generated by `tools/voice_lines.py` (do not edit). File name for each line: "
          "`<id>` with `/` replaced by `__` (e.g. `t1__opening_1.wav`), then `python tools/voice_lines.py "
          "--install <folder>`.", "", "## Cast", ""]
    for name, c in CASTING.items():
        md.append(f"- **{name}**: {c['who']}")
    for place in dict.fromkeys(ln["place"] for ln in voiced):
        md += ["", f"## {place}", "", "| id | speaker | line |", "|---|---|---|"]
        for ln in voiced:
            if ln["place"] == place:
                md.append(f"| `{ln['id']}` | {ln['speaker']}{' (thought)' if ln['kind'] == 'thought' else ''} | "
                          f"{ln['speak'].replace('|', '/')} |")
    open(OUT_MD, "w", encoding="utf-8").write("\n".join(md) + "\n")
    words = sum(len(ln["speak"].split()) for ln in voiced)
    print(f"{len(voiced)} voice lines ({words} words, ~{words / 150:.0f} min), "
          f"{sum(ln['recorded'] for ln in voiced)} recorded -> {os.path.relpath(OUT_JSON, ROOT)}, "
          f"{os.path.relpath(OUT_MD, ROOT)}")
    return data


FILTERS = {"none": "", "radio": "highpass=f=400,lowpass=f=3000,acrusher=bits=8:mix=0.15,",
           "phone": "highpass=f=300,lowpass=f=3400,"}


def install(src_dir: str):
    data = build()
    ffmpeg = shutil.which("ffmpeg") or sys.exit("ffmpeg not found")
    done = 0
    for ln in data["lines"]:
        stem = ln["id"].replace("/", "__")
        found = [p for ext in ("wav", "mp3", "ogg", "flac") for p in glob.glob(os.path.join(src_dir, f"{stem}.{ext}"))]
        if not found:
            continue
        flt = FILTERS[data["casting"].get(ln["speaker"], {}).get("filter", "none")]
        out = os.path.join(ROOT, ln["file"])
        os.makedirs(os.path.dirname(out), exist_ok=True)
        subprocess.run([ffmpeg, "-y", "-loglevel", "error", "-i", found[0], "-af", f"{flt}loudnorm=I=-16:TP=-1.5",
                        "-ac", "1", "-ar", "44100", "-c:a", "libvorbis", "-q:a", "5", out], check=True)
        done += 1
    print(f"installed {done} voice file(s); now run Godot --import")


if __name__ == "__main__":
    ap = argparse.ArgumentParser()
    ap.add_argument("--install", metavar="DIR")
    a = ap.parse_args()
    install(a.install) if a.install else build()
