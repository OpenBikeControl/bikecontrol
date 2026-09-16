import 'package:bike_control/services/health/health_workout_payload.dart';
import 'package:bike_control/services/workout/workout_recorder.dart';
import 'package:bike_control/services/workout/workout_sample.dart';
import 'package:bike_control/services/workout/workout_summary.dart';
import 'package:flutter_test/flutter_test.dart';

final _start = DateTime.utc(2026, 9, 16, 18);

DateTime _t(int seconds) => _start.add(Duration(seconds: seconds));

/// A ride of [seconds] 1 Hz samples, the first one a second after the start.
WorkoutResult _ride({
  required int seconds,
  int? power = 200,
  int? cadence = 90,
  double? speedKph = 36,
  int? hr = 140,
  bool hrFromHealth = false,
  List<WorkoutPause> pauses = const [],
  Duration? active,
}) {
  final samples = [
    for (var i = 1; i <= seconds; i++)
      WorkoutSample(
        timestamp: _t(i),
        powerW: power,
        cadenceRpm: cadence,
        speedKph: speedKph,
        heartRateBpm: hr,
        heartRateFromHealth: hrFromHealth,
      ),
  ];
  final activeDuration = active ?? Duration(seconds: seconds);
  return WorkoutResult(
    samples: samples,
    startedAt: _start,
    endedAt: _t(seconds),
    activeDuration: activeDuration,
    pauses: pauses,
    summary: WorkoutSummary.fromSamples(samples, startedAt: _start, activeDuration: activeDuration),
  );
}

void main() {
  test('skipped below 5 min of active time', () {
    expect(HealthWorkoutPayload.fromResult(_ride(seconds: 299), syncId: 'x'), isNull);
    expect(HealthWorkoutPayload.fromResult(_ride(seconds: 300), syncId: 'x'), isNotNull);
  });

  test('a long ride with a long pause still needs 5 min of ACTIVE time', () {
    final ride = _ride(
      seconds: 600,
      active: const Duration(seconds: 240),
      pauses: [WorkoutPause(start: _t(240), end: _t(600))],
    );
    expect(HealthWorkoutPayload.fromResult(ride, syncId: 'x'), isNull);
  });

  test('carries the sync id, window and pauses', () {
    final ride = _ride(
      seconds: 600,
      active: const Duration(seconds: 540),
      pauses: [WorkoutPause(start: _t(100), end: _t(160))],
    );
    final payload = HealthWorkoutPayload.fromResult(ride, syncId: 'ride-1')!;
    final map = payload.toMap();
    expect(map['syncId'], 'ride-1');
    expect(map['syncVersion'], 1);
    expect(map['start'], _start.millisecondsSinceEpoch);
    expect(map['end'], _t(600).millisecondsSinceEpoch);
    expect(map['pauses'], [
      [_t(100).millisecondsSinceEpoch, _t(160).millisecondsSinceEpoch],
    ]);
  });

  test('instant series: power, cadence, speed in m/s, heart rate', () {
    final payload = HealthWorkoutPayload.fromResult(_ride(seconds: 300), syncId: 'x')!;
    final map = payload.toMap();
    final power = map['power'] as Map;
    expect((power['t'] as List).length, 300);
    expect((power['t'] as List).first, _t(1).millisecondsSinceEpoch);
    expect((power['v'] as List).toSet(), {200});
    expect(((map['cadence'] as Map)['v'] as List).toSet(), {90});
    expect(((map['speed'] as Map)['v'] as List).first, closeTo(10.0, 1e-9));
    expect(((map['heartRate'] as Map)['v'] as List).toSet(), {140});
  });

  test('missing values are left out rather than written as zero', () {
    final payload = HealthWorkoutPayload.fromResult(
      _ride(seconds: 300, cadence: null, hr: null, speedKph: null),
      syncId: 'x',
    )!;
    final map = payload.toMap();
    expect((map['cadence'] as Map)['v'], isEmpty);
    expect((map['heartRate'] as Map)['v'], isEmpty);
    expect((map['speed'] as Map)['v'], isEmpty);
    expect((map['distance'] as Map)['v'], isEmpty);
    expect(payload.totalDistanceMeters, 0);
  });

  test('heart rate read from Apple Health is never written back', () {
    final payload = HealthWorkoutPayload.fromResult(_ride(seconds: 300, hrFromHealth: true), syncId: 'x')!;
    expect((payload.toMap()['heartRate'] as Map)['v'], isEmpty);
    // Everything else is still there.
    expect((payload.toMap()['power'] as Map)['v'], hasLength(300));
  });

  test('distance integrates speed over time, chunked per minute', () {
    // 36 km/h = 10 m/s for 330 s → 3300 m, in 6 one-minute chunks.
    final payload = HealthWorkoutPayload.fromResult(_ride(seconds: 330), syncId: 'x')!;
    expect(payload.totalDistanceMeters, closeTo(3300, 1e-6));
    final distance = payload.toMap()['distance'] as Map;
    final values = (distance['v'] as List).cast<double>();
    expect(values, hasLength(6));
    // Samples at 1..60 s: each covers the second before it.
    expect(values.first, closeTo(600, 1e-6));
    expect(values.fold<double>(0, (a, b) => a + b), closeTo(3300, 1e-6));
    expect((distance['s'] as List).first, _start.millisecondsSinceEpoch);
    expect((distance['e'] as List).first, _t(60).millisecondsSinceEpoch);
    // The last chunk ends with the ride, not a full minute later.
    expect((distance['e'] as List).last, _t(330).millisecondsSinceEpoch);
  });

  test('active energy: kJ from power, taken as kcal', () {
    // 200 W for 300 s = 60 000 J = 60 kJ ≈ 60 kcal.
    final payload = HealthWorkoutPayload.fromResult(_ride(seconds: 300), syncId: 'x')!;
    expect(payload.totalEnergyKcal, closeTo(60, 1e-6));
    final energy = payload.toMap()['energy'] as Map;
    expect((energy['v'] as List).cast<double>().fold<double>(0, (a, b) => a + b), closeTo(60, 1e-6));
  });

  test('samples inside a pause and gaps across it do not count', () {
    final samples = [
      for (var i = 1; i <= 200; i++) WorkoutSample(timestamp: _t(i), powerW: 100, speedKph: 36),
      // Coasting samples recorded before the (backdated) pause was detected.
      for (var i = 201; i <= 210; i++) WorkoutSample(timestamp: _t(i), powerW: 0, speedKph: 36),
      // Resumed after the 100 s pause: the first sample must not be credited
      // with the whole gap.
      for (var i = 301; i <= 400; i++) WorkoutSample(timestamp: _t(i), powerW: 100, speedKph: 36),
    ];
    final ride = WorkoutResult(
      samples: samples,
      startedAt: _start,
      endedAt: _t(400),
      activeDuration: const Duration(seconds: 300),
      pauses: [WorkoutPause(start: _t(200), end: _t(300))],
      summary: WorkoutSummary.fromSamples(samples, startedAt: _start, activeDuration: const Duration(seconds: 300)),
    );
    final payload = HealthWorkoutPayload.fromResult(ride, syncId: 'x')!;
    expect((payload.toMap()['power'] as Map)['v'], hasLength(300));
    // 200 + 100 credited seconds at 10 m/s / 100 W; the paused time is
    // taken out of the gap before sample 301.
    expect(payload.totalDistanceMeters, closeTo(3000, 1e-6));
    expect(payload.totalEnergyKcal, closeTo(30, 1e-6));
  });

  test('a gap from missed ticks is credited at most maxSampleGap', () {
    final samples = [
      for (var i = 1; i <= 300; i++) WorkoutSample(timestamp: _t(i), powerW: 100, speedKph: 36),
      WorkoutSample(timestamp: _t(400), powerW: 100, speedKph: 36),
    ];
    final ride = WorkoutResult(
      samples: samples,
      startedAt: _start,
      endedAt: _t(400),
      activeDuration: const Duration(seconds: 400),
      pauses: const [],
      summary: WorkoutSummary.fromSamples(samples, startedAt: _start, activeDuration: const Duration(seconds: 400)),
    );
    final payload = HealthWorkoutPayload.fromResult(ride, syncId: 'x')!;
    final cap = HealthWorkoutPayload.maxSampleGap.inSeconds;
    expect(payload.totalDistanceMeters, closeTo(3000 + 10.0 * cap, 1e-6));
    expect(payload.totalEnergyKcal, closeTo(30 + 0.1 * cap, 1e-6));
  });

  test('samples after the (backdated) end are left out', () {
    // Auto-stop ends the ride at the last pedal stroke; the recorder kept
    // sampling for the seconds until the pause was noticed.
    final samples = [
      for (var i = 1; i <= 310; i++) WorkoutSample(timestamp: _t(i), powerW: i <= 300 ? 100 : 0, speedKph: 36),
    ];
    final ride = WorkoutResult(
      samples: samples,
      startedAt: _start,
      endedAt: _t(300),
      activeDuration: const Duration(seconds: 300),
      pauses: const [],
      summary: WorkoutSummary.fromSamples(samples, startedAt: _start, activeDuration: const Duration(seconds: 300)),
    );
    final payload = HealthWorkoutPayload.fromResult(ride, syncId: 'x')!;
    expect((payload.toMap()['power'] as Map)['v'], hasLength(300));
    expect(payload.totalDistanceMeters, closeTo(3000, 1e-6));
  });

  test('newRideSyncId is a random v4 UUID', () {
    final a = newRideSyncId();
    final b = newRideSyncId();
    final v4 = RegExp(r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$');
    expect(a, matches(v4));
    expect(b, matches(v4));
    expect(a, isNot(b));
  });
}
