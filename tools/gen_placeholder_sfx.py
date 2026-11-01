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


def vcr_insert(rng):
    n = int(RATE * 1.3)
    noise = lowpass([rng.uniform(-1, 1) for _ in range(n)], 0.2)
    out = []
    for i in range(n):
        t = i / RATE
        clunk1 = (noise[i] * 1.2 + math.sin(2 * math.pi * 140 * t)) * math.exp(-t * 35)
        t2 = t - 0.32
        clunk2 = (noise[i] + math.sin(2 * math.pi * 95 * t)) * math.exp(-t2 * 30) if t2 > 0 else 0.0
        t3 = t - 0.45
        motor = 0.0
        if t3 > 0:
            whirr = math.sin(2 * math.pi * (180 + 40 * min(t3 / 0.3, 1.0)) * t)
            motor = 0.25 * (whirr + 0.4 * noise[i]) * min(t3 / 0.1, 1.0) * math.exp(-max(t3 - 0.6, 0) * 8)
        out.append(clunk1 + clunk2 + motor)
    return out


def tv_static(rng):
    n = int(RATE * 2.0)
    raw = [rng.uniform(-1, 1) for _ in range(n)]
    hiss = lowpass(raw, 0.6)
    out = []
    for i in range(n):
        t = i / RATE
        # Fade the very ends so the loop restart doesn't click.
        edge = min(t / 0.02, 1.0, (2.0 - t) / 0.02)
        out.append(edge * hiss[i])
    return out


def beep(freq, seconds, rng):
    n = int(RATE * seconds)
    out = []
    for i in range(n):
        t = i / RATE
        env = min(t / 0.004, 1.0) * min((seconds - t) / 0.01, 1.0)
        square = 1.0 if math.sin(2 * math.pi * freq * t) > 0 else -1.0
        out.append(env * (0.35 * square + 0.65 * math.sin(2 * math.pi * freq * t)))
    return out


def doorbell(rng):
    out = []
    for freq, start in ((659.3, 0.0), (523.3, 0.55)):
        seg = [0.0] * int(RATE * start)
        for i in range(int(RATE * 1.4)):
            t = i / RATE
            env = math.exp(-t * 2.6)
            seg.append(env * (math.sin(2 * math.pi * freq * t) + 0.3 * math.sin(2 * math.pi * freq * 2.76 * t)))
        if not out:
            out = seg
        else:
            out += [0.0] * (len(seg) - len(out))
            out = [a + b for a, b in zip(out, seg)]
    return out


def fan_hum(rng):
    n = int(RATE * 3.0)
    hiss = lowpass([rng.uniform(-1, 1) for _ in range(n)], 0.04)
    out = []
    for i in range(n):
        t = i / RATE
        edge = min(t / 0.02, 1.0, (3.0 - t) / 0.02)
        whoosh = 0.6 + 0.4 * math.sin(2 * math.pi * 4.0 * t)
        out.append(edge * (0.25 * math.sin(2 * math.pi * 50 * t) + hiss[i] * 2.5 * whoosh))
    return out


def vcr_click(rng):
    n = int(RATE * 0.09)
    noise = [rng.uniform(-1, 1) for _ in range(n)]
    return [(noise[i] * 0.7 + math.sin(2 * math.pi * 1800 * i / RATE) * 0.5) * math.exp(-i / RATE * 90) for i in range(n)]


def room_hum(rng):
    n = int(RATE * 4.0)
    air = lowpass([rng.uniform(-1, 1) for _ in range(n)], 0.02)
    out = []
    for i in range(n):
        t = i / RATE
        edge = min(t / 0.02, 1.0, (4.0 - t) / 0.02)
        out.append(edge * (0.35 * math.sin(2 * math.pi * 50 * t) + 0.15 * math.sin(2 * math.pi * 100 * t) + air[i] * 3.0))
    return out


def crickets(rng):
    n = int(RATE * 6.0)
    out = [0.0] * n
    for voice in range(5):
        f = rng.uniform(3800, 5200)
        period = rng.uniform(0.35, 0.6)
        start = rng.uniform(0, period)
        amp = rng.uniform(0.15, 0.35)
        t0 = start
        while t0 < 5.9:
            for k in range(3):  # each chirp = 3 pulses
                p0 = int((t0 + k * 0.022) * RATE)
                for i in range(int(0.014 * RATE)):
                    if p0 + i < n:
                        e = math.sin(math.pi * i / (0.014 * RATE))
                        out[p0 + i] += amp * e * math.sin(2 * math.pi * f * i / RATE)
            t0 += period * rng.uniform(0.9, 1.1)
    edge = int(0.02 * RATE)
    for i in range(edge):
        out[i] *= i / edge
        out[-1 - i] *= i / edge
    return out


def dog_bark(rng):
    out = silence(0.05)
    for b in range(rng.randint(2, 3)):
        n = int(RATE * 0.22)
        noise = lowpass([rng.uniform(-1, 1) for _ in range(n)], 0.35)
        bark = []
        for i in range(n):
            t = i / RATE
            f = 520 - 900 * t
            env = min(t / 0.015, 1.0) * math.exp(-t * 14)
            bark.append(env * (0.6 * math.sin(2 * math.pi * f * t) + 0.5 * math.sin(2 * math.pi * f * 2.1 * t) + 0.6 * noise[i]))
        out += lowpass(bark, 0.25) + silence(rng.uniform(0.12, 0.3))
    return out


def traffic(rng):
    n = int(RATE * 8.0)
    rumble = lowpass(lowpass([rng.uniform(-1, 1) for _ in range(n)], 0.01), 0.05)
    out = []
    for i in range(n):
        t = i / RATE
        edge = min(t / 0.05, 1.0, (8.0 - t) / 0.05)
        swell = 0.6 + 0.4 * math.sin(2 * math.pi * t / 8.0)
        out.append(edge * rumble[i] * swell)
    return out


def horn(rng):
    n = int(RATE * 0.9)
    return [math.sin(2 * math.pi * 420 * i / RATE) * 0.6 + math.sin(2 * math.pi * 530 * i / RATE) * 0.4
            for i in range(n)]


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
    write("vcr_insert.wav", vcr_insert(rng))
    write("tv_static.wav", tv_static(rng))
    write("ui_blip.wav", [x * 0.5 for x in beep(1200, 0.035, rng)])
    select = beep(880, 0.05, rng) + beep(1320, 0.07, rng)
    write("ui_select.wav", select)
    write("doorbell.wav", doorbell(rng))
    write("fan_hum.wav", fan_hum(rng))
    write("vcr_click.wav", vcr_click(rng))
    write("room_hum.wav", room_hum(rng))
    write("crickets_loop.wav", crickets(rng))
    write("dog_bark.wav", dog_bark(rng))
    write("traffic_loop.wav", traffic(rng))
    write("horn_far.wav", lowpass(horn(rng), 0.08))


if __name__ == "__main__":
    main()
