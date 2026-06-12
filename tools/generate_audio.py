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


# --- Ambient park loop -------------------------------------------------------
# 8 seconds of gentle wind (lowpassed noise) + sparse birdsong chirps, made
# seamless by crossfading the tail into the head. Deterministic seed.

random.seed(20260612)
DUR = 8.0
N = int(SR * DUR)

# Wind: white noise through a one-pole lowpass, slowly breathing in volume.
wind = []
lp = 0.0
for i in range(N):
    t = i / SR
    lp += 0.02 * (random.uniform(-1, 1) - lp)
    breathe = 0.75 + 0.25 * math.sin(2 * math.pi * t / DUR * 2 + 1.3)
    wind.append(0.16 * lp * 10 * breathe)

# Birds: a handful of short FM chirps scattered through the loop.
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

amb = [w + b for w, b in zip(wind, birds)]
# Seamless loop: crossfade the last 0.5s into the first 0.5s.
xf = int(0.5 * SR)
for i in range(xf):
    a = i / xf
    amb[i] = amb[i] * a + amb[N - xf + i] * (1 - a)
amb = amb[: N - xf]
write_wav("ambient_park.wav", amb)
