import 'workout_sample.dart';

/// Aggregate metrics for one completed workout: averages, maxes, distance,
/// and timing. Computed via [WorkoutSummary.fromSamples].
class WorkoutSummary {
  final DateTime startedAt;
  final Duration activeDuration;
  final int avgPowerW;
  final int maxPowerW;
  final int avgCadenceRpm;
  final double avgSpeedKph;
  final double distanceKm;
  final int avgHeartRateBpm;
  final int maxHeartRateBpm;
  final int sampleCount;

  const WorkoutSummary({
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
  });

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
  );

  factory WorkoutSummary.fromSamples(
    List<WorkoutSample> samples, {
    required DateTime startedAt,
    required Duration activeDuration,
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

    double sumD(double? Function(WorkoutSample) pick) {
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

    final avgSpeed = sumD((s) => s.speedKph);
    final distanceKm = avgSpeed * (activeDuration.inSeconds / 3600.0);

    return WorkoutSummary(
      startedAt: startedAt,
      activeDuration: activeDuration,
      avgPowerW: aggregate((s) => s.powerW),
      maxPowerW: aggregate((s) => s.powerW, max: true),
      avgCadenceRpm: aggregate((s) => s.cadenceRpm),
      avgSpeedKph: avgSpeed,
      distanceKm: distanceKm,
      avgHeartRateBpm: aggregate((s) => s.heartRateBpm),
      maxHeartRateBpm: aggregate((s) => s.heartRateBpm, max: true),
      sampleCount: samples.length,
    );
  }
}
