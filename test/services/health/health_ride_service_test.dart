import 'package:bike_control/services/health/fake_health_workout_channel.dart';
import 'package:bike_control/services/health/health_ride_preferences.dart';
import 'package:bike_control/services/health/health_ride_service.dart';
import 'package:bike_control/services/health/health_workout_payload.dart';
import 'package:bike_control/services/sensors/health_kit_channel.dart';
import 'package:bike_control/services/workout/trainer_metrics.dart';
import 'package:bike_control/services/workout/workout_recorder.dart';
import 'package:bike_control/services/workout/workout_sample.dart';
import 'package:bike_control/services/workout/workout_summary.dart';
import 'package:bike_control/utils/keymap/apps/my_whoosh.dart';
import 'package:bike_control/utils/keymap/apps/supported_app.dart';
import 'package:bike_control/utils/keymap/apps/zwift.dart';
import 'package:bike_control/utils/requirements/multi.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Feedback implements HealthRideFeedback {
  final saved = <HealthRideSaved>[];
  final failures = <bool>[];

  @override
  void onSaved(HealthRideSaved ride) => saved.add(ride);

  @override
  void onFailed({required bool denied}) => failures.add(denied);
}

class _Trainer {
  final power = ValueNotifier<int?>(null);
  final cadence = ValueNotifier<int?>(null);
  late final metrics = TrainerMetrics(
    powerW: power,
    cadenceRpm: cadence,
    speedKph: ValueNotifier<double?>(null),
    heartRateBpm: ValueNotifier<int?>(null),
  );
}

class _Rig {
  _Rig(this.async, this.prefs, {Duration minRide = HealthRideService.defaultMinRide}) {
    recorder = WorkoutRecorder(nowProvider: now);
    service = HealthRideService(
      recorder: recorder,
      prefs: prefs,
      channel: channel,
      feedback: feedback,
      isPlatformSupported: () => platform,
      isPro: () => pro,
      trainerApp: () => app,
      target: () => target,
      connectedTrainer: () => trainer.metrics,
      saveFit: (result) async => fitSaves.add(result),
      onError: (e, s, context) => errors.add(e),
      now: now,
      newSyncId: () => 'sync-${++syncIds}',
      minRide: minRide,
    );
  }

  final FakeAsync async;
  final HealthRidePreferences prefs;
  final channel = FakeHealthWorkoutChannel();
  final feedback = _Feedback();
  final trainer = _Trainer();
  final fitSaves = <WorkoutResult>[];
  final errors = <Object>[];
  late final WorkoutRecorder recorder;
  late final HealthRideService service;
  bool platform = true;
  bool pro = true;
  SupportedApp? app = MyWhoosh();
  Target? target = Target.thisDevice;
  int syncIds = 0;

  static final base = DateTime.utc(2026, 9, 16, 18);
  DateTime now() => base.add(async.elapsed);

  Future<void> boot() async {
    await service.start();
  }

  /// Pedal for [seconds], then stop pedalling and wait out the auto-stop.
  void ride(int seconds) {
    trainer.cadence.value = 90;
    trainer.power.value = 200;
    async.elapse(Duration(seconds: seconds));
    trainer.cadence.value = 0;
    trainer.power.value = 0;
    async.elapse(const Duration(minutes: 5, seconds: 2));
    async.flushMicrotasks();
  }

  void dispose() {
    service.dispose();
    recorder.dispose();
  }
}

WorkoutResult _manualRide(int seconds) {
  final start = DateTime.utc(2026, 9, 16, 7);
  final samples = [
    for (var i = 1; i <= seconds; i++) WorkoutSample(timestamp: start.add(Duration(seconds: i)), powerW: 100),
  ];
  return WorkoutResult(
    samples: samples,
    startedAt: start,
    endedAt: start.add(Duration(seconds: seconds)),
    activeDuration: Duration(seconds: seconds),
    pauses: const [],
    summary: WorkoutSummary.fromSamples(samples, startedAt: start, activeDuration: Duration(seconds: seconds)),
  );
}

void main() {
  late HealthRidePreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = HealthRidePreferences(await SharedPreferences.getInstance());
  });

  void run(void Function(_Rig rig) body) {
    fakeAsync((async) {
      final rig = _Rig(async, prefs);
      rig.boot();
      async.flushMicrotasks();
      body(rig);
      rig.dispose();
    });
  }

  group('enabled explicitly', () {
    test('an auto ride is saved as FIT and written to Health once, with a sync id', () {
      run((rig) {
        rig.prefs.setExplicitChoice(true);
        rig.ride(600);
        expect(rig.fitSaves, hasLength(1));
        expect(rig.channel.saved, hasLength(1));
        expect(rig.channel.saved.single.syncId, 'sync-1');
        expect(rig.feedback.saved.single.activeDuration, const Duration(seconds: 599));
        // The ride's own summary average, which still contains the few
        // zero-watt seconds before the auto-pause kicked in.
        expect(rig.feedback.saved.single.avgPowerW, inInclusiveRange(190, 200));
        expect(rig.feedback.saved.single.energyKcal, greaterThan(0));
        expect(rig.service.pendingRide.value, isNull);
      });
    });

    test('an auto ride under 5 min is dropped: no FIT, no Health', () {
      run((rig) {
        rig.prefs.setExplicitChoice(true);
        rig.ride(120);
        expect(rig.fitSaves, isEmpty);
        expect(rig.channel.saved, isEmpty);
        expect(rig.feedback.saved, isEmpty);
      });
    });

    test('a write failure is recorded, reported, and the FIT is kept', () {
      run((rig) {
        rig.prefs.setExplicitChoice(true);
        rig.channel.saveError = PlatformException(code: 'save', message: 'boom');
        rig.ride(600);
        expect(rig.fitSaves, hasLength(1));
        expect(rig.errors.single, isA<PlatformException>());
        expect(rig.feedback.failures, [false]);
      });
    });

    test('a denied write is reported as denied', () {
      run((rig) {
        rig.prefs.setExplicitChoice(true);
        rig.channel.saveError = PlatformException(code: 'denied', message: 'no');
        rig.ride(600);
        expect(rig.feedback.failures, [true]);
        expect(rig.errors, hasLength(1));
      });
    });

    test('a manual ride is written too; a short one is skipped', () {
      run((rig) {
        rig.prefs.setExplicitChoice(true);
        rig.service.onManualRideFinished(_manualRide(600));
        rig.service.onManualRideFinished(_manualRide(200));
        rig.async.flushMicrotasks();
        expect(rig.channel.saved, hasLength(1));
        // The manual flow saves its own FIT.
        expect(rig.fitSaves, isEmpty);
      });
    });

    test('without Pro nothing is recorded or written', () {
      run((rig) {
        rig.prefs.setExplicitChoice(true);
        rig.pro = false;
        rig.ride(600);
        rig.service.onManualRideFinished(_manualRide(600));
        rig.async.flushMicrotasks();
        expect(rig.recorder.state.value, WorkoutState.idle);
        expect(rig.fitSaves, isEmpty);
        expect(rig.channel.saved, isEmpty);
      });
    });
  });

  group('disabled explicitly', () {
    test('nothing auto-records and a manual ride is not written', () {
      run((rig) {
        rig.prefs.setExplicitChoice(false);
        rig.ride(600);
        rig.service.onManualRideFinished(_manualRide(600));
        rig.async.flushMicrotasks();
        expect(rig.fitSaves, isEmpty);
        expect(rig.channel.saved, isEmpty);
        expect(rig.service.showsPrompt, isFalse);
      });
    });
  });

  group('undecided', () {
    test('default-on: the ride is recorded but held for the prompt, not written', () {
      run((rig) {
        rig.ride(600);
        expect(rig.fitSaves, hasLength(1));
        expect(rig.channel.saved, isEmpty);
        expect(rig.service.pendingRide.value, isNotNull);
        expect(rig.service.showsPrompt, isTrue);
      });
    });

    test('accepting authorizes, turns the setting on and writes the held ride', () {
      run((rig) {
        rig.ride(600);
        rig.service.acceptPrompt();
        rig.async.flushMicrotasks();
        expect(rig.channel.authorizeCalls, 1);
        expect(rig.prefs.explicitChoice, isTrue);
        expect(rig.channel.saved, hasLength(1));
        expect(rig.service.pendingRide.value, isNull);
        expect(rig.service.showsPrompt, isFalse);
      });
    });

    test('accepting with Health denied keeps the setting undecided and reports it', () {
      run((rig) {
        rig.ride(600);
        rig.channel.authorization = HealthKitAuthorization.denied;
        rig.service.acceptPrompt();
        rig.async.flushMicrotasks();
        expect(rig.prefs.explicitChoice, isNull);
        expect(rig.channel.saved, isEmpty);
        expect(rig.feedback.failures, [true]);
      });
    });

    test('dismissing turns it off for good and hides the prompt', () {
      run((rig) {
        rig.ride(600);
        rig.service.dismissPrompt();
        rig.async.flushMicrotasks();
        expect(rig.prefs.explicitChoice, isFalse);
        expect(rig.prefs.promptDismissed, isTrue);
        expect(rig.service.pendingRide.value, isNull);
        expect(rig.service.showsPrompt, isFalse);
      });
    });

    test('default-off (Zwift on this device): detected, not recorded, prompt shown', () {
      run((rig) {
        rig.app = Zwift();
        rig.ride(600);
        expect(rig.fitSaves, isEmpty);
        expect(rig.prefs.rideDetected, isTrue);
        expect(rig.service.pendingRide.value, isNull);
        expect(rig.service.showsPrompt, isTrue);
      });
    });

    test('not Pro: detected and prompted (the UI shows the paywall on accept)', () {
      run((rig) {
        rig.pro = false;
        rig.ride(600);
        expect(rig.fitSaves, isEmpty);
        expect(rig.service.showsPrompt, isTrue);
      });
    });

    test('no prompt before any ride, nor after a short spin', () {
      run((rig) {
        expect(rig.service.showsPrompt, isFalse);
        rig.ride(60);
        expect(rig.service.showsPrompt, isFalse);
      });
    });
  });

  group('platform', () {
    test('unsupported: no recording, no prompt, toggle hidden', () {
      run((rig) {
        rig.platform = false;
        rig.ride(600);
        expect(rig.fitSaves, isEmpty);
        expect(rig.service.isSupported, isFalse);
        expect(rig.service.showsPrompt, isFalse);
      });
    });

    test('Health unavailable on the device counts as unsupported', () {
      fakeAsync((async) {
        final rig = _Rig(async, prefs);
        rig.channel.available = false;
        rig.boot();
        async.flushMicrotasks();
        expect(rig.service.isSupported, isFalse);
        rig.ride(600);
        expect(rig.fitSaves, isEmpty);
        rig.dispose();
      });
    });
  });

  group('setEnabled', () {
    test('on authorizes first, then stores the choice', () {
      run((rig) {
        late bool result;
        rig.service.setEnabled(true).then((v) => result = v);
        rig.async.flushMicrotasks();
        expect(result, isTrue);
        expect(rig.channel.authorizeCalls, 1);
        expect(rig.prefs.explicitChoice, isTrue);
        expect(rig.service.isEnabled, isTrue);
      });
    });

    test('on with Health denied stays off and reports', () {
      run((rig) {
        rig.app = Zwift();
        rig.channel.authorization = HealthKitAuthorization.denied;
        late bool result;
        rig.service.setEnabled(true).then((v) => result = v);
        rig.async.flushMicrotasks();
        expect(result, isFalse);
        expect(rig.prefs.explicitChoice, isNull);
        expect(rig.feedback.failures, [true]);
      });
    });

    test('an authorize error is recorded and reported', () {
      run((rig) {
        rig.channel.authorizeError = PlatformException(code: 'authorize', message: 'x');
        late bool result;
        rig.service.setEnabled(true).then((v) => result = v);
        rig.async.flushMicrotasks();
        expect(result, isFalse);
        expect(rig.errors, hasLength(1));
        expect(rig.feedback.failures, [false]);
      });
    });

    test('off needs no authorization', () {
      run((rig) {
        rig.service.setEnabled(false);
        rig.async.flushMicrotasks();
        expect(rig.channel.authorizeCalls, 0);
        expect(rig.prefs.explicitChoice, isFalse);
        expect(rig.service.isEnabled, isFalse);
      });
    });
  });

  test('finishNow writes the running auto ride; discard drops it', () {
    run((rig) {
      rig.prefs.setExplicitChoice(true);
      rig.trainer.cadence.value = 90;
      rig.async.elapse(const Duration(minutes: 6));
      expect(rig.service.isAutoRecording.value, isTrue);
      rig.service.finishNow();
      rig.async.flushMicrotasks();
      expect(rig.channel.saved, hasLength(1));

      rig.trainer.cadence.value = 0;
      rig.async.elapse(const Duration(seconds: 2));
      rig.trainer.cadence.value = 90;
      rig.async.elapse(const Duration(minutes: 6));
      expect(rig.service.isAutoRecording.value, isTrue);
      rig.service.discard();
      rig.async.flushMicrotasks();
      expect(rig.channel.saved, hasLength(1));
      expect(rig.fitSaves, hasLength(1));
      expect(rig.recorder.state.value, WorkoutState.idle);
    });
  });

  group('stopRide (the workout card Stop button)', () {
    test('a hand-started ride is stopped, returned and written to Health', () {
      run((rig) {
        rig.prefs.setExplicitChoice(true);
        rig.recorder.start(rig.trainer.metrics);
        rig.trainer.cadence.value = 90;
        rig.async.elapse(const Duration(minutes: 6));
        final result = rig.service.stopRide();
        rig.async.flushMicrotasks();
        expect(result.activeDuration, greaterThanOrEqualTo(const Duration(minutes: 5)));
        expect(rig.recorder.state.value, WorkoutState.idle);
        expect(rig.channel.saved, hasLength(1));
        // The card saves its own FIT.
        expect(rig.fitSaves, isEmpty);
      });
    });

    test('an auto ride is written once and does not restart while still pedalling', () {
      run((rig) {
        rig.prefs.setExplicitChoice(true);
        rig.trainer.cadence.value = 90;
        rig.async.elapse(const Duration(minutes: 6));
        expect(rig.service.isAutoRecording.value, isTrue);
        rig.service.stopRide();
        rig.async.elapse(const Duration(seconds: 5));
        expect(rig.service.isAutoRecording.value, isFalse);
        expect(rig.recorder.state.value, WorkoutState.idle);
        expect(rig.channel.saved, hasLength(1));
        expect(rig.fitSaves, isEmpty);
      });
    });

    test('undecided: an auto ride stopped by hand is held for the prompt', () {
      run((rig) {
        rig.trainer.cadence.value = 90;
        rig.async.elapse(const Duration(minutes: 6));
        expect(rig.service.isAutoRecording.value, isTrue);
        rig.service.stopRide();
        rig.async.flushMicrotasks();
        expect(rig.channel.saved, isEmpty);
        expect(rig.service.pendingRide.value, isNotNull);
        expect(rig.service.showsPrompt, isTrue);
      });
    });
  });

  test('payload sanity: what reaches the channel is the ride', () {
    run((rig) {
      rig.prefs.setExplicitChoice(true);
      rig.ride(600);
      final HealthWorkoutPayload p = rig.channel.saved.single;
      expect(p.start, _Rig.base.add(const Duration(seconds: 1)));
    });
  });

  test('a custom minRide is honoured: a 30 s ride is written, a 15 s one is skipped', () {
    fakeAsync((async) {
      final rig = _Rig(async, prefs, minRide: const Duration(seconds: 20));
      rig.boot();
      async.flushMicrotasks();
      rig.prefs.setExplicitChoice(true);

      rig.ride(15);
      expect(rig.fitSaves, isEmpty);
      expect(rig.channel.saved, isEmpty);

      rig.ride(30);
      expect(rig.fitSaves, hasLength(1));
      expect(rig.channel.saved, hasLength(1));

      rig.dispose();
    });
  });
}
