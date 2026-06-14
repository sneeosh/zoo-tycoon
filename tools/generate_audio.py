#!/usr/bin/env python3
"""Generate the game's SFX + ambient loop as committed WAV assets.

Build-time asset generation, mirroring the sprite pipeline (CLAUDE.md §5:
generate at build time and commit — never at runtime, per the engine's
web-performance discipline). Pure stdlib; deterministic output.

    python3 tools/generate_audio.py        # writes assets/audio/*.wav

Sound design notes: short, soft, synthesized "toy chime" SFX — the classic
management-game palette. Everything is quiet by default (peak ≈ 0.4) so the
mix never fights the player's attention; ZooAudio applies master volume.
"""
import math
import os
import random
import struct
import wave

SR = 22050
OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "audio")


def write_wav(name, samples):
    os.makedirs(OUT, exist_ok=True)
    path = os.path.join(OUT, name)
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        frames = b"".join(
            struct.pack("<h", max(-32767, min(32767, int(s * 32767))))
            for s in samples)
        w.writeframes(frames)
    print(f"wrote {path} ({len(samples) / SR:.2f}s)")


def silence(dur):
    return [0.0] * int(SR * dur)


def tone(freq, dur, amp=0.4, decay=8.0, harmonic=0.0):
    """A decaying sine 'chime' partial; optional 2nd harmonic for sparkle."""
    n = int(SR * dur)
    out = []
    for i in range(n):
        t = i / SR
        env = math.exp(-decay * t)
        s = math.sin(2 * math.pi * freq * t)
        if harmonic:
            s += harmonic * math.sin(2 * math.pi * freq * 2 * t)
        out.append(amp * env * s)
    return out


def mix(*tracks):
    n = max(len(t) for t in tracks)
    out = [0.0] * n
    for t in tracks:
        for i, s in enumerate(t):
            out[i] += s
    peak = max(1e-6, max(abs(s) for s in out))
    if peak > 0.85:                      # soft headroom guard
        out = [s * 0.85 / peak for s in out]
    return out


def seq(*parts):
    out = []
    for p in parts:
        out.extend(p)
    return out


def delayed(track, dur):
    return silence(dur) + track


# --- SFX --------------------------------------------------------------------

# Coin ding — a guest paid (tickets, food, drink, donations).
write_wav("purchase.wav", mix(
    tone(1318.5, 0.16, amp=0.30, decay=18),
    tone(1760.0, 0.12, amp=0.15, decay=24)))

# Soft construction thump — an entity was placed.
write_wav("place.wav", mix(
    tone(196.0, 0.14, amp=0.40, decay=22),
    tone(294.0, 0.10, amp=0.18, decay=30)))

# Happy departure — two quick ascending notes.
write_wav("verdict_happy.wav", mix(
    tone(659.3, 0.20, amp=0.22, decay=14),
    delayed(tone(880.0, 0.18, amp=0.24, decay=12), 0.07)))

# Unhappy departure — a low minor drop.
write_wav("verdict_unhappy.wav", mix(
    tone(392.0, 0.18, amp=0.22, decay=12),
    delayed(tone(311.1, 0.22, amp=0.24, decay=10), 0.09)))

# Day rollover — a gentle three-note arpeggio (C5 E5 G5).
write_wav("day_chime.wav", mix(
    tone(523.3, 0.5, amp=0.20, decay=6, harmonic=0.2),
    delayed(tone(659.3, 0.45, amp=0.20, decay=6, harmonic=0.2), 0.12),
    delayed(tone(784.0, 0.5, amp=0.22, decay=5, harmonic=0.2), 0.24)))

# Welfare alert — two-tone "attention" (soft, not a klaxon).
write_wav("alert.wav", seq(
    tone(554.4, 0.14, amp=0.26, decay=10),
    tone(415.3, 0.22, amp=0.26, decay=9)))

# A birth — a quick cheerful trill.
write_wav("birth.wav", mix(
    tone(784.0, 0.12, amp=0.20, decay=14),
    delayed(tone(987.8, 0.12, amp=0.20, decay=14), 0.06),
    delayed(tone(1174.7, 0.20, amp=0.22, decay=10), 0.12)))

# Win sting — rising major fanfare (C E G C).
write_wav("win.wav", mix(
    tone(523.3, 1.0, amp=0.20, decay=4, harmonic=0.25),
    delayed(tone(659.3, 0.9, amp=0.20, decay=4, harmonic=0.25), 0.15),
    delayed(tone(784.0, 0.8, amp=0.20, decay=4, harmonic=0.25), 0.30),
    delayed(tone(1046.5, 0.9, amp=0.24, decay=3.2, harmonic=0.25), 0.45)))

# Lose sting — a slow descending minor line.
write_wav("lose.wav", mix(
    tone(440.0, 0.9, amp=0.22, decay=4),
    delayed(tone(392.0, 0.9, amp=0.22, decay=4), 0.30),
    delayed(tone(311.1, 1.1, amp=0.24, decay=3), 0.60)))


# --- Ambient loops (day / night / rain) -------------------------------------
# Roadmap 6.7 audio depth: one ambient bed read as a prototype; a launch wants
# a soundscape that responds to the world. We synthesize three seamless loops
# (ZooAudio crossfades between them by time-of-day + weather): a day park bed
# with birdsong, a night bed with crickets + the odd owl, and a rain bed with
# heavier filtered noise. All deterministic, all stdlib.

DUR = 8.0
N = int(SR * DUR)


def loop_seamless(samples, xf_sec=0.5):
    """Crossfade the tail into the head so the loop has no seam."""
    xf = int(xf_sec * SR)
    out = list(samples)
    for i in range(xf):
        a = i / xf
        out[i] = out[i] * a + out[N - xf + i] * (1 - a)
    return out[: N - xf]


def wind_bed(amp, lp_coef, breathe_rate):
    """White noise through a one-pole lowpass, slowly breathing in volume."""
    out = []
    lp = 0.0
    for i in range(N):
        t = i / SR
        lp += lp_coef * (random.uniform(-1, 1) - lp)
        breathe = 0.75 + 0.25 * math.sin(2 * math.pi * t / DUR * breathe_rate + 1.3)
        out.append(amp * lp * 10 * breathe)
    return out


# Day: gentle wind + scattered FM birdsong chirps.
random.seed(20260612)
wind = wind_bed(0.16, 0.02, 2)
birds = [0.0] * N
for start, base in [(0.9, 2800), (2.1, 3400), (3.8, 2500), (5.2, 3100), (6.6, 2700)]:
    n0 = int(start * SR)
    chirp_len = int(0.16 * SR)
    for k in range(chirp_len):
        t = k / SR
        sweep = base + 600 * math.sin(2 * math.pi * 18 * t)
        env = math.sin(math.pi * k / chirp_len) ** 2
        if n0 + k < N:
            birds[n0 + k] += 0.10 * env * math.sin(2 * math.pi * sweep * t)
write_wav("ambient_park.wav", loop_seamless([w + b for w, b in zip(wind, birds)]))

# Night: softer, darker wind + steady cricket pulses + a distant owl.
random.seed(20260613)
nwind = wind_bed(0.10, 0.012, 1)
crickets = [0.0] * N
cricket_period = 0.32
k_len = int(0.05 * SR)
tpos = 0.2
while tpos < DUR:
    n0 = int(tpos * SR)
    for k in range(k_len):
        t = k / SR
        env = math.sin(math.pi * k / k_len) ** 2
        if n0 + k < N:
            crickets[n0 + k] += 0.05 * env * math.sin(2 * math.pi * 4500 * t)
    tpos += cricket_period
owl = [0.0] * N
for start, base in [(1.6, 360), (5.0, 330)]:
    n0 = int(start * SR)
    hoot_len = int(0.5 * SR)
    for k in range(hoot_len):
        t = k / SR
        env = math.sin(math.pi * k / hoot_len) ** 2
        if n0 + k < N:
            owl[n0 + k] += 0.07 * env * math.sin(2 * math.pi * base * t)
write_wav("ambient_night.wav",
          loop_seamless([w + c + o for w, c, o in zip(nwind, crickets, owl)]))

# Rain: heavier high-passed noise (patter) over a low rumble bed.
random.seed(20260614)
rain = []
hp_prev = 0.0
lp = 0.0
for i in range(N):
    t = i / SR
    nz = random.uniform(-1, 1)
    lp += 0.05 * (nz - lp)
    hp = nz - lp                      # high-passed = the patter
    rumble = 0.0
    rl = lp * 10
    swell = 0.8 + 0.2 * math.sin(2 * math.pi * t / DUR)
    rain.append((0.13 * hp + 0.05 * rl) * swell)
    hp_prev = hp
write_wav("ambient_rain.wav", loop_seamless(rain))


# --- Music bed --------------------------------------------------------------
# A small, calm music set (6.7): one slow pad loop on a I–vi–IV–V progression
# in C, very quiet so it sits under the ambience. Seamless over its own length.

def pad(freqs, dur, amp=0.12):
    n = int(SR * dur)
    out = [0.0] * n
    for k in range(n):
        t = k / SR
        # Gentle attack/release so chords don't click.
        env = min(1.0, t / 0.4) * min(1.0, (dur - t) / 0.4)
        s = 0.0
        for f in freqs:
            s += math.sin(2 * math.pi * f * t)
        out[k] = amp * env * s / max(1, len(freqs))
    return out


CHORD_DUR = 3.0
C_major = [261.6, 329.6, 392.0]
A_minor = [220.0, 261.6, 329.6]
F_major = [174.6, 220.0, 261.6]
G_major = [196.0, 246.9, 293.7]
music = seq(
    pad(C_major, CHORD_DUR), pad(A_minor, CHORD_DUR),
    pad(F_major, CHORD_DUR), pad(G_major, CHORD_DUR))
write_wav("music_calm.wav", music)
