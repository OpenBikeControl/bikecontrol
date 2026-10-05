import 'dart:math' as math;

import 'workout_recorder.dart' show WorkoutPause;
import 'workout_sample.dart';

/// Power and heart rate over a ride, bucketed for the summary card and the
/// details chart. Bucket `i` covers `[i * stepSeconds, (i + 1) * stepSeconds)`
/// from the ride's start; a bucket without samples (a pause, a dropout) is
/// null so the line breaks there.
class RideChart {
  final int stepSeconds;
  final List<int?> power;
  final List<int?> heartRate;

  /// Paused stretches as (start, end) seconds from the ride's start.
  final List<(int, int)> pauses;

  const RideChart({required this.stepSeconds, required this.power, required this.heartRate, required this.pauses});

  /// TUNABLE. More points than a phone-width chart can show is wasted json.
  static const maxPoints = 360;
  static const minStepSeconds = 5;

  int get totalSeconds => math.max(power.length, heartRate.length) * stepSeconds;

  bool get hasPower => power.any((v) => v != null && v > 0);
  bool get hasHeartRate => heartRate.any((v) => v != null && v > 0);

  static RideChart build(
    List<WorkoutSample> samples, {
    required DateTime startedAt,
    required Duration elapsed,
    List<WorkoutPause> pauses = const [],
  }) {
    final seconds = math.max(1, elapsed.inSeconds);
    final step = math.max(minStepSeconds, (seconds / maxPoints).ceil());
    final count = (seconds / step).ceil();
    final pSum = List<int>.filled(count, 0), pN = List<int>.filled(count, 0);
    final hSum = List<int>.filled(count, 0), hN = List<int>.filled(count, 0);
    for (final s in samples) {
      final at = s.timestamp.difference(startedAt).inSeconds;
      if (at < 0) continue;
      final i = math.min(count - 1, at ~/ step);
      if (s.powerW case final p?) {
        pSum[i] += p;
        pN[i]++;
      }
      if (s.heartRateBpm case final h? when h > 0) {
        hSum[i] += h;
        hN[i]++;
      }
    }
    return RideChart(
      stepSeconds: step,
      power: [for (var i = 0; i < count; i++) pN[i] == 0 ? null : (pSum[i] / pN[i]).round()],
      heartRate: [for (var i = 0; i < count; i++) hN[i] == 0 ? null : (hSum[i] / hN[i]).round()],
      pauses: [
        for (final p in pauses) (p.start.difference(startedAt).inSeconds, p.end.difference(startedAt).inSeconds),
      ],
    );
  }

  Map<String, Object?> toJson() => {
    'step': stepSeconds,
    'power': power,
    'heartRate': heartRate,
    'pauses': [
      for (final p in pauses) [p.$1, p.$2],
    ],
  };

  static RideChart? fromJson(Object? raw) {
    if (raw is! Map) return null;
    List<int?> ints(Object? v) => v is List ? [for (final x in v) (x as num?)?.toInt()] : const [];
    return RideChart(
      stepSeconds: (raw['step'] as num?)?.toInt() ?? minStepSeconds,
      power: ints(raw['power']),
      heartRate: ints(raw['heartRate']),
      pauses: [
        if (raw['pauses'] case final List list)
          for (final p in list)
            if (p is List && p.length == 2) ((p[0] as num).toInt(), (p[1] as num).toInt()),
      ],
    );
  }
}

/// Aggregate metrics for one completed ride: averages, maxes, distance,
/// work and timing, plus where the ride has gone since (Health, a shared
/// .fit). Computed via [WorkoutSummary.fromSamples]; persisted as the
/// `.fit.json` sidecar. Every field added after the first version is
/// optional in the json, so rides saved by older builds still load.
class WorkoutSummary {
  final DateTime startedAt;

  /// Moving time: the ride minus its pauses.
  final Duration activeDuration;

  /// Null for rides saved before the end time was recorded.
  final DateTime? endedAt;
  final int avgPowerW;
  final int maxPowerW;
  final int avgCadenceRpm;
  final int maxCadenceRpm;
  final double avgSpeedKph;
  final double distanceKm;

  /// Whether anything reported speed. Without it there is no distance: a
  /// cadence sensor or a power meter alone cannot tell how far.
  final bool hasSpeed;
  final int avgHeartRateBpm;
  final int maxHeartRateBpm;
  final int sampleCount;

  /// Mechanical work in kJ (Ø power × moving time).
  final double workKj;

  /// Shifts (rear and front) during the ride; null without a gear source.
  final int? gearChanges;
  final String? trainerName;
  final String? appName;

  /// Started by the first pedal stroke rather than by hand.
  final bool autoStarted;
  final RideChart? chart;

  /// Already written to Apple Health / Health Connect.
  final bool savedToHealth;

  /// The Health sync identifier, kept so a retry replaces instead of
  /// duplicating.
  final String? healthSyncId;

  /// The .fit file was shared or saved somewhere.
  final bool fitExported;

  WorkoutSummary({
    required this.startedAt,
    required this.activeDuration,
    required this.avgPowerW,
    required this.maxPowerW,
    required this.avgCadenceRpm,
    required this.avgSpeedKph,
    required this.distanceKm,
    required this.avgHeartRateBpm,
    required this.maxHeartRateBpm,
    required this.sampleCount,
    this.endedAt,
    this.maxCadenceRpm = 0,
    bool? hasSpeed,
    double? workKj,
    this.gearChanges,
    this.trainerName,
    this.appName,
    this.autoStarted = false,
    this.chart,
    this.savedToHealth = false,
    this.healthSyncId,
    this.fitExported = false,
  }) : hasSpeed = hasSpeed ?? avgSpeedKph > 0,
       workKj = workKj ?? avgPowerW * activeDuration.inSeconds / 1000;

  /// Start to end, pauses included.
  Duration get elapsedDuration {
    final end = endedAt;
    if (end == null) return activeDuration;
    final d = end.difference(startedAt);
    return d < activeDuration ? activeDuration : d;
  }

  /// The distance to show, or null when nothing measured speed.
  double? get shownDistanceKm => hasSpeed ? distanceKm : null;

  /// kcal burned ≈ kJ of work: the ~4.18 J/cal factor and ~24 % human
  /// efficiency cancel out (the usual cycling rule of thumb).
  double get energyKcal => workKj;

  WorkoutSummary copyWith({bool? savedToHealth, String? healthSyncId, bool? fitExported}) => WorkoutSummary(
    startedAt: startedAt,
    activeDuration: activeDuration,
    avgPowerW: avgPowerW,
    maxPowerW: maxPowerW,
    avgCadenceRpm: avgCadenceRpm,
    avgSpeedKph: avgSpeedKph,
    distanceKm: distanceKm,
    avgHeartRateBpm: avgHeartRateBpm,
    maxHeartRateBpm: maxHeartRateBpm,
    sampleCount: sampleCount,
    endedAt: endedAt,
    maxCadenceRpm: maxCadenceRpm,
    hasSpeed: hasSpeed,
    workKj: workKj,
    gearChanges: gearChanges,
    trainerName: trainerName,
    appName: appName,
    autoStarted: autoStarted,
    chart: chart,
    savedToHealth: savedToHealth ?? this.savedToHealth,
    healthSyncId: healthSyncId ?? this.healthSyncId,
    fitExported: fitExported ?? this.fitExported,
  );

  Map<String, Object?> toJson() => {
    'startedAt': startedAt.toUtc().toIso8601String(),
    'activeDurationSeconds': activeDuration.inSeconds,
    'avgPowerW': avgPowerW,
    'maxPowerW': maxPowerW,
    'avgCadenceRpm': avgCadenceRpm,
    'avgSpeedKph': avgSpeedKph,
    'distanceKm': distanceKm,
    'avgHeartRateBpm': avgHeartRateBpm,
    'maxHeartRateBpm': maxHeartRateBpm,
    'sampleCount': sampleCount,
    // Added with automatic ride recording; all optional on read.
    'version': 2,
    if (endedAt case final end?) 'endedAt': end.toUtc().toIso8601String(),
    'maxCadenceRpm': maxCadenceRpm,
    'hasSpeed': hasSpeed,
    'workKj': workKj,
    if (gearChanges case final g?) 'gearChanges': g,
    if (trainerName case final t?) 'trainerName': t,
    if (appName case final a?) 'appName': a,
    'autoStarted': autoStarted,
    if (chart case final c?) 'chart': c.toJson(),
    'savedToHealth': savedToHealth,
    if (healthSyncId case final id?) 'healthSyncId': id,
    'fitExported': fitExported,
  };

  factory WorkoutSummary.fromJson(Map<String, Object?> j) => WorkoutSummary(
    startedAt: DateTime.parse(j['startedAt'] as String),
    activeDuration: Duration(seconds: (j['activeDurationSeconds'] as num).toInt()),
    avgPowerW: (j['avgPowerW'] as num).toInt(),
    maxPowerW: (j['maxPowerW'] as num).toInt(),
    avgCadenceRpm: (j['avgCadenceRpm'] as num).toInt(),
    avgSpeedKph: (j['avgSpeedKph'] as num).toDouble(),
    distanceKm: (j['distanceKm'] as num).toDouble(),
    avgHeartRateBpm: (j['avgHeartRateBpm'] as num).toInt(),
    maxHeartRateBpm: (j['maxHeartRateBpm'] as num).toInt(),
    sampleCount: (j['sampleCount'] as num).toInt(),
    endedAt: j['endedAt'] is String ? DateTime.parse(j['endedAt'] as String) : null,
    maxCadenceRpm: (j['maxCadenceRpm'] as num?)?.toInt() ?? 0,
    hasSpeed: j['hasSpeed'] as bool?,
    workKj: (j['workKj'] as num?)?.toDouble(),
    gearChanges: (j['gearChanges'] as num?)?.toInt(),
    trainerName: j['trainerName'] as String?,
    appName: j['appName'] as String?,
    autoStarted: j['autoStarted'] as bool? ?? false,
    chart: RideChart.fromJson(j['chart']),
    savedToHealth: j['savedToHealth'] as bool? ?? false,
    healthSyncId: j['healthSyncId'] as String?,
    fitExported: j['fitExported'] as bool? ?? false,
  );

  factory WorkoutSummary.fromSamples(
    List<WorkoutSample> samples, {
    required DateTime startedAt,
    required Duration activeDuration,
    DateTime? endedAt,
    List<WorkoutPause> pauses = const [],
    int? gearChanges,
    String? trainerName,
    String? appName,
    bool autoStarted = false,
  }) {
    int aggregate(int? Function(WorkoutSample) pick, {bool max = false}) {
      int n = 0;
      int acc = 0;
      int best = 0;
      for (final s in samples) {
        final v = pick(s);
        if (v == null) continue;
        acc += v;
        if (v > best) best = v;
        n++;
      }
      if (max) return best;
      return n == 0 ? 0 : (acc / n).round();
    }

    double mean(num? Function(WorkoutSample) pick) {
      int n = 0;
      double acc = 0;
      for (final s in samples) {
        final v = pick(s);
        if (v == null) continue;
        acc += v;
        n++;
      }
      return n == 0 ? 0 : acc / n;
    }

    final hasSpeed = samples.any((s) => s.speedKph != null);
    final avgSpeed = mean((s) => s.speedKph);
    final distanceKm = avgSpeed * (activeDuration.inSeconds / 3600.0);
    final workKj = mean((s) => s.powerW) * activeDuration.inSeconds / 1000;
    final end = endedAt ?? startedAt.add(activeDuration);

    return WorkoutSummary(
      startedAt: startedAt,
      activeDuration: activeDuration,
      endedAt: endedAt,
      avgPowerW: aggregate((s) => s.powerW),
      maxPowerW: aggregate((s) => s.powerW, max: true),
      avgCadenceRpm: aggregate((s) => s.cadenceRpm),
      maxCadenceRpm: aggregate((s) => s.cadenceRpm, max: true),
      avgSpeedKph: avgSpeed,
      distanceKm: distanceKm,
      hasSpeed: hasSpeed,
      avgHeartRateBpm: aggregate((s) => s.heartRateBpm),
      maxHeartRateBpm: aggregate((s) => s.heartRateBpm, max: true),
      sampleCount: samples.length,
      workKj: workKj,
      gearChanges: gearChanges,
      trainerName: trainerName,
      appName: appName,
      autoStarted: autoStarted,
      chart: RideChart.build(samples, startedAt: startedAt, elapsed: end.difference(startedAt), pauses: pauses),
    );
  }
}
