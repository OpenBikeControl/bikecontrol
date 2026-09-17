import 'dart:math';

import '../workout/workout_recorder.dart';
import '../workout/workout_sample.dart';
import 'auto_ride_controller.dart';

/// A random (v4) UUID — the ride's HealthKit sync identifier, so a retried
/// save replaces rather than duplicates the workout.
String newRideSyncId() {
  final random = Random.secure();
  final bytes = List<int>.generate(16, (_) => random.nextInt(256));
  bytes[6] = (bytes[6] & 0x0f) | 0x40;
  bytes[8] = (bytes[8] & 0x3f) | 0x80;
  final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-'
      '${hex.substring(16, 20)}-${hex.substring(20)}';
}

/// Timestamps (ms since epoch) and values of one instantaneous series.
class HealthInstantSeries {
  final List<int> times = [];
  final List<num> values = [];

  void add(DateTime at, num value) {
    times.add(at.millisecondsSinceEpoch);
    values.add(value);
  }

  Map<String, Object?> toMap() => {'t': times, 'v': values};
}

/// Cumulative amounts per interval (distance, energy).
class HealthIntervalSeries {
  final List<int> starts = [];
  final List<int> ends = [];
  final List<double> values = [];

  Map<String, Object?> toMap() => {'s': starts, 'e': ends, 'v': values};
}

/// Everything `HealthKitWorkoutWriter.swift` needs to write one ride, built
/// from the recorder's 1 Hz samples and sent over the channel in one call.
class HealthWorkoutPayload {
  HealthWorkoutPayload._({required this.syncId, required this.start, required this.end, required this.pauses});

  static const syncVersion = 1;

  /// Distance and energy are written as one sample per chunk.
  static const chunk = Duration(minutes: 1);

  /// TUNABLE. A sample is credited with the time since the previous one, but
  /// never more than this — missed ticks (the app suspended) must not turn
  /// one reading into minutes of distance.
  static const maxSampleGap = Duration(seconds: 5);

  final String syncId;
  final DateTime start;
  final DateTime end;
  final List<WorkoutPause> pauses;

  final power = HealthInstantSeries();
  final cadence = HealthInstantSeries();
  final speed = HealthInstantSeries();
  final heartRate = HealthInstantSeries();
  final distance = HealthIntervalSeries();
  final energy = HealthIntervalSeries();

  double totalDistanceMeters = 0;
  double totalEnergyKcal = 0;

  /// Null when the ride is too short to be worth a Health workout.
  ///
  /// [minActiveDuration] mirrors whatever [AutoRideController] used to
  /// detect/record the ride — pass the same value through so a ride that
  /// qualified is never dropped here.
  static HealthWorkoutPayload? fromResult(
    WorkoutResult result, {
    required String syncId,
    Duration minActiveDuration = AutoRideController.defaultMinRide,
  }) {
    if (result.activeDuration < minActiveDuration) return null;
    final payload = HealthWorkoutPayload._(
      syncId: syncId,
      start: result.startedAt,
      end: result.endedAt,
      pauses: result.pauses,
    );
    payload._build(result.samples);
    return payload;
  }

  void _build(List<WorkoutSample> samples) {
    final distanceChunks = <int, double>{};
    final energyChunks = <int, double>{};
    var previous = start;

    for (final s in samples) {
      final t = s.timestamp;
      if (t.isAfter(end) || _isPaused(t)) continue;

      final raw = t.difference(previous) - _pausedBetween(previous, t);
      final dt = raw > maxSampleGap ? maxSampleGap : (raw.isNegative ? Duration.zero : raw);
      final seconds = dt.inMicroseconds / Duration.microsecondsPerSecond;
      previous = t;
      // A sample accounts for the time leading up to it, so one that lands
      // exactly on a chunk boundary belongs to the chunk it closes.
      final bucket = max(0, t.difference(start).inMicroseconds - 1) ~/ chunk.inMicroseconds;

      final watts = s.powerW;
      if (watts != null) {
        power.add(t, watts);
        // kJ of work ≈ kcal burned: the ~4.18 J/cal factor and ~24 % human
        // efficiency cancel out — the usual cycling rule of thumb.
        final kcal = watts * seconds / 1000;
        if (kcal > 0) {
          energyChunks.update(bucket, (v) => v + kcal, ifAbsent: () => kcal);
          totalEnergyKcal += kcal;
        }
      }

      final rpm = s.cadenceRpm;
      if (rpm != null) cadence.add(t, rpm);

      final kph = s.speedKph;
      if (kph != null) {
        final metersPerSecond = kph / 3.6;
        speed.add(t, metersPerSecond);
        final meters = metersPerSecond * seconds;
        if (meters > 0) {
          distanceChunks.update(bucket, (v) => v + meters, ifAbsent: () => meters);
          totalDistanceMeters += meters;
        }
      }

      final bpm = s.heartRateBpm;
      // Heart rate read from Health is already there; writing it back would
      // duplicate it under our name.
      if (bpm != null && bpm > 0 && !s.heartRateFromHealth) heartRate.add(t, bpm);
    }

    _fill(distance, distanceChunks);
    _fill(energy, energyChunks);
  }

  void _fill(HealthIntervalSeries series, Map<int, double> chunks) {
    final buckets = chunks.keys.toList()..sort();
    for (final b in buckets) {
      final chunkStart = start.add(chunk * b);
      var chunkEnd = chunkStart.add(chunk);
      if (chunkEnd.isAfter(end)) chunkEnd = end;
      if (!chunkEnd.isAfter(chunkStart)) continue;
      series.starts.add(chunkStart.millisecondsSinceEpoch);
      series.ends.add(chunkEnd.millisecondsSinceEpoch);
      series.values.add(chunks[b]!);
    }
  }

  bool _isPaused(DateTime t) => pauses.any((p) => t.isAfter(p.start) && !t.isAfter(p.end));

  Duration _pausedBetween(DateTime from, DateTime to) {
    var total = Duration.zero;
    for (final p in pauses) {
      final s = p.start.isAfter(from) ? p.start : from;
      final e = p.end.isBefore(to) ? p.end : to;
      if (e.isAfter(s)) total += e.difference(s);
    }
    return total;
  }

  Map<String, Object?> toMap() => {
    'syncId': syncId,
    'syncVersion': syncVersion,
    'start': start.millisecondsSinceEpoch,
    'end': end.millisecondsSinceEpoch,
    'pauses': [
      for (final p in pauses) [p.start.millisecondsSinceEpoch, p.end.millisecondsSinceEpoch],
    ],
    'power': power.toMap(),
    'cadence': cadence.toMap(),
    'speed': speed.toMap(),
    'heartRate': heartRate.toMap(),
    'distance': distance.toMap(),
    'energy': energy.toMap(),
  };
}
