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
        nowProvider: () =>
            DateTime.utc(2026, 4, 24, 10, 0, 0).add(Duration(milliseconds: async.elapsed.inMilliseconds)),
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
        nowProvider: () =>
            DateTime.utc(2026, 4, 24, 10, 0, 0).add(Duration(milliseconds: async.elapsed.inMilliseconds)),
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

  group('health export bookkeeping', () {
    DateTime base() => DateTime.utc(2026, 4, 24, 10, 0, 0);

    test('pause intervals and end time are reported; a pause open at stop closes at the end', () {
      fakeAsync((async) {
        final fake = _Fake();
        final rec = WorkoutRecorder(nowProvider: () => base().add(async.elapsed));
        rec.start(fake.metrics);
        async.elapse(const Duration(seconds: 10));
        rec.pause();
        async.elapse(const Duration(seconds: 5));
        rec.resume();
        async.elapse(const Duration(seconds: 10));
        rec.pause();
        async.elapse(const Duration(seconds: 3));

        final result = rec.stop();
        expect(result.endedAt, base().add(const Duration(seconds: 28)));
        expect(result.pauses, hasLength(2));
        expect(result.pauses[0].start, base().add(const Duration(seconds: 10)));
        expect(result.pauses[0].end, base().add(const Duration(seconds: 15)));
        expect(result.pauses[1].start, base().add(const Duration(seconds: 25)));
        expect(result.pauses[1].end, base().add(const Duration(seconds: 28)));
        expect(result.activeDuration, const Duration(seconds: 20));
      });
    });

    test('a backdated pause excludes the coast from active time', () {
      fakeAsync((async) {
        final fake = _Fake();
        final rec = WorkoutRecorder(nowProvider: () => base().add(async.elapsed));
        rec.start(fake.metrics);
        async.elapse(const Duration(seconds: 30));
        // Pedalling stopped at 20 s; the pause is only detected at 30 s.
        rec.pause(at: base().add(const Duration(seconds: 20)));
        async.elapse(const Duration(seconds: 60));

        // Stopping at the pause start drops the trailing pause entirely.
        final result = rec.stop(at: base().add(const Duration(seconds: 20)));
        expect(result.activeDuration, const Duration(seconds: 20));
        expect(result.endedAt, base().add(const Duration(seconds: 20)));
        expect(result.pauses, isEmpty);
      });
    });

    test('samples carry whether heart rate came from Apple Health', () {
      fakeAsync((async) {
        final fake = _Fake();
        var fromHealth = true;
        final metrics = TrainerMetrics(
          powerW: fake.power,
          cadenceRpm: fake.cadence,
          speedKph: fake.speed,
          heartRateBpm: fake.hr,
          isHeartRateFromHealth: () => fromHealth,
        );
        final rec = WorkoutRecorder(nowProvider: () => base().add(async.elapsed));
        fake.hr.value = 120;
        rec.start(metrics);
        async.elapse(const Duration(seconds: 1));
        fromHealth = false;
        async.elapse(const Duration(seconds: 1));

        final result = rec.stop();
        expect(result.samples.map((s) => s.heartRateFromHealth), [true, false]);
      });
    });

    test('updateMetrics swaps the source mid-recording (trainer reconnected)', () {
      fakeAsync((async) {
        final first = _Fake()..power.value = 100;
        final second = _Fake()..power.value = 250;
        final rec = WorkoutRecorder(nowProvider: () => base().add(async.elapsed));
        rec.start(first.metrics);
        async.elapse(const Duration(seconds: 1));
        rec.updateMetrics(second.metrics);
        async.elapse(const Duration(seconds: 1));

        expect(rec.samples.map((s) => s.powerW), [100, 250]);
        expect(rec.startedAt, base());
      });
    });
  });

  group('gear changes', () {
    DateTime base() => DateTime.utc(2026, 4, 24, 10, 0, 0);

    test('counts every rear and front shift while the ride runs, not before or after', () {
      fakeAsync((async) {
        final fake = _Fake();
        final gear = ValueNotifier<int>(12);
        final front = ValueNotifier<Object?>('small');
        final metrics = TrainerMetrics(
          powerW: fake.power,
          cadenceRpm: fake.cadence,
          speedKph: fake.speed,
          heartRateBpm: fake.hr,
          gear: gear,
          frontRing: front,
        );
        final rec = WorkoutRecorder(nowProvider: () => base().add(async.elapsed));
        gear.value = 13; // before the ride: not counted
        rec.start(metrics);
        gear.value = 14;
        gear.value = 15;
        front.value = 'large';
        async.elapse(const Duration(seconds: 2));
        rec.pause();
        gear.value = 14; // a shift while paused still happened on this ride
        rec.resume();
        expect(rec.gearChanges.value, 4);
        final result = rec.stop();
        expect(result.gearChanges, 4);
        expect(result.summary.gearChanges, 4);
        gear.value = 10; // after the ride: not counted
        expect(rec.gearChanges.value, 0);
      });
    });

    test('a reconnect that rebuilds the gear notifier is not a shift', () {
      fakeAsync((async) {
        final fake = _Fake();
        final first = ValueNotifier<int>(12);
        final second = ValueNotifier<int>(12);
        TrainerMetrics m(ValueNotifier<int> g) => TrainerMetrics(
          powerW: fake.power,
          cadenceRpm: fake.cadence,
          speedKph: fake.speed,
          heartRateBpm: fake.hr,
          gear: g,
        );
        final rec = WorkoutRecorder(nowProvider: () => base().add(async.elapsed));
        rec.start(m(first));
        first.value = 15;
        rec.updateMetrics(m(second)); // fresh definition back at 12
        first.value = 16; // the old one is no longer listened to
        second.value = 13;
        expect(rec.stop().gearChanges, 2);
      });
    });

    test('each sample carries the gear it was ridden in', () {
      fakeAsync((async) {
        final fake = _Fake();
        final gear = ValueNotifier<int>(12);
        final metrics = TrainerMetrics(
          powerW: fake.power,
          cadenceRpm: fake.cadence,
          speedKph: fake.speed,
          heartRateBpm: fake.hr,
          gear: gear,
        );
        final rec = WorkoutRecorder(nowProvider: () => base().add(async.elapsed));
        rec.start(metrics);
        async.elapse(const Duration(seconds: 1));
        gear.value = 14;
        async.elapse(const Duration(seconds: 2));
        expect(rec.stop().samples.map((s) => s.gear), [12, 14, 14]);
      });
    });

    test('without a gear source samples have no gear', () {
      fakeAsync((async) {
        final rec = WorkoutRecorder(nowProvider: () => base().add(async.elapsed));
        rec.start(_Fake().metrics);
        async.elapse(const Duration(seconds: 2));
        expect(rec.stop().samples.map((s) => s.gear), [null, null]);
      });
    });

    test('without a gear source the count stays unknown', () {
      fakeAsync((async) {
        final rec = WorkoutRecorder(nowProvider: () => base().add(async.elapsed));
        rec.start(_Fake().metrics);
        async.elapse(const Duration(seconds: 1));
        expect(rec.stop().summary.gearChanges, isNull);
      });
    });
  });
}
