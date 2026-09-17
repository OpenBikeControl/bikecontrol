import 'package:bike_control/services/health/auto_ride_controller.dart';
import 'package:bike_control/services/workout/trainer_metrics.dart';
import 'package:bike_control/services/workout/workout_recorder.dart';
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
  _Rig(this.async, {this.record = true, this.detect = false}) {
    recorder = WorkoutRecorder(nowProvider: now);
    controller = AutoRideController(
      recorder: recorder,
      connectedTrainer: () => connected ? trainer.metrics : null,
      shouldRecord: () => record,
      shouldDetect: () => detect,
      onRideFinished: finished.add,
      onRideDetected: () => detections++,
      now: now,
    )..start();
  }

  final FakeAsync async;
  bool record;
  bool detect;
  bool connected = true;
  final trainer = _Trainer();
  late final WorkoutRecorder recorder;
  late final AutoRideController controller;
  final finished = <WorkoutResult>[];
  int detections = 0;

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
      expect(rig.controller.isAutoRecording.value, isFalse);
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
      expect(rig.controller.isAutoRecording.value, isTrue);
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
      rig.controller.finishNow();
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
      expect(rig.controller.isAutoRecording.value, isFalse);
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

  test('leaves a manual recording alone', () {
    fakeAsync((async) {
      final rig = _Rig(async);
      rig.trainer.cadence.value = 0;
      rig.recorder.start(rig.trainer.metrics);
      rig.runTo(700);
      expect(rig.state, WorkoutState.recording);
      expect(rig.controller.isAutoRecording.value, isFalse);
      expect(rig.finished, isEmpty);
      rig.recorder.stop();
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
      rig.controller.finishNow();
      expect(rig.finished, hasLength(1));
      expect(rig.finished.single.endedAt, rig.at(30).add(const Duration(milliseconds: 1)));
      rig.runTo(60);
      expect(rig.state, WorkoutState.idle);
      rig.dispose();
    });
  });

  group('detection only (setting undecided or not Pro)', () {
    test('reports a ride of at least 5 min once it ends, without recording', () {
      fakeAsync((async) {
        final rig = _Rig(async, record: false, detect: true);
        rig.trainer.cadence.value = 90;
        rig.runTo(400);
        expect(rig.state, WorkoutState.idle);
        rig.trainer.cadence.value = 0;
        rig.runTo(699);
        expect(rig.detections, 0);
        rig.runTo(700);
        expect(rig.detections, 1);
        rig.runTo(2000);
        expect(rig.detections, 1);
        rig.dispose();
      });
    });

    test('ignores a short spin', () {
      fakeAsync((async) {
        final rig = _Rig(async, record: false, detect: true);
        rig.trainer.cadence.value = 90;
        rig.runTo(120);
        rig.trainer.cadence.value = 0;
        rig.runTo(1000);
        expect(rig.detections, 0);
        rig.dispose();
      });
    });

    test('also ends on disconnect', () {
      fakeAsync((async) {
        final rig = _Rig(async, record: false, detect: true);
        rig.trainer.cadence.value = 90;
        rig.runTo(400);
        rig.connected = false;
        rig.runTo(521);
        expect(rig.detections, 1);
        rig.dispose();
      });
    });
  });

  test('a recorded ride of 5 min or more also counts as detected', () {
    fakeAsync((async) {
      final rig = _Rig(async);
      rig.trainer.cadence.value = 90;
      rig.runTo(400);
      rig.trainer.cadence.value = 0;
      rig.runTo(700);
      expect(rig.detections, 1);
      rig.dispose();
    });
  });
}
