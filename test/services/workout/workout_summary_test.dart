import 'package:bike_control/services/workout/workout_sample.dart';
import 'package:bike_control/services/workout/workout_summary.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final start = DateTime(2026, 4, 24, 10, 0, 0);

  WorkoutSample s(int sec, {int? p, int? c, double? sp, int? hr}) =>
      WorkoutSample(
        timestamp: start.add(Duration(seconds: sec)),
        powerW: p,
        cadenceRpm: c,
        speedKph: sp,
        heartRateBpm: hr,
      );

  test('empty samples produce zeroed summary', () {
    final sum = WorkoutSummary.fromSamples([], startedAt: start, activeDuration: Duration.zero);
    expect(sum.avgPowerW, 0);
    expect(sum.maxPowerW, 0);
    expect(sum.avgCadenceRpm, 0);
    expect(sum.avgSpeedKph, 0);
    expect(sum.distanceKm, 0);
    expect(sum.avgHeartRateBpm, 0);
    expect(sum.maxHeartRateBpm, 0);
    expect(sum.sampleCount, 0);
  });

  test('averages ignore null entries', () {
    final samples = [
      s(0, p: 100, c: 80, sp: 20, hr: null),
      s(1, p: 200, c: null, sp: 22, hr: 140),
      s(2, p: 300, c: 90, sp: 24, hr: 150),
    ];
    final sum = WorkoutSummary.fromSamples(
      samples,
      startedAt: start,
      activeDuration: const Duration(seconds: 3),
    );
    expect(sum.avgPowerW, 200); // (100+200+300)/3
    expect(sum.maxPowerW, 300);
    expect(sum.avgCadenceRpm, 85); // (80+90)/2 rounded
    expect(sum.avgSpeedKph, closeTo(22.0, 0.001));
    expect(sum.avgHeartRateBpm, 145);
    expect(sum.maxHeartRateBpm, 150);
    expect(sum.sampleCount, 3);
  });

  test('distance is avg speed * active duration', () {
    final samples = [
      s(0, sp: 30),
      s(1, sp: 30),
      s(2, sp: 30),
    ];
    final sum = WorkoutSummary.fromSamples(
      samples,
      startedAt: start,
      activeDuration: const Duration(minutes: 1),
    );
    // 30 km/h for 1 minute = 0.5 km
    expect(sum.distanceKm, closeTo(0.5, 0.001));
  });
}
