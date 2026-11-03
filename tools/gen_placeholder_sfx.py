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


# ---- Tape 1 story sounds (added after the first set, so the rng order above is unchanged)

def intercom_buzz(rng):
    """Old building intercom: two harsh buzzes, then a gap (loops)."""
    out = []
    for _ in range(2):
        n = int(RATE * 0.4)
        for i in range(n):
            t = i / RATE
            env = min(t / 0.01, 1.0) * min((0.4 - t) / 0.01, 1.0)
            saw = ((t * 220) % 1.0) * 2 - 1
            out.append(env * (0.6 * saw + 0.4 * math.sin(2 * math.pi * 440 * t)))
        out += silence(0.15)
    return out + silence(1.2)


def breathing(rng):
    """Slow, close breathing through a cheap handset (6 s loop)."""
    n = int(RATE * 6.0)
    noise = lowpass([rng.uniform(-1, 1) for _ in range(n)], 0.18)
    out = []
    for i in range(n):
        t = i / RATE
        phase = (t % 3.0) / 3.0
        env = math.sin(math.pi * min(phase / 0.45, 1.0)) ** 2 if phase < 0.45 else             0.7 * math.sin(math.pi * min((phase - 0.5) / 0.4, 1.0)) ** 2 if 0.5 < phase < 0.9 else 0.0
        hum = 0.04 * math.sin(2 * math.pi * 50 * t)
        out.append(noise[i] * env * 1.6 + hum)
    return out


def phone_ring(rng):
    """Indian landline double ring: 400/450 Hz, ring-ring, pause (loops)."""
    out = []
    for _ in range(2):
        n = int(RATE * 0.4)
        for i in range(n):
            t = i / RATE
            env = min(t / 0.01, 1.0) * min((0.4 - t) / 0.01, 1.0)
            trill = 0.5 + 0.5 * math.sin(2 * math.pi * 25 * t)
            out.append(env * trill * (math.sin(2 * math.pi * 400 * t) + math.sin(2 * math.pi * 450 * t)) * 0.5)
        out += silence(0.2)
    return out + silence(1.8)


def footstep(rng):
    """Chappal on concrete: a soft slap."""
    n = int(RATE * 0.12)
    noise = lowpass([rng.uniform(-1, 1) for _ in range(n)], 0.3)
    return [noise[i] * math.exp(-i / RATE * 45) + 0.3 * math.sin(2 * math.pi * 90 * i / RATE) * math.exp(-i / RATE * 40)
            for i in range(n)]


def gate_creak(rng):
    """Rusty hinge: a wavering squeal."""
    n = int(RATE * 1.3)
    out = []
    ph = 0.0
    for i in range(n):
        t = i / RATE
        f = 520 + 180 * math.sin(2 * math.pi * 0.9 * t) + 60 * math.sin(2 * math.pi * 7 * t)
        ph += 2 * math.pi * f / RATE
        env = min(t / 0.08, 1.0) * min((1.3 - t) / 0.2, 1.0)
        out.append(env * (0.5 * math.sin(ph) + 0.25 * math.sin(2.01 * ph) + 0.1 * rng.uniform(-1, 1)))
    return out


def gate_clang(rng):
    """Iron gate shutting: metallic hit with ringing partials."""
    n = int(RATE * 1.6)
    out = []
    for i in range(n):
        t = i / RATE
        ring = sum(math.sin(2 * math.pi * f * t) * a for f, a in ((180, 0.5), (437, 0.35), (811, 0.25), (1290, 0.15)))
        out.append(ring * math.exp(-t * 3.5) + rng.uniform(-1, 1) * math.exp(-t * 40) * 0.8)
    return out


def power_down(rng):
    """Mains dying: a clunk and the hum winding down."""
    n = int(RATE * 2.2)
    out = []
    ph = 0.0
    for i in range(n):
        t = i / RATE
        f = 100 * math.exp(-t * 1.4) + 20
        ph += 2 * math.pi * f / RATE
        out.append(0.5 * math.sin(ph) * math.exp(-t * 1.2) + rng.uniform(-1, 1) * math.exp(-t * 30) * 0.9)
    return out


def switch_clack(rng):
    """Big main switch lever thrown."""
    n = int(RATE * 0.35)
    noise = lowpass([rng.uniform(-1, 1) for _ in range(n)], 0.4)
    return [noise[i] * math.exp(-i / RATE * 25) + 0.6 * math.sin(2 * math.pi * 140 * i / RATE) * math.exp(-i / RATE * 18)
            for i in range(n)]


# ---- Phase 3: footsteps per surface, drawers, handling items (appended: rng order kept)

def _env_noise(rng, seconds, lp, decay):
    n = int(RATE * seconds)
    noise = lowpass([rng.uniform(-1, 1) for _ in range(n)], lp)
    return [noise[i] * math.exp(-i / RATE * decay) for i in range(n)]


def step_concrete(rng):
    grit = _env_noise(rng, 0.16, 0.35, 32)
    return [g + 0.45 * math.sin(2 * math.pi * 85 * i / RATE) * math.exp(-i / RATE * 45) for i, g in enumerate(grit)]


def step_tile(rng):
    click = _env_noise(rng, 0.12, 0.7, 60)
    return [c + 0.25 * math.sin(2 * math.pi * 1900 * i / RATE) * math.exp(-i / RATE * 70) for i, c in enumerate(click)]


def step_wood(rng):
    knock = _env_noise(rng, 0.2, 0.15, 30)
    return [k * 0.6 + 0.7 * math.sin(2 * math.pi * 170 * i / RATE) * math.exp(-i / RATE * 28) for i, k in enumerate(knock)]


def step_metal(rng):
    n = int(RATE * 0.35)
    out = []
    for i in range(n):
        t = i / RATE
        ring = sum(math.sin(2 * math.pi * f * t) * a for f, a in ((410, 0.4), (1130, 0.3), (2270, 0.2)))
        out.append(ring * math.exp(-t * 14) + rng.uniform(-1, 1) * math.exp(-t * 60) * 0.6)
    return out


def step_dirt(rng):
    n = int(RATE * 0.2)
    out = []
    for i in range(n):
        t = i / RATE
        grain = rng.uniform(-1, 1) * (1.0 if rng.random() < 0.3 else 0.2)
        out.append(grain * math.exp(-t * 18))
    return lowpass(out, 0.5)


def step_soft(rng):
    return lowpass(_env_noise(rng, 0.15, 0.08, 30), 0.3)


def drawer_slide(rng):
    n = int(RATE * 0.45)
    noise = lowpass([rng.uniform(-1, 1) for _ in range(n)], 0.25)
    out = []
    for i in range(n):
        t = i / RATE
        chatter = 0.6 + 0.4 * math.sin(2 * math.pi * 38 * t)
        env = min(t / 0.04, 1.0) * min((0.45 - t) / 0.08, 1.0)
        out.append(noise[i] * chatter * env)
    return out


def rustle(rng):
    n = int(RATE * 0.3)
    out = []
    for i in range(n):
        t = i / RATE
        out.append(rng.uniform(-1, 1) * (0.3 + 0.7 * rng.random() ** 6) * math.sin(math.pi * t / 0.3))
    return lowpass(out, 0.6)


def tube_hum(rng):
    """Fluorescent tube + choke: 100 Hz mains buzz with harmonics and a faint crackle.
    Exactly 200 cycles (2 s) so the loop is seamless."""
    n = int(RATE * 2.0)
    crackle = [rng.uniform(-1, 1) if rng.random() < 0.002 else 0.0 for _ in range(n)]
    out = []
    for i in range(n):
        t = i / RATE
        buzz = (math.sin(2 * math.pi * 100 * t) * 0.5 + math.sin(2 * math.pi * 200 * t) * 0.25
                + math.sin(2 * math.pi * 300 * t) * 0.18 + math.sin(2 * math.pi * 500 * t) * 0.07)
        out.append(buzz * 0.6 + crackle[i] * 0.4)
    return out


def train_far(rng):
    """A local train far away: two-tone horn, then the rumble of the rake passing."""
    n = int(RATE * 7.0)
    rumble = lowpass([rng.uniform(-1, 1) for _ in range(n)], 0.01)
    out = []
    for i in range(n):
        t = i / RATE
        horn = 0.0
        for start, length, f in ((0.3, 0.9, 311.0), (1.35, 1.6, 277.0)):
            if start <= t < start + length:
                env = min((t - start) / 0.08, 1.0, (start + length - t) / 0.2)
                horn += env * (math.sin(2 * math.pi * f * t) + 0.5 * math.sin(2 * math.pi * f * 2 * t)
                               + 0.3 * math.sin(2 * math.pi * f * 1.5 * t))
        clack = 1.0 + 0.4 * (math.sin(2 * math.pi * 1.7 * t) > 0.92)
        swell = math.sin(min(t / 7.0, 1.0) * math.pi)
        out.append(horn * 0.35 + rumble[i] * 9.0 * swell * clack)
    return lowpass(out, 0.15)


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
    write("intercom_buzz.wav", intercom_buzz(rng))
    write("breathing.wav", breathing(rng))
    write("phone_ring.wav", phone_ring(rng))
    write("footstep_chappal.wav", footstep(rng))
    write("gate_creak.wav", gate_creak(rng))
    write("gate_clang.wav", gate_clang(rng))
    write("power_down.wav", power_down(rng))
    write("switch_clack.wav", switch_clack(rng))
    for name, fn in (("step_concrete", step_concrete), ("step_tile", step_tile), ("step_wood", step_wood),
                     ("step_metal", step_metal), ("step_dirt", step_dirt), ("step_soft", step_soft),
                     ("drawer_slide", drawer_slide), ("rustle", rustle)):
        write(name + ".wav", fn(rng))
    write("tube_hum.wav", tube_hum(rng))
    write("train_far.wav", train_far(rng))


if __name__ == "__main__":
    main()
