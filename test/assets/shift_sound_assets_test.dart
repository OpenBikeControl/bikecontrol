// Verifies the shift-feedback WAV assets meet the format constraints the
// Windows winmm backend and the phone-speaker use case require (see
// lib/services/shift_feedback/sound_players/shift_sound_assets.dart and
// assets/sounds/README.md), plus the specific duration bounds for the
// 2026-09 redesign (cues derived from the video-ad click). Pure Dart: reads
// the RIFF/WAVE header and PCM samples by hand, no audio packages.
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

class _WavFile {
  _WavFile({required this.channels, required this.sampleRate, required this.bitsPerSample, required this.samples});

  final int channels;
  final int sampleRate;
  final int bitsPerSample;

  /// Signed 16-bit PCM samples, interleaved across channels if channels > 1.
  final Int16List samples;

  double get durationSeconds => samples.length / channels / sampleRate;

  int get peakAbsSample => samples.isEmpty ? 0 : samples.map((s) => s.abs()).reduce((a, b) => a > b ? a : b);

  double get peakDbfs => 20 * _log10(peakAbsSample / 32768.0);

  double rmsOverFirst(Duration window) {
    final sampleCount = (window.inMicroseconds * sampleRate / 1e6).round() * channels;
    final slice = samples.take(sampleCount.clamp(0, samples.length));
    if (slice.isEmpty) return 0;
    final sumSquares = slice.fold<double>(0, (sum, s) => sum + s * s);
    return math.sqrt(sumSquares / slice.length);
  }
}

double _log10(num x) => x <= 0 ? double.negativeInfinity : math.log(x.toDouble()) / math.ln10;

/// Parses a canonical RIFF/WAVE file: 'fmt ' chunk for format, 'data' chunk
/// for samples. Skips any other chunks (e.g. LIST/INFO) it finds along the
/// way.
_WavFile _readWav(File file) {
  final bytes = file.readAsBytesSync();
  final data = ByteData.sublistView(bytes);

  String fourCC(int offset) => String.fromCharCodes(bytes.sublist(offset, offset + 4));

  if (fourCC(0) != 'RIFF' || fourCC(8) != 'WAVE') {
    throw FormatException('${file.path} is not a RIFF/WAVE file');
  }

  int? channels;
  int? sampleRate;
  int? bitsPerSample;
  Int16List? samples;

  var offset = 12;
  while (offset + 8 <= bytes.length) {
    final chunkId = fourCC(offset);
    final chunkSize = data.getUint32(offset + 4, Endian.little);
    final chunkStart = offset + 8;

    if (chunkId == 'fmt ') {
      channels = data.getUint16(chunkStart + 2, Endian.little);
      sampleRate = data.getUint32(chunkStart + 4, Endian.little);
      bitsPerSample = data.getUint16(chunkStart + 14, Endian.little);
    } else if (chunkId == 'data') {
      final sampleData = ByteData.sublistView(bytes, chunkStart, chunkStart + chunkSize);
      samples = Int16List(chunkSize ~/ 2);
      for (var i = 0; i < samples.length; i++) {
        samples[i] = sampleData.getInt16(i * 2, Endian.little);
      }
    }

    // Chunks are padded to an even number of bytes.
    offset = chunkStart + chunkSize + (chunkSize.isOdd ? 1 : 0);
  }

  if (channels == null || sampleRate == null || bitsPerSample == null || samples == null) {
    throw FormatException('${file.path} is missing a fmt or data chunk');
  }

  return _WavFile(channels: channels, sampleRate: sampleRate, bitsPerSample: bitsPerSample, samples: samples);
}

void main() {
  final up = _readWav(File('assets/sounds/shift_up.wav'));
  final down = _readWav(File('assets/sounds/shift_down.wav'));
  final limit = _readWav(File('assets/sounds/shift_limit.wav'));

  group('format constraints (winmm + phone speaker)', () {
    for (final MapEntry(key: name, value: wav) in {'shift_up': up, 'shift_down': down, 'shift_limit': limit}.entries) {
      test('$name.wav is mono 16-bit 44.1kHz, <= 0.5s, peak around -14 dBFS', () {
        expect(wav.channels, 1, reason: 'must be mono for winmm');
        expect(wav.sampleRate, 44100);
        expect(wav.bitsPerSample, 16);
        expect(wav.durationSeconds, lessThanOrEqualTo(0.5));
        expect(wav.peakDbfs, inInclusiveRange(-16, -12));
      });
    }
  });

  group('2026-09 ad-click redesign duration bounds', () {
    test('shift_up.wav is short and snappy (<= 0.30s)', () {
      expect(up.durationSeconds, lessThanOrEqualTo(0.30));
    });

    test('shift_down.wav is the full-length, heavier click (0.40-0.50s)', () {
      expect(down.durationSeconds, inInclusiveRange(0.40, 0.50));
    });

    test('shift_limit.wav is a short dry double-tick (<= 0.15s)', () {
      expect(limit.durationSeconds, lessThanOrEqualTo(0.15));
    });
  });

  test('up and down are distinguishable without concentrating', () {
    final durationsDiffer = (up.durationSeconds - down.durationSeconds).abs() >= 0.1;
    final earlyRmsDiffers = (up.rmsOverFirst(const Duration(milliseconds: 20)) - down.rmsOverFirst(const Duration(milliseconds: 20))).abs() > 50;
    expect(
      durationsDiffer || earlyRmsDiffers,
      isTrue,
      reason: 'up and down must differ either in duration (>=0.1s) or in early transient loudness',
    );
  });
}
