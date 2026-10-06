#!/usr/bin/env python3
"""Synthesize the game's audio into res://audio/ (stdlib only, so it's reproducible).

    python3 tools/gen_audio.py

Loops use whole-number cycles per buffer so they repeat without clicks;
looping itself is switched on in the matching .wav.import files.
"""
import math
import os
import random
import struct
import wave

RATE = 22050
OUT = os.path.join(os.path.dirname(__file__), "..", "audio")
random.seed(7)


def write(name, samples):
    peak = max(1e-9, max(abs(s) for s in samples))
    with wave.open(os.path.join(OUT, name), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes(b"".join(struct.pack("<h", int(s / peak * 0.9 * 32767)) for s in samples))


def saw(f, t):
    return 2.0 * ((f * t) % 1.0) - 1.0


def square(f, t):
    return 1.0 if (f * t) % 1.0 < 0.5 else -1.0


def note(n):  # MIDI note -> Hz
    return 440.0 * 2 ** ((n - 69) / 12)


def lowpass(samples, k):
    out, y = [], 0.0
    for s in samples:
        y += k * (s - y)
        out.append(y)
    return out


def engine():
    # 1 s loop at 50 Hz (integer cycles); pitch_scale shifts it with speed.
    n = RATE
    s = []
    for i in range(n):
        t = i / RATE
        firing = 0.5 + 0.5 * math.sin(2 * math.pi * 25 * t)  # cylinder throb
        s.append((saw(50, t) * 0.6 + square(100, t) * 0.25 + math.sin(2 * math.pi * 150 * t) * 0.3) * (0.6 + 0.4 * firing))
    return lowpass(s, 0.25)


def nitro():
    # Hissing turbo whoosh with a whistle on top.
    s = [random.uniform(-1, 1) for _ in range(RATE)]
    hp = [a - b for a, b in zip(s, lowpass(s, 0.08))]  # keep the hiss
    return [h * 0.8 + math.sin(2 * math.pi * 1200 * i / RATE) * 0.15 for i, h in enumerate(hp)]


def skid():
    # Tyre squeal: wobbling tone plus gritty noise.
    s = []
    for i in range(RATE):
        t = i / RATE
        f = 820 + 40 * math.sin(2 * math.pi * 6 * t)
        s.append(math.sin(2 * math.pi * f * t) * 0.5 + random.uniform(-1, 1) * 0.35)
    return lowpass(s, 0.5)


def fanfare():
    # Rising arpeggio then a held major chord.
    s = [0.0] * int(RATE * 2.4)
    seq = [(0.0, [72]), (0.15, [76]), (0.3, [79]), (0.45, [84]), (0.7, [72, 76, 79, 84])]
    for start, notes in seq:
        length = 1.6 if len(notes) > 1 else 0.22
        for k in range(int(length * RATE)):
            env = min(1.0, k / 300) * math.exp(-2.2 * k / RATE)
            v = sum(square(note(m), k / RATE) * 0.5 + math.sin(2 * math.pi * note(m) * k / RATE) for m in notes)
            s[int(start * RATE) + k] += v * env / len(notes) ** 0.5
    return lowpass(s, 0.35)


def music():
    # 8 bars of driving rock-ish chiptune at 128 bpm, loops cleanly.
    bpm = 128
    beat = 60 / bpm
    bars = 8
    n = int(bars * 4 * beat * RATE)
    s = [0.0] * n
    roots = [45, 45, 41, 43, 45, 45, 48, 43]  # A A F G A A C G
    for bar, root in enumerate(roots):
        for e in range(8):  # eighth-note bass
            start = int((bar * 4 + e / 2) * beat * RATE)
            f = note(root - 12 + (12 if e % 2 else 0))
            for k in range(int(beat / 2 * RATE * 0.9)):
                s[start + k] += saw(f, k / RATE) * 0.35 * math.exp(-3 * k / RATE)
        for e in range(16):  # sixteenth-note arpeggio lead
            start = int((bar * 4 + e / 4) * beat * RATE)
            m = root + 24 + [0, 7, 12, 7, 3, 7, 12, 15][e % 8] - (0 if root in (45, 48) else 0)
            for k in range(int(beat / 4 * RATE * 0.8)):
                s[start + k] += square(note(m), k / RATE) * 0.12 * math.exp(-8 * k / RATE)
        for b in range(4):  # kick on beats, snare on 2 & 4, hats on eighths
            start = int((bar * 4 + b) * beat * RATE)
            for k in range(int(0.15 * RATE)):
                t = k / RATE
                s[start + k] += math.sin(2 * math.pi * (50 + 120 * math.exp(-30 * t)) * t) * 0.8 * math.exp(-18 * t)
            if b % 2:
                for k in range(int(0.12 * RATE)):
                    s[start + k] += random.uniform(-1, 1) * 0.35 * math.exp(-25 * k / RATE)
            for h in range(2):
                hs = start + int(h * beat / 2 * RATE)
                for k in range(int(0.03 * RATE)):
                    s[hs + k] += random.uniform(-1, 1) * 0.12 * math.exp(-120 * k / RATE)
    return s


if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    for name, fn in [("engine.wav", engine), ("nitro.wav", nitro), ("skid.wav", skid), ("finish.wav", fanfare), ("music.wav", music)]:
        write(name, fn())
        print("wrote audio/" + name)
