"""Turns raw bed recordings into game-ready looping OGGs with consistent loudness.

Run from the project root (needs ffmpeg on PATH):
    python tools/gen_placeholder_sfx.py     # writes tools/_build/beds/<folder>/<name>.wav
    python tools/process_audio.py           # -> assets/audio/<folder>/<name>.ogg
    <console exe> --headless --path . --import ; python tools/process_audio.py --imports

Loudness targets (EBU R128 integrated, two-pass ffmpeg loudnorm, true peak <= -1.5 dBTP):
    ambience beds  -30 LUFS   (room tone, wind, crickets... sit under everything)
    tension layers -28 LUFS   (mixed in by AudioManager.set_tension)
    music          -24 LUFS   (main menu drone)
    voice          -16 LUFS   (when VO exists: tools/_build/voice/<id>.wav)
Short SFX stay WAV, peak-normalised by the generator, and are balanced by per-use volume.
To use a real recording, drop its WAV in tools/_build/beds/<folder>/ with the same name.
--imports sets loop=true on every OGG under assets/audio/ambience|tension|music after import.
"""
import glob
import json
import os
import re
import subprocess
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(ROOT, "tools", "_build", "beds")
TARGETS = {"ambience": -30.0, "tension": -28.0, "music": -24.0, "voice": -16.0}
TRUE_PEAK = -1.5


def measure(path: str) -> dict:
    out = subprocess.run(["ffmpeg", "-hide_banner", "-nostats", "-i", path, "-af",
                          f"loudnorm=I=-24:TP={TRUE_PEAK}:LRA=11:print_format=json", "-f", "null", "-"],
                         capture_output=True, text=True).stderr
    return json.loads(out[out.rindex("{"):out.rindex("}") + 1])


def process(src: str, dst: str, target: float) -> float:
    m = measure(src)
    af = (f"loudnorm=I={target}:TP={TRUE_PEAK}:LRA=11:measured_I={m['input_i']}:measured_TP={m['input_tp']}"
          f":measured_LRA={m['input_lra']}:measured_thresh={m['input_thresh']}:offset={m['target_offset']}:linear=true")
    os.makedirs(os.path.dirname(dst), exist_ok=True)
    subprocess.run(["ffmpeg", "-hide_banner", "-loglevel", "error", "-y", "-i", src, "-af", af,
                    "-ar", "44100", "-c:a", "libvorbis", "-q:a", "4", dst], check=True)
    return float(measure(dst)["input_i"])


def set_loop_imports() -> None:
    n = 0
    for folder in ("ambience", "tension", "music"):
        for imp in glob.glob(os.path.join(ROOT, "assets", "audio", folder, "*.ogg.import")):
            text = open(imp, encoding="utf-8").read()
            new = re.sub(r"^loop=.*$", "loop=true", text, flags=re.M)
            if new != text:
                open(imp, "w", encoding="utf-8", newline="\n").write(new)
                n += 1
    print(f"set loop on {n} imports")


def main() -> int:
    if "--imports" in sys.argv:
        set_loop_imports()
        return 0
    for folder, target in TARGETS.items():
        for src in sorted(glob.glob(os.path.join(SRC, folder, "*.wav"))):
            name = os.path.splitext(os.path.basename(src))[0]
            dst = os.path.join(ROOT, "assets", "audio", folder, name + ".ogg")
            got = process(src, dst, target)
            print(f"{folder}/{name}.ogg  {got:.1f} LUFS (target {target})")
    return 0


if __name__ == "__main__":
    sys.exit(main())
