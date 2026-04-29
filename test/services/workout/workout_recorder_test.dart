import 'package:bike_control/services/workout/trainer_metrics.dart';
import 'package:bike_control/services/workout/workout_recorder.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

class _Fake {
  final power = ValueNotifier<int?>(null);
  final cadence = ValueNotifier<int?>(null);
  final speed = ValueNotifier<double?>(null);
  final hr = ValueNotifier<int?>(null);

  TrainerMetrics get metrics => TrainerMetrics(
        powerW: power,
        cadenceRpm: cadence,
        speedKph: speed,
        heartRateBpm: hr,
      );
}

void main() {
  test('idle → recording → idle, collects samples at tick rate', () async {
    fakeAsync((async) {
      final fake = _Fake();
      final rec = WorkoutRecorder(
        nowProvider: () => DateTime.utc(2026, 4, 24, 10, 0, 0).add(Duration(milliseconds: async.elapsed.inMilliseconds)),
        tick: const Duration(milliseconds: 100),
      );
      expect(rec.state.value, WorkoutState.idle);

      rec.start(fake.metrics);
      expect(rec.state.value, WorkoutState.recording);

      fake.power.value = 200;
      async.elapse(const Duration(milliseconds: 100));
      fake.power.value = 210;
      async.elapse(const Duration(milliseconds: 100));

      final result = rec.stop();
      expect(rec.state.value, WorkoutState.idle);
      expect(result.samples.length, greaterThanOrEqualTo(2));
      expect(result.samples.first.powerW, 200);
    });
  });

  test('pause skips samples and excludes time from active duration', () async {
    fakeAsync((async) {
      final fake = _Fake();
      final rec = WorkoutRecorder(
        nowProvider: () => DateTime.utc(2026, 4, 24, 10, 0, 0).add(Duration(milliseconds: async.elapsed.inMilliseconds)),
        tick: const Duration(milliseconds: 100),
      );

      rec.start(fake.metrics);
      fake.power.value = 100;
      async.elapse(const Duration(milliseconds: 300));

      rec.pause();
      expect(rec.state.value, WorkoutState.paused);
      final beforePause = rec.samples.length;
      async.elapse(const Duration(milliseconds: 500));
      expect(rec.samples.length, beforePause); // no new samples while paused

      rec.resume();
      fake.power.value = 150;
      async.elapse(const Duration(milliseconds: 200));

      final result = rec.stop();
      expect(result.activeDuration.inMilliseconds, inInclusiveRange(400, 600));
    });
  });
}
