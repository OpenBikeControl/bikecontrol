# Shift-feedback cues

Three clips, all **mono, 16-bit PCM, 44.1 kHz WAV** (WAV so the Windows
backend can hand them straight to winmm's `PlaySound`):

  - `shift_up.wav` — harder gear: a bright, snappy click, ≤ 0.30 s.
  - `shift_down.wav` — easier gear: the same click, full length, ≤ 0.50 s —
    heavier and longer than `shift_up.wav`.
  - `shift_limit.wav` — no next gear: a dry double tick, ≤ 0.15 s, no body.

Peak level is normalised to **≈ −14 dBFS**. These play over a phone speaker
while the rider is pedalling next to a fan, so they must be audible but never
startling. Up and down must stay distinguishable without concentrating; they
differ in both length and pitch.

## Provenance (2026-09 redesign)

The previous cues were synthesized DC-motor whines (see git history for the
old `generate.py`); they read as "pretty bad". They were replaced with cues
derived from the click used in the September 2026 promotional video: a deep,
layered click — a body generated with ElevenLabs Sound Effects v2 (via
fal.ai) layered with a synthetic 15 ms mid transient. The source clip
(`click-layered.wav`, 0.48 s stereo, peak ≈ −3 dBFS) is **not** committed to
this repo — it lives in the marketing project's asset store alongside the ad
that uses it. If you need to regenerate these cues, pull it from there.

## Regenerating from `click-layered.wav` (+ the standalone `click-mid.wav`
mid transient) with ffmpeg

```sh
# shift_up.wav — pitch up ~4 semitones, trim to 0.28s, 20ms fade-out, downmix, normalise
ffmpeg -i click-layered.wav -af \
  "asetrate=44100*1.259921,aresample=44100,atrim=0:0.28,afade=t=out:st=0.26:d=0.02,pan=mono|c0=0.5*c0+0.5*c1" \
  -ar 44100 -c:a pcm_s16le up_raw.wav
ffmpeg -i up_raw.wav -af volumedetect -f null -   # read max_volume, e.g. -3.4 dB
ffmpeg -i up_raw.wav -af "volume=<-14dB - max_volume>dB" -ar 44100 -c:a pcm_s16le shift_up.wav

# shift_down.wav — original pitch, full length, downmix, normalise
ffmpeg -i click-layered.wav -af "pan=mono|c0=0.5*c0+0.5*c1" -ar 44100 -c:a pcm_s16le down_raw.wav
ffmpeg -i down_raw.wav -af volumedetect -f null -
ffmpeg -i down_raw.wav -af "volume=<-14dB - max_volume>dB" -ar 44100 -c:a pcm_s16le shift_down.wav

# shift_limit.wav — two mid transients only, at 0ms and 90ms, downmix, normalise
ffmpeg -i click-mid.wav -i click-mid.wav -filter_complex \
  "[1:a]adelay=90|90[delayed];[0:a][delayed]amix=inputs=2:duration=longest:normalize=0[mixed];[mixed]pan=mono|c0=0.5*c0+0.5*c1[out]" \
  -map "[out]" -ar 44100 -c:a pcm_s16le limit_raw.wav
ffmpeg -i limit_raw.wav -af volumedetect -f null -
ffmpeg -i limit_raw.wav -af "volume=<-14dB - max_volume>dB" -ar 44100 -c:a pcm_s16le shift_limit.wav
```

The `volume=<...>dB` step is a manual gain-matching pass: read `max_volume`
from the `volumedetect` output, compute `-14 - max_volume`, and pass that as
the gain so the final peak lands at −14 dBFS.

Verified by `test/assets/shift_sound_assets_test.dart` (format + duration
bounds + up/down distinguishability).
