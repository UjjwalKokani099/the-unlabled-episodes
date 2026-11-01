"""Synthesises placeholder horror SFX (stdlib only) into assets/audio/sfx/.

Run from the project root:  python tools/gen_placeholder_sfx.py
Replace these with real recordings later; keep the same file names.
"""
import math
import random
import struct
import wave
from pathlib import Path

RATE = 22050
OUT = Path(__file__).resolve().parent.parent / "assets" / "audio" / "sfx"


def lowpass(samples, amount):
    out, y = [], 0.0
    for s in samples:
        y += amount * (s - y)
        out.append(y)
    return out


def silence(seconds):
    return [0.0] * int(RATE * seconds)


def mix_into(buf, sound, at_seconds):
    start = int(at_seconds * RATE)
    need = start + len(sound) - len(buf)
    if need > 0:
        buf.extend([0.0] * need)
    for i, s in enumerate(sound):
        buf[start + i] += s


def knock(rng):
    n = int(RATE * 0.18)
    noise = lowpass([rng.uniform(-1, 1) for _ in range(n)], 0.25)
    out = []
    for i in range(n):
        t = i / RATE
        body = math.sin(2 * math.pi * 110 * t) * math.exp(-t * 28)
        click = noise[i] * math.exp(-t * 60)
        out.append(0.8 * body + 0.9 * click)
    return out


def slam(rng):
    n = int(RATE * 1.4)
    noise = lowpass([rng.uniform(-1, 1) for _ in range(n)], 0.12)
    out = []
    for i in range(n):
        t = i / RATE
        thump = math.sin(2 * math.pi * (55 + 30 * math.exp(-t * 20)) * t) * math.exp(-t * 5)
        crack = noise[i] * math.exp(-t * 14)
        rattle = noise[i] * 0.25 * math.exp(-t * 3) * (0.5 + 0.5 * math.sin(2 * math.pi * 31 * t))
        out.append(thump + 1.4 * crack + rattle)
    return out


def sting(rng):
    n = int(RATE * 2.4)
    freqs = [196.0, 207.6, 277.2, 293.7, 415.3]
    noise = lowpass([rng.uniform(-1, 1) for _ in range(n)], 0.05)
    out = []
    for i in range(n):
        t = i / RATE
        env = min(t / 0.12, 1.0) * math.exp(-max(t - 0.12, 0.0) * 1.6)
        trem = 0.75 + 0.25 * math.sin(2 * math.pi * 7.0 * t)
        tone = sum(math.sin(2 * math.pi * f * t * (1.0 + 0.004 * math.sin(t * 3 + k))) for k, f in enumerate(freqs))
        out.append(env * trem * (tone / len(freqs) + 0.6 * noise[i]))
    return out


def write(name, samples):
    peak = max(abs(s) for s in samples) or 1.0
    OUT.mkdir(parents=True, exist_ok=True)
    with wave.open(str(OUT / name), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes(b"".join(struct.pack("<h", int(s / peak * 0.9 * 32767)) for s in samples))
    print("wrote", OUT / name, f"{len(samples) / RATE:.2f}s")


def main():
    rng = random.Random(1999)
    knocks = silence(0.1)
    for at in (0.0, 0.42, 0.78):
        mix_into(knocks, knock(rng), at)
    knocks += silence(0.3)
    write("knock.wav", knocks)
    write("door_slam.wav", slam(rng))
    write("sting.wav", sting(rng))


if __name__ == "__main__":
    main()
