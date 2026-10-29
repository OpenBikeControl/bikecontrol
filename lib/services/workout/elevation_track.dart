import 'dart:math' as math;

import 'workout_sample.dart';

/// The course a ride climbed, from the grade the trainer app sent and the
/// distance covered on it: each second's distance along the slope, at that
/// second's grade. Trainer apps send no altitude, so this is the only one.
abstract final class ElevationTrack {
  /// Longest gap between two samples still counted as riding. Samples come
  /// at 1 Hz; a longer gap is a pause, which covers no distance.
  static const _maxGapSeconds = 2.0;

  /// Altitude at each of [samples] in metres, from 0 at the first. Seconds
  /// without a grade stay level. Null when no sample has a grade other than
  /// 0: the ride has no course (a trainer in SIM that no app sent a grade to
  /// still reports 0 %).
  static List<double>? altitudes(List<WorkoutSample> samples) {
    if (!samples.any((s) => (s.gradePct ?? 0) != 0)) return null;
    final out = <double>[];
    var alt = 0.0;
    for (var i = 0; i < samples.length; i++) {
      final s = samples[i];
      if (i > 0) {
        final dt = s.timestamp.difference(samples[i - 1].timestamp).inMilliseconds / 1000;
        final grade = s.gradePct;
        final speed = s.speedKph;
        if (grade != null && speed != null && dt > 0) {
          final g = grade / 100;
          alt += speed / 3.6 * math.min(dt, _maxGapSeconds) * g / math.sqrt(1 + g * g);
        }
      }
      out.add(alt);
    }
    return out;
  }

  /// Metres climbed and descended along [altitudes].
  static ({double ascent, double descent}) climb(List<double?> altitudes) {
    var up = 0.0, down = 0.0;
    double? last;
    for (final a in altitudes) {
      if (a == null) continue;
      if (last != null) {
        if (a > last) {
          up += a - last;
        } else {
          down += last - a;
        }
      }
      last = a;
    }
    return (ascent: up, descent: down);
  }
}
