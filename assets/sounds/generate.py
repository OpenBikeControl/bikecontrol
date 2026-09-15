#!/usr/bin/env python3
"""Regenerates the shift-feedback cues in this folder. Stdlib only.

Three clips, all mono 16-bit 44.1 kHz WAV (WAV so the Windows backend can hand
them straight to winmm's PlaySound):

  shift_up.wav     rising two-tone (1000 -> 1500 Hz) with a click transient
  shift_down.wav   the same, falling (1500 -> 1000 Hz)
  shift_limit.wav  a dull double thud (140 Hz) - "no more gears"

Synthetic on purpose: no CC0 recordings of electronic derailleurs exist on the
usual libraries, and shipping a recording of a branded groupset would raise
rights questions for a public app. Tweak the numbers below and re-run.
"""
import math
import random
import struct
import wave
from pathlib import Path

RATE = 44100
HERE = Path(__file__).parent


def _write(name: str, samples: list[float]) -> None:
    peak = max(abs(s) for s in samples) or 1.0
    scale = 0.9 / peak  # normalise with headroom
    with wave.open(str(HERE / name), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes(b"".join(struct.pack("<h", int(max(-1.0, min(1.0, s * scale)) * 32767)) for s in samples))


def _fade_out(samples: list[float], seconds: float) -> None:
    n = int(seconds * RATE)
    for i in range(n):
        samples[len(samples) - n + i] *= 1.0 - i / n


def _two_tone(f1: float, f2: float, seed: int) -> list[float]:
    rng = random.Random(seed)
    dur, split = 0.14, 0.055
    out = []
    for i in range(int(dur * RATE)):
        t = i / RATE
        if t < split:
            tone = math.sin(2 * math.pi * f1 * t) * math.exp(-35 * t)
        else:
            tone = math.sin(2 * math.pi * f2 * t) * math.exp(-35 * (t - split))
        click = (rng.random() - 0.5) * math.exp(-150 * t)
        out.append(0.55 * tone + 0.35 * click)
    _fade_out(out, 0.04)
    return out


def _double_thud(seed: int) -> list[float]:
    rng = random.Random(seed)
    dur, gap, f = 0.20, 0.09, 140.0
    out = []
    for i in range(int(dur * RATE)):
        t = i / RATE
        tone = math.sin(2 * math.pi * f * t) * math.exp(-30 * t)
        noise = math.exp(-120 * t)
        if t >= gap:
            tone += math.sin(2 * math.pi * f * (t - gap)) * math.exp(-30 * (t - gap))
            noise += math.exp(-120 * (t - gap))
        out.append(0.8 * tone + 0.3 * (rng.random() - 0.5) * noise)
    _fade_out(out, 0.04)
    return out


if __name__ == "__main__":
    _write("shift_up.wav", _two_tone(1000, 1500, seed=1))
    _write("shift_down.wav", _two_tone(1500, 1000, seed=2))
    _write("shift_limit.wav", _double_thud(seed=3))
    print("wrote shift_up.wav shift_down.wav shift_limit.wav")
