import 'package:bike_control/services/rides/ride_detector.dart';
import 'package:bike_control/services/workout/trainer_metrics.dart';
import 'package:bike_control/services/workout/workout_recorder.dart';
import 'package:bike_control/services/workout/workout_sample.dart';
import 'package:bike_control/services/workout/workout_summary.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

class _Trainer {
  final power = ValueNotifier<int?>(null);
  final cadence = ValueNotifier<int?>(null);
  final speed = ValueNotifier<double?>(null);
  final hr = ValueNotifier<int?>(null);

  late final metrics = TrainerMetrics(powerW: power, cadenceRpm: cadence, speedKph: speed, heartRateBpm: hr);
}

/// Wires a controller to a scripted trainer on a fake clock. Everything is
/// driven from the 1 Hz tick, so `at(seconds)` reads as "the ride's clock".
class _Rig {
  _Rig(this.async, {this.record = true}) {
    recorder = WorkoutRecorder(nowProvider: now);
    controller = RideDetector(
      recorder: recorder,
      source: () => connected ? trainer.metrics : null,
      autoRecord: () => record,
      onRideFinished: (result, reason) {
        finished.add(result);
        reasons.add(reason);
      },
      now: now,
    )..start();
  }

  final FakeAsync async;
  bool record;
  bool connected = true;
  final trainer = _Trainer();
  late final WorkoutRecorder recorder;
  late final RideDetector controller;
  final finished = <WorkoutResult>[];
  final reasons = <RideEndReason>[];

  static final base = DateTime.utc(2026, 9, 16, 18);

  DateTime now() => base.add(async.elapsed);

  DateTime at(int seconds) => base.add(Duration(seconds: seconds));

  /// Elapses to just after [seconds] so the tick at exactly that second has run.
  void runTo(int seconds) {
    final target = Duration(seconds: seconds, milliseconds: 1);
    if (target > async.elapsed) async.elapse(target - async.elapsed);
  }

  WorkoutState get state => recorder.state.value;

  void dispose() {
    controller.dispose();
    recorder.dispose();
  }
}

void main() {
  test('stays idle while the setting is off, however hard the rider pedals', () {
    fakeAsync((async) {
      final rig = _Rig(async, record: false);
      rig.trainer.cadence.value = 90;
      rig.trainer.power.value = 200;
      rig.runTo(30);
      expect(rig.state, WorkoutState.idle);
      expect(rig.controller.startedAutomatically.value, isFalse);
      rig.dispose();
    });
  });

  test('does not start without a connected trainer or without pedalling', () {
    fakeAsync((async) {
      final rig = _Rig(async);
      rig.connected = false;
      rig.trainer.cadence.value = 90;
      rig.runTo(5);
      expect(rig.state, WorkoutState.idle);

      rig.connected = true;
      rig.trainer.cadence.value = 0;
      rig.trainer.power.value = 0;
      rig.runTo(10);
      expect(rig.state, WorkoutState.idle);
      rig.dispose();
    });
  });

  test('starts on cadence alone', () {
    fakeAsync((async) {
      final rig = _Rig(async);
      rig.trainer.cadence.value = 85;
      rig.runTo(1);
      expect(rig.state, WorkoutState.recording);
      expect(rig.controller.startedAutomatically.value, isTrue);
      rig.dispose();
    });
  });

  test('starts on power alone', () {
    fakeAsync((async) {
      final rig = _Rig(async);
      rig.trainer.power.value = 120;
      rig.runTo(1);
      expect(rig.state, WorkoutState.recording);
      rig.dispose();
    });
  });

  test('pauses after 10 s without pedalling (backdated), resumes on pedalling', () {
    fakeAsync((async) {
      final rig = _Rig(async);
      rig.trainer.cadence.value = 90;
      rig.runTo(60);
      rig.trainer.cadence.value = 0;

      rig.runTo(69);
      expect(rig.state, WorkoutState.recording);
      rig.runTo(70);
      expect(rig.state, WorkoutState.paused);

      rig.runTo(100);
      rig.trainer.power.value = 150;
      rig.runTo(101);
      expect(rig.state, WorkoutState.recording);

      rig.runTo(131);
      rig.controller.finish();
      final ride = rig.finished.single;
      // 1 s → 60 s pedalling, paused 60 s → 101 s, then 101 s → 131 s (+ the
      // 1 ms runTo overshoots by, since finishNow ends the ride "now").
      expect(ride.activeDuration, const Duration(seconds: 89, milliseconds: 1));
      expect(ride.pauses.single.start, rig.at(60));
      expect(ride.pauses.single.end, rig.at(101));
      rig.dispose();
    });
  });

  test('stops 5 min after the last pedal stroke and ends the ride there', () {
    fakeAsync((async) {
      final rig = _Rig(async);
      rig.trainer.cadence.value = 90;
      rig.runTo(400);
      rig.trainer.cadence.value = 0;

      rig.runTo(699);
      expect(rig.finished, isEmpty);
      rig.runTo(700);
      expect(rig.state, WorkoutState.idle);
      expect(rig.controller.startedAutomatically.value, isFalse);
      final ride = rig.finished.single;
      expect(ride.startedAt, rig.at(1));
      expect(ride.endedAt, rig.at(400));
      expect(ride.activeDuration, const Duration(seconds: 399));
      expect(ride.pauses, isEmpty);
      rig.dispose();
    });
  });

  test('stops 2 min after the trainer disconnects', () {
    fakeAsync((async) {
      final rig = _Rig(async);
      rig.trainer.cadence.value = 90;
      rig.runTo(400);
      rig.connected = false;

      rig.runTo(520);
      expect(rig.finished, isEmpty);
      rig.runTo(521);
      expect(rig.finished, hasLength(1));
      expect(rig.state, WorkoutState.idle);
      rig.dispose();
    });
  });

  test('a reconnect within 2 min cancels the stop and keeps recording', () {
    fakeAsync((async) {
      final rig = _Rig(async);
      rig.trainer.cadence.value = 90;
      rig.runTo(400);
      rig.connected = false;
      rig.runTo(500);
      expect(rig.state, WorkoutState.paused);

      rig.connected = true;
      rig.runTo(510);
      expect(rig.state, WorkoutState.recording);
      rig.runTo(700);
      expect(rig.finished, isEmpty);
      expect(rig.state, WorkoutState.recording);
      rig.dispose();
    });
  });

  test('a manual start follows the same flow: auto-pause, resume and end', () {
    fakeAsync((async) {
      final rig = _Rig(async, record: false);
      expect(rig.controller.startManual(), isTrue);
      expect(rig.state, WorkoutState.recording);
      expect(rig.controller.startedAutomatically.value, isFalse);
      // Nobody pedals yet: it pauses after 10 s like an automatic ride.
      rig.runTo(10);
      expect(rig.state, WorkoutState.paused);
      rig.trainer.cadence.value = 90;
      rig.runTo(11);
      expect(rig.state, WorkoutState.recording);
      rig.runTo(200);
      rig.trainer.cadence.value = 0;
      rig.runTo(500);
      expect(rig.reasons, [RideEndReason.idle]);
      expect(rig.finished.single.endedAt, rig.at(200));
      rig.dispose();
    });
  });

  test('a manual start without anything to record from does nothing', () {
    fakeAsync((async) {
      final rig = _Rig(async, record: false);
      rig.connected = false;
      expect(rig.controller.startManual(), isFalse);
      expect(rig.state, WorkoutState.idle);
      rig.dispose();
    });
  });

  test('Beenden ends the ride now and reports it as a manual finish', () {
    fakeAsync((async) {
      final rig = _Rig(async);
      rig.trainer.cadence.value = 90;
      rig.runTo(30);
      final result = rig.controller.finish();
      expect(result, isNotNull);
      expect(rig.reasons, [RideEndReason.finished]);
      rig.dispose();
    });
  });

  test('discard drops the ride and waits for a real break before starting again', () {
    fakeAsync((async) {
      final rig = _Rig(async);
      rig.trainer.cadence.value = 90;
      rig.runTo(30);
      rig.controller.discard();
      expect(rig.state, WorkoutState.idle);
      expect(rig.finished, isEmpty);

      // Still pedalling: no instant new ride.
      rig.runTo(60);
      expect(rig.state, WorkoutState.idle);

      rig.trainer.cadence.value = 0;
      rig.runTo(61);
      rig.trainer.cadence.value = 90;
      rig.runTo(62);
      expect(rig.state, WorkoutState.recording);
      rig.dispose();
    });
  });

  test('finishNow hands the ride over and does not restart mid-pedal', () {
    fakeAsync((async) {
      final rig = _Rig(async);
      rig.trainer.cadence.value = 90;
      rig.runTo(30);
      rig.controller.finish();
      expect(rig.finished, hasLength(1));
      expect(rig.finished.single.endedAt, rig.at(30).add(const Duration(milliseconds: 1)));
      rig.runTo(60);
      expect(rig.state, WorkoutState.idle);
      rig.dispose();
    });
  });

  group('too short to keep', () {
    WorkoutResult ride(Duration moving, int watts) {
      final start = DateTime.utc(2026);
      final samples = [WorkoutSample(timestamp: start, powerW: watts)];
      return WorkoutResult(
        samples: samples,
        startedAt: start,
        endedAt: start.add(moving),
        activeDuration: moving,
        pauses: const [],
        summary: WorkoutSummary.fromSamples(samples, startedAt: start, activeDuration: moving),
      );
    }

    test('under 2 min moving AND under 10 kJ is discarded', () {
      expect(RideDetector.isTooShort(ride(const Duration(seconds: 119), 80)), isTrue);
    });

    test('2 min of moving time is kept, however easy', () {
      expect(RideDetector.isTooShort(ride(const Duration(minutes: 2), 20)), isFalse);
    });

    test('a short hard effort over 10 kJ is kept', () {
      // 100 s at 110 W = 11 kJ.
      expect(RideDetector.isTooShort(ride(const Duration(seconds: 100), 110)), isFalse);
    });
  });

  test('a heart-rate strap alone never starts a ride', () {
    fakeAsync((async) {
      final rig = _Rig(async);
      rig.trainer.hr.value = 130;
      rig.runTo(30);
      expect(rig.state, WorkoutState.idle);
      rig.dispose();
    });
  });
}
