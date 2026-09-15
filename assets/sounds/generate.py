#!/usr/bin/env python3
"""Regenerates the shift-feedback cues in this folder. Stdlib only.

Three clips, all mono 16-bit 44.1 kHz WAV (WAV so the Windows backend can hand
them straight to winmm's PlaySound):

  shift_up.wav     harder gear: motor spools UP (160 → 380 Hz), bright gear
                   whine, ends in one crisp tick — chain dropping onto a
                   smaller cog
  shift_down.wav   easier gear: motor spools DOWN (380 → 160 Hz), darker
                   whine, ends in a heavier double clunk — chain climbing a
                   bigger cog
  shift_limit.wav  paddle click only, twice — the motor never runs because
                   there is no next gear

Modelled on a small geared DC motor: a buzzy commutation fundamental with a
few harmonics, plus a *resonant* gear-mesh whine (band-passed noise, not just
low-passed hiss) with a light 18 Hz amplitude wobble, then a mechanical click
as the chain lands. Up and down differ on three axes at once — glide
direction, whine colour, click character — so they're distinguishable over a
fan without concentrating. No pure tones: those read as a phone notification.

Synthetic on purpose: no CC0 recordings of electronic derailleurs exist on the
usual libraries, and shipping a recording of a branded groupset would raise
rights questions for a public app. Tweak the numbers below and re-run.

Level: PEAK sets the normalised peak (-14 dBFS). These play over a phone
speaker while the rider is pedalling next to a fan, so they must be audible
but never startling.
"""
import math
import random
import struct
import wave
from pathlib import Path

RATE = 44100
HERE = Path(__file__).parent
PEAK = 0.2  # ≈ -14 dBFS


def _write(name: str, samples: list[float]) -> None:
    peak = max(abs(s) for s in samples) or 1.0
    scale = PEAK / peak
    with wave.open(str(HERE / name), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes(b"".join(struct.pack("<h", int(max(-1.0, min(1.0, s * scale)) * 32767)) for s in samples))
    rms = math.sqrt(sum((s * scale) ** 2 for s in samples) / len(samples))
    print(f"{name}: {len(samples) / RATE * 1000:.0f} ms, peak {20 * math.log10(PEAK):.1f} dBFS, rms {20 * math.log10(rms):.1f} dBFS")


def _lowpass(samples: list[float], cutoff_hz: float) -> list[float]:
    """One-pole low-pass — takes the fizz off noise bursts."""
    rc = 1.0 / (2 * math.pi * cutoff_hz)
    alpha = (1.0 / RATE) / (rc + 1.0 / RATE)
    out, y = [], 0.0
    for s in samples:
        y += alpha * (s - y)
        out.append(y)
    return out


def _bandpass(samples: list[float], f0: float, q: float) -> list[float]:
    """RBJ biquad band-pass: a resonant peak, which is what a gearbox whine
    is — energy concentrated around the mesh frequency, not broadband."""
    w0 = 2 * math.pi * f0 / RATE
    alpha = math.sin(w0) / (2 * q)
    b0, b1, b2 = alpha, 0.0, -alpha
    a0, a1, a2 = 1 + alpha, -2 * math.cos(w0), 1 - alpha
    b0, b1, b2, a1, a2 = b0 / a0, b1 / a0, b2 / a0, a1 / a0, a2 / a0
    out, x1, x2, y1, y2 = [], 0.0, 0.0, 0.0, 0.0
    for x in samples:
        y = b0 * x + b1 * x1 + b2 * x2 - a1 * y1 - a2 * y2
        out.append(y)
        x2, x1, y2, y1 = x1, x, y1, y
    return out


def _env(t: float, attack: float, hold: float, release: float) -> float:
    """Linear attack, flat hold, exponential release. 0 outside."""
    if t < 0:
        return 0.0
    if t < attack:
        return t / attack
    if t < attack + hold:
        return 1.0
    r = t - attack - hold
    return math.exp(-r / release) if r < release * 5 else 0.0


def _motor(dur: float, f_start: float, f_end: float, whine_hz: float, rng: random.Random) -> list[float]:
    """Geared DC motor. The commutation fundamental glides exponentially
    f_start → f_end (motors spool, they don't step); the whine is band-passed
    noise around [whine_hz], amplitude-modulated by the gear mesh and by a
    slow wobble so it doesn't sit perfectly still."""
    n = int(dur * RATE)
    phase = 0.0
    out = []
    whine = _bandpass([(rng.random() - 0.5) for _ in range(n)], whine_hz, q=5.0)
    ratio = f_end / f_start
    for i in range(n):
        t = i / RATE
        f = f_start * ratio ** (t / dur)
        phase += 2 * math.pi * f / RATE
        # commutation buzz: first 5 harmonics, 1/n^1.2
        buzz = sum(math.sin(phase * h) / (h**1.2) for h in range(1, 6))
        mesh = whine[i] * (0.55 + 0.45 * math.sin(phase * 11)) * (0.85 + 0.15 * math.sin(2 * math.pi * 18 * t))
        env = _env(t, attack=0.008, hold=dur - 0.03, release=0.010)
        out.append(env * (0.45 * buzz + 9.0 * mesh))
    return out


def _click(
    rng: random.Random,
    strength: float = 1.0,
    cutoff: float = 2500,
    thump_hz: float = 180,
    thump: float = 0.35,
) -> list[float]:
    """Chain landing on a cog / paddle detent: a short noise burst with a low
    thump underneath. Higher cutoff = 'tick', lower + more thump = 'clunk'."""
    n = int(0.020 * RATE)
    burst = _lowpass([(rng.random() - 0.5) * math.exp(-t / RATE * 900) for t in range(n)], cutoff)
    out = []
    for i in range(n):
        t = i / RATE
        th = math.sin(2 * math.pi * thump_hz * t) * math.exp(-t * 220)
        out.append(strength * (2.2 * burst[i] + thump * th))
    return out


def _mix(parts: list[tuple[float, list[float]]], total: float) -> list[float]:
    out = [0.0] * int(total * RATE)
    for at, part in parts:
        start = int(at * RATE)
        for i, s in enumerate(part):
            if start + i < len(out):
                out[start + i] += s
    return out


WHIR = 0.11  # motor run time


def _up(seed: int) -> list[float]:
    rng = random.Random(seed)
    return _mix(
        [
            (0.0, _motor(WHIR, 160, 380, whine_hz=2600, rng=rng)),
            # one crisp tick as the chain drops onto the smaller cog
            (WHIR - 0.005, _click(rng, strength=0.6, cutoff=5000, thump=0.15)),
        ],
        total=0.16,
    )


def _down(seed: int) -> list[float]:
    rng = random.Random(seed)
    return _mix(
        [
            (0.0, _motor(WHIR, 380, 160, whine_hz=1500, rng=rng)),
            # heavier double clunk: the chain climbing onto the bigger cog
            (WHIR - 0.008, _click(rng, strength=0.75, cutoff=1300, thump_hz=120, thump=0.9)),
            (WHIR + 0.022, _click(rng, strength=0.5, cutoff=1100, thump_hz=110, thump=0.7)),
        ],
        total=0.18,
    )


def _limit(seed: int) -> list[float]:
    """Paddle clicks with no motor behind them — the shifter works, the
    derailleur has nowhere to go."""
    rng = random.Random(seed)
    return _mix(
        [
            (0.0, _click(rng, strength=0.5, cutoff=1800)),
            (0.075, _click(rng, strength=0.5, cutoff=1800)),
        ],
        total=0.12,
    )


if __name__ == "__main__":
    _write("shift_up.wav", _up(seed=1))
    _write("shift_down.wav", _down(seed=2))
    _write("shift_limit.wav", _limit(seed=3))
