import 'workout_sample.dart';

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

  factory WorkoutSummary.fromSamples(
    List<WorkoutSample> samples, {
    required DateTime startedAt,
    required Duration activeDuration,
  }) {
    int sum(int? Function(WorkoutSample) pick, {int Function(int, int)? reduce}) {
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
      if (reduce != null) return best;
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
      avgPowerW: sum((s) => s.powerW),
      maxPowerW: sum((s) => s.powerW, reduce: (a, b) => a > b ? a : b),
      avgCadenceRpm: sum((s) => s.cadenceRpm),
      avgSpeedKph: avgSpeed,
      distanceKm: distanceKm,
      avgHeartRateBpm: sum((s) => s.heartRateBpm),
      maxHeartRateBpm: sum((s) => s.heartRateBpm, reduce: (a, b) => a > b ? a : b),
      sampleCount: samples.length,
    );
  }
}
