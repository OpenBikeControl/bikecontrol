import 'package:bike_control/services/workout/workout_recorder.dart' show WorkoutPause;
import 'package:bike_control/services/workout/workout_sample.dart';
import 'package:bike_control/services/workout/workout_summary.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final start = DateTime(2026, 4, 24, 10, 0, 0);

  WorkoutSample s(int sec, {int? p, int? c, double? sp, int? hr, int? g}) => WorkoutSample(
    timestamp: start.add(Duration(seconds: sec)),
    powerW: p,
    cadenceRpm: c,
    speedKph: sp,
    heartRateBpm: hr,
    gear: g,
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

  group('ride statistics', () {
    test('work, energy, max cadence and total vs moving time', () {
      final samples = [
        s(0, p: 100, c: 80, hr: 120),
        s(1, p: 200, c: 95, hr: 130),
        s(2, p: 300, c: 110, hr: 150),
      ];
      final sum = WorkoutSummary.fromSamples(
        samples,
        startedAt: start,
        activeDuration: const Duration(minutes: 10),
        endedAt: start.add(const Duration(minutes: 12)),
        gearChanges: 7,
      );
      // Ø 200 W over 600 s of pedalling = 120 kJ; kcal ≈ kJ.
      expect(sum.workKj, closeTo(120, 0.001));
      expect(sum.energyKcal, closeTo(120, 0.001));
      expect(sum.maxCadenceRpm, 110);
      expect(sum.elapsedDuration, const Duration(minutes: 12));
      expect(sum.activeDuration, const Duration(minutes: 10));
      expect(sum.gearChanges, 7);
    });

    test('no speed source: distance is unknown, never invented', () {
      final sum = WorkoutSummary.fromSamples(
        [s(0, p: 200, c: 90), s(1, p: 210, c: 91)],
        startedAt: start,
        activeDuration: const Duration(minutes: 5),
      );
      expect(sum.hasSpeed, isFalse);
      expect(sum.shownDistanceKm, isNull);
    });

    test('a speed source gives a distance', () {
      final sum = WorkoutSummary.fromSamples(
        [s(0, sp: 30), s(1, sp: 30)],
        startedAt: start,
        activeDuration: const Duration(minutes: 2),
      );
      expect(sum.hasSpeed, isTrue);
      expect(sum.shownDistanceKm, closeTo(1.0, 0.001));
    });

    test('chart buckets power and heart rate over the whole ride, pauses empty', () {
      final samples = [
        for (var i = 0; i < 20; i++) s(i, p: 200, hr: 140),
        for (var i = 30; i < 40; i++) s(i, p: 100, hr: 120),
      ];
      final sum = WorkoutSummary.fromSamples(
        samples,
        startedAt: start,
        activeDuration: const Duration(seconds: 30),
        endedAt: start.add(const Duration(seconds: 40)),
        pauses: [
          WorkoutPause(start: start.add(const Duration(seconds: 20)), end: start.add(const Duration(seconds: 30))),
        ],
      );
      final chart = sum.chart!;
      expect(chart.stepSeconds, 5);
      expect(chart.power, [200, 200, 200, 200, null, null, 100, 100]);
      expect(chart.heartRate, [140, 140, 140, 140, null, null, 120, 120]);
      expect(chart.pauses, [(20, 30)]);
    });

    test('chart buckets cadence and keeps the gear held longest in each bucket', () {
      final samples = [
        for (var i = 0; i < 5; i++) s(i, p: 200, c: 90, g: i < 2 ? 10 : 11),
        for (var i = 5; i < 10; i++) s(i, p: 200, c: 80, g: 12),
      ];
      final chart = WorkoutSummary.fromSamples(
        samples,
        startedAt: start,
        activeDuration: const Duration(seconds: 10),
        endedAt: start.add(const Duration(seconds: 10)),
      ).chart!;
      expect(chart.cadence, [90, 80]);
      expect(chart.gear, [11, 12]);
      expect(chart.hasCadence, isTrue);
      expect(chart.hasGear, isTrue);
    });

    test('a ride without gears or cadence has neither series', () {
      final chart = WorkoutSummary.fromSamples(
        [for (var i = 0; i < 10; i++) s(i, p: 200)],
        startedAt: start,
        activeDuration: const Duration(seconds: 10),
      ).chart!;
      expect(chart.hasCadence, isFalse);
      expect(chart.hasGear, isFalse);
      expect(chart.gearSeconds, isEmpty);
    });

    test('time at each gear, power and heart rate counts every second ridden', () {
      final samples = [
        for (var i = 0; i < 7; i++) s(i, p: 150, hr: 120, g: 10),
        for (var i = 7; i < 10; i++) s(i, p: 302, hr: 121, g: 11),
        s(10, p: null, hr: 0, g: 11),
      ];
      final chart = WorkoutSummary.fromSamples(
        samples,
        startedAt: start,
        activeDuration: const Duration(seconds: 11),
      ).chart!;
      expect(chart.gearSeconds, {10: 7, 11: 4});
      expect(chart.powerSeconds, {150: 7, 302: 3});
      expect(chart.heartRateSeconds, {120: 7, 121: 3});
    });

    test('a chart saved before cadence and gears were kept still loads', () {
      final chart = RideChart.fromJson({
        'step': 5,
        'power': [200, 210],
        'heartRate': [140, 141],
        'pauses': [],
      })!;
      expect(chart.cadence, isEmpty);
      expect(chart.gear, isEmpty);
      expect(chart.hasCadence, isFalse);
      expect(chart.hasGear, isFalse);
      expect(chart.gearSeconds, isEmpty);
      // Zones still have something to go on: the buckets.
      expect(chart.powerSeconds, {200: 5, 210: 5});
      expect(chart.heartRateSeconds, {140: 5, 141: 5});
    });

    test('round-trips everything through json', () {
      final sum = WorkoutSummary.fromSamples(
        [s(0, p: 200, c: 90, sp: 30, hr: 140, g: 9), s(1, p: 220, c: 92, sp: 31, hr: 141, g: 10)],
        startedAt: start,
        activeDuration: const Duration(minutes: 3),
        endedAt: start.add(const Duration(minutes: 4)),
        gearChanges: 3,
        trainerName: 'KICKR CORE',
        appName: 'MyWhoosh',
        autoStarted: true,
      ).copyWith(savedToHealth: true, healthSyncId: 'abc', fitExported: true);
      final back = WorkoutSummary.fromJson(sum.toJson());
      expect(back.toJson(), sum.toJson());
      expect(back.trainerName, 'KICKR CORE');
      expect(back.appName, 'MyWhoosh');
      expect(back.autoStarted, isTrue);
      expect(back.savedToHealth, isTrue);
      expect(back.healthSyncId, 'abc');
      expect(back.fitExported, isTrue);
      expect(back.gearChanges, 3);
      expect(back.chart!.power, sum.chart!.power);
      expect(back.chart!.cadence, sum.chart!.cadence);
      expect(back.chart!.gear, sum.chart!.gear);
      expect(back.chart!.gearSeconds, {9: 1, 10: 1});
      expect(back.chart!.powerSeconds, sum.chart!.powerSeconds);
      expect(back.chart!.heartRateSeconds, sum.chart!.heartRateSeconds);
    });

    test('reads a ride saved before this version', () {
      final old = {
        'startedAt': '2026-04-24T10:00:00.000Z',
        'activeDurationSeconds': 1800,
        'avgPowerW': 200,
        'maxPowerW': 400,
        'avgCadenceRpm': 88,
        'avgSpeedKph': 0.0,
        'distanceKm': 0.0,
        'avgHeartRateBpm': 0,
        'maxHeartRateBpm': 0,
        'sampleCount': 1800,
      };
      final sum = WorkoutSummary.fromJson(old);
      expect(sum.activeDuration, const Duration(minutes: 30));
      expect(sum.elapsedDuration, const Duration(minutes: 30));
      expect(sum.hasSpeed, isFalse);
      expect(sum.shownDistanceKm, isNull);
      expect(sum.workKj, closeTo(360, 0.001));
      expect(sum.gearChanges, isNull);
      expect(sum.chart, isNull);
      expect(sum.savedToHealth, isFalse);
      expect(sum.maxCadenceRpm, 0);
    });
  });
}
