#!/usr/bin/env python3
"""Regenerates the shift-feedback cues in this folder. Stdlib only.

Three clips, all mono 16-bit 44.1 kHz WAV (WAV so the Windows backend can hand
them straight to winmm's PlaySound):

  shift_up.wav     servo whir gliding UP in pitch, then the chain-drop click
  shift_down.wav   the same whir gliding DOWN, then the click
  shift_limit.wav  paddle click only, twice — the motor never runs because
                   there is no next gear

Modelled on what an electronic derailleur actually sounds like: ~90 ms of a
small geared DC motor (low buzzy fundamental plus a thin gear-mesh whine, very
little energy above 4 kHz) ending in a soft mechanical click. No pure tones —
those read as a phone notification, not as a bike.

Synthetic on purpose: no CC0 recordings of electronic derailleurs exist on the
usual libraries, and shipping a recording of a branded groupset would raise
rights questions for a public app. Tweak the numbers below and re-run.

Level: PEAK sets the normalised peak (-14 dBFS). These play over a phone
speaker while the rider is pedalling next to a fan, so they must be audible
but never startling; a "confirm" cue should sit well under the trainer app's
own audio.
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
    """One-pole low-pass — enough to take the fizz off noise bursts."""
    rc = 1.0 / (2 * math.pi * cutoff_hz)
    alpha = (1.0 / RATE) / (rc + 1.0 / RATE)
    out, y = [], 0.0
    for s in samples:
        y += alpha * (s - y)
        out.append(y)
    return out


def _env(t: float, attack: float, hold: float, release: float) -> float:
    """Linear attack, flat hold, exponential-ish release. 0 outside."""
    if t < 0:
        return 0.0
    if t < attack:
        return t / attack
    if t < attack + hold:
        return 1.0
    r = t - attack - hold
    return math.exp(-r / release) if r < release * 5 else 0.0


def _motor(dur: float, f_start: float, f_end: float, rng: random.Random) -> list[float]:
    """Geared DC motor: buzzy low fundamental (harmonics rolled off) plus a
    faint, noisy gear-mesh whine. Pitch glides f_start → f_end over the whir
    (motors spool up/down) — that glide is what tells up from down."""
    n = int(dur * RATE)
    phase = 0.0
    out = []
    whine = _lowpass([(rng.random() - 0.5) for _ in range(n)], 4500)
    for i in range(n):
        t = i / RATE
        f = f_start + (f_end - f_start) * (t / dur)
        phase += 2 * math.pi * f / RATE
        # first 6 harmonics, 1/n^1.3 — brighter than a sine, duller than a saw
        buzz = sum(math.sin(phase * h) / (h**1.3) for h in range(1, 7))
        # gear mesh: the whine amplitude-modulated at ~14x the fundamental
        mesh = whine[i] * (0.6 + 0.4 * math.sin(phase * 14))
        env = _env(t, attack=0.006, hold=dur - 0.03, release=0.008)
        out.append(env * (0.5 * buzz + 5.0 * mesh))
    return out


def _click(rng: random.Random, strength: float = 1.0, cutoff: float = 2500) -> list[float]:
    """Chain landing on the cog / paddle detent: a 4 ms noise burst with a
    tiny low thump underneath, low-passed so it's a 'tick', not a 'tss'."""
    n = int(0.018 * RATE)
    burst = _lowpass([(rng.random() - 0.5) * math.exp(-t / RATE * 900) for t in range(n)], cutoff)
    out = []
    for i in range(n):
        t = i / RATE
        thump = math.sin(2 * math.pi * 180 * t) * math.exp(-t * 250)
        out.append(strength * (2.2 * burst[i] + 0.35 * thump))
    return out


def _mix(parts: list[tuple[float, list[float]]], total: float) -> list[float]:
    out = [0.0] * int(total * RATE)
    for at, part in parts:
        start = int(at * RATE)
        for i, s in enumerate(part):
            if start + i < len(out):
                out[start + i] += s
    return out


def _shift(f_start: float, f_end: float, seed: int) -> list[float]:
    rng = random.Random(seed)
    whir = 0.085
    return _mix(
        [
            (0.0, _motor(whir, f_start, f_end, rng)),
            # the chain drops onto the cog just as the motor stops
            (whir - 0.004, _click(rng, strength=0.55)),
        ],
        total=0.13,
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
    _write("shift_up.wav", _shift(230, 300, seed=1))
    _write("shift_down.wav", _shift(300, 230, seed=2))
    _write("shift_limit.wav", _limit(seed=3))
