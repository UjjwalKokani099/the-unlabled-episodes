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


def objective_tick(rng):
    """Objective update: a soft pencil tick then a low two-note chime, quiet and short."""
    out = []
    n = int(RATE * 0.55)
    for i in range(n):
        t = i / RATE
        tick = rng.uniform(-1, 1) * math.exp(-t * 160) * 0.35
        a = math.sin(2 * math.pi * 523.3 * t) * math.exp(-max(t - 0.05, 0) * 7) * (t > 0.05)
        b = math.sin(2 * math.pi * 659.3 * t) * math.exp(-max(t - 0.16, 0) * 6) * (t > 0.16)
        out.append(tick + (a * 0.22 + b * 0.18) * min(1.0, t * 40))
    return out


def phone_buzz(rng):
    """Phone vibrating on a hard surface: two short 160 Hz rattling pulses."""
    out = []
    n = int(RATE * 0.9)
    for i in range(n):
        t = i / RATE
        on = (0.0 < t < 0.32) or (0.48 < t < 0.8)
        env = (min((t % 0.48) * 30, 1.0)) if on else 0.0
        buzz = math.sin(2 * math.pi * 160 * t) * 0.6 + (rng.uniform(-1, 1) * 0.25 if on else 0.0)
        out.append(buzz * env * 0.6)
    return lowpass(out, 0.5)


def mobile_ring(rng):
    """Nikhil's mobile ringtone: a soft three-note marimba figure, 2 s (loops)."""
    out = [0.0] * int(RATE * 2.0)
    for start, f in ((0.0, 880.0), (0.18, 1108.7), (0.36, 1318.5), (0.72, 880.0), (0.9, 1108.7), (1.08, 1318.5)):
        s0 = int(start * RATE)
        for i in range(int(RATE * 0.5)):
            t = i / RATE
            v = (math.sin(2 * math.pi * f * t) + 0.3 * math.sin(2 * math.pi * f * 4 * t) * math.exp(-t * 30)) \
                * math.exp(-t * 7) * 0.32
            if s0 + i < len(out):
                out[s0 + i] += v
    return out


def tape_runout(rng):
    """End of a tape: the hiss of blank tape thinning out over 4 s, a low hum under it, then
    the deck's mechanical stop clunk."""
    n = int(RATE * 5.2)
    out = []
    y = 0.0
    for i in range(n):
        t = i / RATE
        y = y * 0.6 + rng.uniform(-1, 1) * 0.4
        fade = max(0.0, 1.0 - t / 4.2) ** 1.6
        hum = math.sin(2 * math.pi * 50 * t) * 0.08 * fade
        clunk = 0.0
        if t > 4.6:
            k = t - 4.6
            clunk = (math.sin(2 * math.pi * 70 * k) * 0.8 + rng.uniform(-1, 1) * 0.4) * math.exp(-k * 25)
        out.append(y * 0.35 * fade + hum + clunk)
    return out


def light_flicker(rng):
    """A tube light dropping out for a moment: the starter's dry tick and a short choke buzz."""
    n = int(RATE * 0.16)
    out = []
    for i in range(n):
        t = i / RATE
        tick = rng.uniform(-1, 1) * math.exp(-t * 160) * 0.8
        buzz = (math.sin(2 * math.pi * 100 * t) + 0.5 * math.sin(2 * math.pi * 200 * t)
                + 0.25 * math.copysign(1, math.sin(2 * math.pi * 300 * t))) * 0.22 * math.exp(-t * 22)
        out.append(tick + buzz + rng.uniform(-1, 1) * 0.04 * math.exp(-t * 30))
    return out


def pipe_creak(rng):
    """An old water pipe ticking and groaning as it cools: three ticks and a low bend."""
    n = int(RATE * 1.8)
    out = [0.0] * n
    for at in (0.0, 0.31, 0.55 + rng.uniform(0, 0.1)):
        k0 = int(at * RATE)
        for i in range(int(RATE * 0.05)):
            if k0 + i < n:
                t = i / RATE
                out[k0 + i] += (math.sin(2 * math.pi * 2300 * t) * 0.4 + rng.uniform(-1, 1) * 0.3) * math.exp(-t * 120)
    phase = 0.0
    for i in range(int(RATE * 0.8), n):
        t = (i - RATE * 0.8) / RATE
        f = 95 + 30 * math.sin(t * 3.1) + rng.uniform(-3, 3)
        phase += 2 * math.pi * f / RATE
        env = math.sin(math.pi * min(t / 1.0, 1.0)) * 0.35
        out[i] += (math.sin(phase) + 0.4 * math.sin(phase * 2.01)) * env
    return lowpass(out, 0.3)


def lathi_tap(rng):
    """Far away, another building's watchman doing his round: his stick tapped on the road
    three times, then two blasts on his whistle."""
    n = int(RATE * 3.2)
    out = [0.0] * n
    for at in (0.0, 0.62, 1.2):
        k0 = int(at * RATE)
        for i in range(int(RATE * 0.12)):
            t = i / RATE
            out[k0 + i] += (rng.uniform(-1, 1) * 0.6 + math.sin(2 * math.pi * 420 * t) * 0.4) * math.exp(-t * 55)
    for at, length in ((1.8, 0.35), (2.3, 0.6)):
        k0 = int(at * RATE)
        for i in range(int(RATE * length)):
            t = i / RATE
            trill = 1.0 + 0.04 * math.sin(2 * math.pi * 32 * t)
            env = min(t / 0.03, 1.0) * min((length - t) / 0.08, 1.0)
            out[k0 + i] += math.sin(2 * math.pi * 2650 * trill * t) * 0.35 * env + rng.uniform(-1, 1) * 0.05 * env
    return lowpass(out, 0.25)


def cooker_whistle(rng):
    """A pressure cooker whistling in a flat across the lane: the hiss rising into a shriek."""
    n = int(RATE * 2.6)
    out = []
    y = 0.0
    for i in range(n):
        t = i / RATE
        rise = min(t / 0.7, 1.0)
        env = rise * min((2.6 - t) / 0.5, 1.0)
        y = y * 0.5 + rng.uniform(-1, 1) * 0.5
        tone = math.sin(2 * math.pi * (1700 + 500 * rise) * t) * 0.3 * rise
        out.append((y * 0.25 + tone) * env)
    return lowpass(out, 0.35)


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


def resample(samples, factor):
    """Speed up (>1) or slow down (<1) by linear interpolation: shifts pitch and length."""
    n = int(len(samples) / factor)
    out = []
    for i in range(n):
        x = i * factor
        j = int(x)
        f = x - j
        a = samples[j] if j < len(samples) else 0.0
        b = samples[j + 1] if j + 1 < len(samples) else 0.0
        out.append(a + (b - a) * f)
    return out


def step_gravel(rng):
    """Crunch: many tiny grains over ~0.2 s plus a dull thud."""
    n = int(RATE * 0.22)
    out = [0.0] * n
    for _ in range(70):
        at = int(rng.uniform(0, 0.16) * RATE)
        amp = rng.uniform(0.2, 1.0)
        for k in range(int(RATE * 0.004)):
            if at + k < n:
                out[at + k] += amp * rng.uniform(-1, 1) * math.exp(-k / (RATE * 0.0012))
    thud = [0.5 * math.sin(2 * math.pi * 75 * i / RATE) * math.exp(-i / RATE * 35) for i in range(n)]
    return [a + b for a, b in zip(out, thud)]


def step_grass(rng):
    """Swish of blades + a soft press."""
    n = int(RATE * 0.25)
    swish = lowpass([rng.uniform(-1, 1) for _ in range(n)], 0.35)
    return [swish[i] * math.sin(math.pi * min(i / n * 1.6, 1.0)) * math.exp(-i / RATE * 9) * 0.8
            + 0.3 * math.sin(2 * math.pi * 60 * i / RATE) * math.exp(-i / RATE * 30) for i in range(n)]


def door_creak(rng):
    """Interior door hinge: a short wavering creak (pitch differs per variant)."""
    n = int(RATE * rng.uniform(0.6, 0.9))
    base = rng.uniform(420, 700)
    out = []
    ph = 0.0
    for i in range(n):
        t = i / RATE
        f = base * (1 + 0.15 * math.sin(2 * math.pi * rng.uniform(5, 9) * t) + 0.25 * t)
        ph += 2 * math.pi * f / RATE
        stick = 0.6 + 0.4 * (math.sin(2 * math.pi * 31 * t) > 0.2)
        env = min(t / 0.05, 1.0) * max(0.0, 1 - t / (n / RATE))
        out.append(env * stick * (math.sin(ph) + 0.4 * math.sin(2.7 * ph)) * 0.6)
    return lowpass(out, 0.5)


def door_latch(rng):
    """Door shutting: thump of the leaf + the latch clicking home."""
    n = int(RATE * 0.35)
    noise = [rng.uniform(-1, 1) for _ in range(n)]
    out = [0.8 * math.sin(2 * math.pi * 95 * i / RATE) * math.exp(-i / RATE * 22) + noise[i] * 0.3 * math.exp(-i / RATE * 60)
           for i in range(n)]
    click_at = int(RATE * rng.uniform(0.03, 0.06))
    for k in range(int(RATE * 0.02)):
        if click_at + k < n:
            out[click_at + k] += 0.7 * math.sin(2 * math.pi * 2600 * k / RATE) * math.exp(-k / RATE * 300)
    return out


def door_rattle(rng):
    """Locked: the handle pushed down and the door knocking in its frame, 3-4 times."""
    buf = silence(0.05)
    for j in range(rng.randint(3, 4)):
        hit = [0.7 * math.sin(2 * math.pi * rng.uniform(150, 190) * i / RATE) * math.exp(-i / RATE * 30)
               + rng.uniform(-1, 1) * 0.5 * math.exp(-i / RATE * 90) for i in range(int(RATE * 0.12))]
        mix_into(buf, hit, 0.05 + j * rng.uniform(0.09, 0.12))
    return buf + silence(0.1)


def switch_click(rng):
    """Indian modular wall switch: a crisp plastic snap."""
    n = int(RATE * 0.06)
    f = rng.uniform(2200, 3200)
    return [(rng.uniform(-1, 1) * 0.6 + math.sin(2 * math.pi * f * i / RATE)) * math.exp(-i / RATE * 140) for i in range(n)]


def pickup(rng):
    """Taking something: a cloth/paper brush and a light tap."""
    out = lowpass([rng.uniform(-1, 1) * math.sin(math.pi * i / (RATE * 0.18)) for i in range(int(RATE * 0.18))], 0.4)
    tap = [0.5 * math.sin(2 * math.pi * rng.uniform(300, 500) * i / RATE) * math.exp(-i / RATE * 60) for i in range(int(RATE * 0.08))]
    mix_into(out, tap, 0.1)
    return out


def interact_tick(rng):
    """Generic soft feedback when using something that has no sound of its own."""
    n = int(RATE * 0.05)
    return [math.sin(2 * math.pi * rng.uniform(900, 1200) * i / RATE) * math.exp(-i / RATE * 90) * 0.5 for i in range(n)]


# ---- seamless ambience beds + tension layers (written as WAV, then tools/process_audio.py
# makes loudness-normalised looping OGGs in assets/audio/ambience/ and assets/audio/tension/)

def seamless(fn, seconds, rng, fade=0.5):
    """Render `seconds` + `fade` of a bed and fold the tail over the head: loops with no seam."""
    raw = fn(rng, seconds + fade)
    n, f = int(RATE * seconds), int(RATE * fade)
    out = raw[:n]
    for i in range(f):
        t = i / f
        out[i] = out[i] * t + raw[n + i] * (1 - t)
    return out


def bed_room_tone(rng, seconds):
    """Air in a quiet room: very soft broadband hiss with a faint 50 Hz mains."""
    n = int(RATE * seconds)
    air = lowpass([rng.uniform(-1, 1) for _ in range(n)], 0.05)
    return [air[i] * 2.0 + 0.05 * math.sin(2 * math.pi * 50 * i / RATE) for i in range(n)]


def bed_fridge(rng, seconds):
    """Old fridge compressor: 50 Hz + harmonics with a slow wobble."""
    n = int(RATE * seconds)
    air = lowpass([rng.uniform(-1, 1) for _ in range(n)], 0.03)
    out = []
    for i in range(n):
        t = i / RATE
        w = 1 + 0.08 * math.sin(2 * math.pi * 0.3 * t)
        out.append((0.4 * math.sin(2 * math.pi * 50 * t) + 0.25 * math.sin(2 * math.pi * 100 * t * w)
                    + 0.1 * math.sin(2 * math.pi * 150 * t)) * 0.7 + air[i])
    return out


def bed_wind(rng, seconds):
    """Night breeze between buildings: filtered noise swelling and easing."""
    n = int(RATE * seconds)
    a = lowpass([rng.uniform(-1, 1) for _ in range(n)], 0.02)
    b = lowpass([rng.uniform(-1, 1) for _ in range(n)], 0.006)
    return [(a[i] * 3.0 + b[i] * 6.0) * (0.55 + 0.45 * math.sin(2 * math.pi * i / RATE / 7.3 + 1.0)) for i in range(n)]


def bed_rain(rng, seconds):
    """Steady rain: dense droplets over a soft wash."""
    n = int(RATE * seconds)
    wash = lowpass([rng.uniform(-1, 1) for _ in range(n)], 0.25)
    out = [w * 0.6 for w in wash]
    for _ in range(int(seconds * 900)):
        at = rng.randrange(n)
        amp = rng.uniform(0.05, 0.4)
        for k in range(60):
            if at + k < n:
                out[at + k] += amp * math.exp(-k / 8.0) * rng.uniform(-1, 1)
    return out


def bed_electric(rng, seconds):
    """Meter room: transformer hum (100 Hz rich) with the odd crackle."""
    n = int(RATE * seconds)
    out = []
    for i in range(n):
        t = i / RATE
        buzz = sum(math.sin(2 * math.pi * 100 * k * t) / k for k in range(1, 7))
        out.append(buzz * 0.35 + (rng.uniform(-1, 1) * 0.8 if rng.random() < 0.0008 else 0.0))
    return out


def bed_drone_low(rng, seconds):
    """Tension 1: two detuned low tones beating slowly, under a dark wash."""
    n = int(RATE * seconds)
    wash = lowpass([rng.uniform(-1, 1) for _ in range(n)], 0.01)
    return [0.45 * math.sin(2 * math.pi * 55 * i / RATE) + 0.4 * math.sin(2 * math.pi * 55.6 * i / RATE)
            + 0.15 * math.sin(2 * math.pi * 82.4 * i / RATE) + wash[i] * 4 for i in range(n)]


def bed_drone_high(rng, seconds):
    """Tension 2: a thin dissonant cluster with slow tremolo (only at high intensity)."""
    n = int(RATE * seconds)
    out = []
    for i in range(n):
        t = i / RATE
        trem = 0.6 + 0.4 * math.sin(2 * math.pi * 0.17 * t)
        out.append(trem * (math.sin(2 * math.pi * 466.2 * t) + 0.8 * math.sin(2 * math.pi * 493.9 * t)
                           + 0.5 * math.sin(2 * math.pi * 698.5 * t)) * 0.3)
    return lowpass(out, 0.3)


def bed_rumble(rng, seconds):
    """Tension 3: sub rumble (brown noise, very low)."""
    n = int(RATE * seconds)
    out, y = [], 0.0
    for _ in range(n):
        y = (y + rng.uniform(-1, 1) * 0.02) * 0.998
        out.append(y)
    return lowpass(out, 0.02)


def bed_menu_drone(rng, seconds):
    """Main menu: a slow, dark pad (A, E, a flat ninth detuned) breathing over tape hiss.
    Swells every 8 s; 24 s loop."""
    n = int(RATE * seconds)
    hiss = lowpass([rng.uniform(-1, 1) for _ in range(n)], 0.18)
    out = []
    for i in range(n):
        t = i / RATE
        swell = 0.55 + 0.45 * math.sin(2 * math.pi * t / 8.0 - 1.2)
        pad = (0.5 * math.sin(2 * math.pi * 55.0 * t) + 0.35 * math.sin(2 * math.pi * 55.35 * t)
               + 0.28 * math.sin(2 * math.pi * 82.41 * t) * swell
               + 0.12 * math.sin(2 * math.pi * 116.54 * t) * swell * swell
               + 0.08 * math.sin(2 * math.pi * 164.81 * t + math.sin(2 * math.pi * 0.25 * t)))
        out.append(pad + hiss[i] * 0.35)
    return lowpass(out, 0.35)


def boot_sting(rng):
    """Studio logo: a tape-head thunk, then a low swell that hangs and decays (3 s)."""
    n = int(RATE * 3.0)
    out = []
    for i in range(n):
        t = i / RATE
        thunk = math.sin(2 * math.pi * 48 * t) * math.exp(-t * 18) * 1.2 + rng.uniform(-1, 1) * math.exp(-t * 60) * 0.5
        env = min(t / 0.6, 1.0) * math.exp(-max(t - 0.6, 0.0) * 1.3)
        swell = (math.sin(2 * math.pi * 55 * t) + 0.6 * math.sin(2 * math.pi * 82.4 * t)
                 + 0.3 * math.sin(2 * math.pi * 110.3 * t)) * env * 0.45
        out.append(thunk + swell)
    return lowpass(out, 0.4)


BEDS = {  # name: (generator, seconds, folder)
    "room_tone": (bed_room_tone, 10.0, "ambience"), "fridge": (bed_fridge, 8.0, "ambience"),
    "wind": (bed_wind, 14.6, "ambience"), "rain": (bed_rain, 10.0, "ambience"),
    "electric": (bed_electric, 8.0, "ambience"),
    "drone_low": (bed_drone_low, 12.0, "tension"), "drone_high": (bed_drone_high, 11.76, "tension"),
    "rumble": (bed_rumble, 10.0, "tension"),
    "menu_drone": (bed_menu_drone, 24.0, "music"),
}


def write_beds(rng):
    import shutil
    beds = OUT.parent.parent.parent / "tools" / "_build" / "beds" / "ambience"
    beds.mkdir(parents=True, exist_ok=True)
    for loop in ("crickets", "traffic"):  # the night beds written above become ambience OGGs too
        shutil.copy(OUT / f"{loop}_loop.wav", beds / f"{loop}.wav")
    for name, (fn, seconds, folder) in BEDS.items():
        write(f"../../../tools/_build/beds/{folder}/{name}.wav", seamless(fn, seconds, rng))


# name: (generator, variants)  -> assets/audio/sfx/variants/<name>_<n>.wav + data/sounds/<name>.tres
SOUND_SETS = {
    "step_concrete": "step_concrete", "step_tile": "step_tile", "step_wood": "step_wood",
    "step_metal": "step_metal", "step_gravel": "step_gravel", "step_grass": "step_grass",
    "step_carpet": "step_soft", "door_creak": "door_creak", "door_latch": "door_latch",
    "door_rattle": "door_rattle", "switch_click": "switch_click", "pickup": "pickup",
    "interact_tick": "interact_tick",
}
VARIANTS = 5


def write_sound_sets(rng):
    root = OUT.parent.parent.parent
    sets_dir = root / "data" / "sounds"
    sets_dir.mkdir(parents=True, exist_ok=True)
    gens = globals()
    for set_name, fn in SOUND_SETS.items():
        paths = []
        for v in range(1, VARIANTS + 1):
            samples = resample(gens[fn](rng), rng.uniform(0.94, 1.06))
            rel = f"variants/{set_name}_{v}.wav"
            write(rel, samples)
            paths.append(f"res://assets/audio/sfx/{rel}")
        ext = "\n".join(f'[ext_resource type="AudioStream" path="{p}" id="{i + 1}_s"]' for i, p in enumerate(paths))
        streams = ", ".join(f'ExtResource("{i + 1}_s")' for i in range(len(paths)))
        text = (f'[gd_resource type="Resource" script_class="SoundSet" format=3]\n\n'
                f'[ext_resource type="Script" path="res://systems/audio/sound_set.gd" id="0_script"]\n{ext}\n\n'
                f'[resource]\nscript = ExtResource("0_script")\nstreams = Array[AudioStream]([{streams}])\n')
        (sets_dir / f"{set_name}.tres").write_text(text, encoding="utf-8", newline="\n")
    print(f"wrote {len(SOUND_SETS)} sound sets x {VARIANTS} variants")


def write(name, samples):
    peak = max(abs(s) for s in samples) or 1.0
    OUT.mkdir(parents=True, exist_ok=True)
    (OUT / name).parent.mkdir(parents=True, exist_ok=True)
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
    write("objective_update.wav", objective_tick(random.Random(55)))
    write("phone_buzz.wav", phone_buzz(random.Random(56)))
    write("mobile_ring.wav", mobile_ring(random.Random(57)))
    write("tape_runout.wav", tape_runout(random.Random(58)))
    write("light_flicker.wav", light_flicker(random.Random(59)))
    write("pipe_creak.wav", pipe_creak(random.Random(60)))
    write("lathi_tap.wav", lathi_tap(random.Random(61)))
    write("cooker_whistle.wav", cooker_whistle(random.Random(62)))
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
    # Variant sets (separate seed so adding sets never changes the files above).
    write_sound_sets(random.Random(4242))
    write_beds(random.Random(777))
    write("boot_sting.wav", boot_sting(random.Random(31)))


if __name__ == "__main__":
    main()
