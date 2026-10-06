import 'dart:math' as math;

import 'package:bike_control/services/workout/fit_writer.dart';
import 'package:bike_control/services/workout/memory_workout_repository.dart';
import 'package:bike_control/services/workout/past_workout.dart';
import 'package:bike_control/services/workout/workout_recorder.dart';
import 'package:bike_control/services/workout/workout_sample.dart';
import 'package:bike_control/services/workout/workout_summary.dart';

/// A believable ride (the mock's: 42:18 moving, a 1:44 pause, Ø ≈ 212 W),
/// saved into [repo] with its .fit so exports can read the series back.
/// With [gearChanges] it was ridden with virtual shifting: every second has
/// a gear, from 9 up to 13 and down again every few minutes.
Future<PastWorkout> saveSampleRide(
  MemoryWorkoutRepository repo, {
  DateTime? start,
  Duration moving = const Duration(minutes: 42, seconds: 18),
  Duration pauseAt = const Duration(minutes: 22, seconds: 10),
  Duration pause = const Duration(minutes: 1, seconds: 44),
  bool speed = true,
  bool heartRate = true,
  int? gearChanges = 37,
  int seed = 7,
  int avgWatts = 212,
}) async {
  final t0 = start ?? DateTime.now().subtract(const Duration(minutes: 50));
  final rnd = math.Random(seed);
  final samples = <WorkoutSample>[];
  final elapsed = moving + pause;
  var hr = 96.0;
  for (var s = 1; s <= elapsed.inSeconds; s++) {
    final at = Duration(seconds: s);
    if (at > pauseAt && at <= pauseAt + pause) continue;
    final m = s / 60;
    var w = avgWatts + 18 * math.sin(m / 2.3) + 10 * math.sin(m / 0.9) + (rnd.nextDouble() - .5) * 30;
    for (final c in [0.21, 0.30, 0.39, 0.62, 0.72]) {
      final cm = c * elapsed.inMinutes;
      if (m >= cm && m < cm + 1.5) w = avgWatts * 1.45 + rnd.nextDouble() * 25;
    }
    if (m < 6) w = avgWatts * (0.6 + m / 6 * 0.35);
    hr += ((62 + w * 0.38) - hr) * 0.06;
    samples.add(
      WorkoutSample(
        timestamp: t0.add(at),
        powerW: w.round(),
        cadenceRpm: 84 + rnd.nextInt(8),
        speedKph: speed ? 34 + w / 40 : null,
        heartRateBpm: heartRate ? math.min(176, hr.round()) : null,
        gear: gearChanges == null ? null : 9 + (m ~/ 3) % 5,
      ),
    );
  }
  final pauses = [WorkoutPause(start: t0.add(pauseAt), end: t0.add(pauseAt + pause))];
  final end = t0.add(elapsed);
  final summary = WorkoutSummary.fromSamples(
    samples,
    startedAt: t0,
    activeDuration: moving,
    endedAt: end,
    pauses: pauses,
    gearChanges: gearChanges,
    trainerName: 'KICKR CORE',
    appName: 'MyWhoosh',
    autoStarted: true,
  );
  final bytes = FitFileWriter.encode(samples: samples, summary: summary, pauses: pauses, endedAt: end);
  final file = await repo.save(startedAt: t0, fitBytes: bytes, summary: summary);
  return PastWorkout(file: file, startedAt: t0.toUtc(), sizeBytes: bytes.length, summary: summary);
}
