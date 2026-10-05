import 'package:bike_control/services/health/fake_health_workout_channel.dart';
import 'package:bike_control/services/health/health_workout_channel.dart';
import 'package:bike_control/services/rides/ride_preferences.dart';
import 'package:bike_control/services/rides/ride_service.dart';
import 'package:bike_control/services/sensors/health_kit_channel.dart';
import 'package:bike_control/services/workout/memory_workout_repository.dart';
import 'package:bike_control/services/workout/past_workout.dart';
import 'package:bike_control/services/workout/trainer_metrics.dart';
import 'package:bike_control/services/workout/workout_recorder.dart';
import 'package:bike_control/utils/keymap/apps/my_whoosh.dart';
import 'package:bike_control/utils/keymap/apps/rouvy.dart';
import 'package:bike_control/utils/keymap/apps/supported_app.dart';
import 'package:bike_control/utils/keymap/apps/zwift.dart';
import 'package:bike_control/utils/requirements/multi.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Feedback implements RideFeedback {
  int tooShort = 0;
  final saved = <HealthStore>[];
  final failed = <bool>[];
  final notified = <PastWorkout>[];

  @override
  void onTooShort() => tooShort++;

  @override
  void onHealthSaved(HealthStore store) => saved.add(store);

  @override
  void onHealthFailed(HealthStore store, {required bool denied}) => failed.add(denied);

  @override
  Future<void> onRideFinishedInBackground(PastWorkout ride) async => notified.add(ride);
}

class _Trainer {
  final power = ValueNotifier<int?>(null);
  final cadence = ValueNotifier<int?>(null);
  final speed = ValueNotifier<double?>(null);
  final gear = ValueNotifier<int>(12);
  late final metrics = TrainerMetrics(
    powerW: power,
    cadenceRpm: cadence,
    speedKph: speed,
    heartRateBpm: ValueNotifier<int?>(null),
    gear: gear,
    sourceName: 'KICKR CORE',
  );
}

class _Rig {
  _Rig(
    this.async,
    this.prefs, {
    MemoryWorkoutRepository? repository,
    HealthWorkoutChannel? health,
    this.noHealth = false,
  }) : repository = repository ?? MemoryWorkoutRepository(),
       channel = health ?? FakeHealthWorkoutChannel() {
    recorder = WorkoutRecorder(nowProvider: now);
    service = RideService(
      recorder: recorder,
      prefs: prefs,
      repository: this.repository,
      source: () => connected ? trainer.metrics : null,
      health: noHealth ? null : channel,
      feedback: feedback,
      trainerName: () => trainer.metrics.sourceName,
      appName: () => app?.name,
      trainerApp: () => app,
      target: () => target,
      isForeground: () => foreground,
      onError: (e, s, context) => errors.add('$context: $e'),
      now: now,
      newSyncId: () => 'sync-${++syncIds}',
    );
  }

  final FakeAsync async;
  final RidePreferences prefs;
  final MemoryWorkoutRepository repository;
  final HealthWorkoutChannel channel;
  FakeHealthWorkoutChannel get fake => channel as FakeHealthWorkoutChannel;
  final bool noHealth;
  final feedback = _Feedback();
  final trainer = _Trainer();
  final errors = <String>[];
  late final WorkoutRecorder recorder;
  late final RideService service;
  bool connected = true;
  bool foreground = true;
  SupportedApp? app = MyWhoosh();
  Target? target = Target.thisDevice;
  int syncIds = 0;

  static final base = DateTime.utc(2026, 10, 5, 15, 56);
  DateTime now() => base.add(async.elapsed);

  void boot() {
    service.start();
    async.flushMicrotasks();
  }

  /// Pedal for [seconds], then stop and wait out the automatic end.
  void ride(int seconds, {int watts = 200}) {
    trainer.cadence.value = 90;
    trainer.power.value = watts;
    trainer.speed.value = 36;
    async.elapse(Duration(seconds: seconds));
    trainer.gear.value = 13;
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

void main() {
  late RidePreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = RidePreferences(await SharedPreferences.getInstance());
  });

  test('an automatic ride is saved with its summary and shows on the card', () {
    fakeAsync((async) {
      final rig = _Rig(async, prefs)..boot();
      rig.ride(600);
      final ride = rig.service.summaryRide.value!;
      expect(rig.repository.saves, 1);
      final s = ride.summary!;
      // Recording starts on the first tick that sees pedalling.
      expect(s.activeDuration, const Duration(seconds: 599));
      expect(s.trainerName, 'KICKR CORE');
      expect(s.appName, 'MyWhoosh');
      expect(s.autoStarted, isTrue);
      expect(s.gearChanges, 1);
      expect(s.hasSpeed, isTrue);
      expect(prefs.summaryRide, ride.fileName);
      expect(rig.errors, isEmpty);
      rig.dispose();
    });
  });

  test('the summary card survives a restart', () {
    fakeAsync((async) {
      final repo = MemoryWorkoutRepository();
      final first = _Rig(async, prefs, repository: repo)..boot();
      first.ride(600);
      final name = first.service.summaryRide.value!.fileName;
      first.dispose();

      final second = _Rig(async, prefs, repository: repo)..boot();
      expect(second.service.summaryRide.value?.fileName, name);
      second.dispose();
    });
  });

  test('the card stays until dismissed', () {
    fakeAsync((async) {
      final rig = _Rig(async, prefs)..boot();
      rig.ride(600);
      rig.service.dismissSummary();
      async.flushMicrotasks();
      expect(rig.service.summaryRide.value, isNull);
      expect(prefs.summaryRide, isNull);
      rig.dispose();
    });
  });

  test('the next ride starting replaces the card', () {
    fakeAsync((async) {
      final rig = _Rig(async, prefs)..boot();
      rig.ride(600);
      expect(rig.service.summaryRide.value, isNotNull);
      rig.trainer.cadence.value = 90;
      async.elapse(const Duration(seconds: 2));
      async.flushMicrotasks();
      expect(rig.recorder.state.value, WorkoutState.recording);
      expect(rig.service.summaryRide.value, isNull);
      rig.dispose();
    });
  });

  test('a spin-up (under 2 min and 10 kJ) is dropped silently', () {
    fakeAsync((async) {
      final rig = _Rig(async, prefs)..boot();
      rig.ride(60, watts: 100); // 60 s, 6 kJ
      expect(rig.repository.saves, 0);
      expect(rig.service.summaryRide.value, isNull);
      expect(rig.feedback.tooShort, 0);
      rig.dispose();
    });
  });

  test('a short but hard effort is kept', () {
    fakeAsync((async) {
      final rig = _Rig(async, prefs)..boot();
      rig.ride(100, watts: 150); // 15 kJ
      expect(rig.repository.saves, 1);
      rig.dispose();
    });
  });

  test('Beenden on a spin-up says why nothing was kept', () {
    fakeAsync((async) {
      final rig = _Rig(async, prefs)..boot();
      rig.trainer.cadence.value = 90;
      rig.trainer.power.value = 100;
      async.elapse(const Duration(seconds: 30));
      rig.service.finish();
      async.flushMicrotasks();
      expect(rig.feedback.tooShort, 1);
      expect(rig.repository.saves, 0);
      rig.dispose();
    });
  });

  test('Verwerfen saves nothing', () {
    fakeAsync((async) {
      final rig = _Rig(async, prefs)..boot();
      rig.trainer.cadence.value = 90;
      rig.trainer.power.value = 250;
      async.elapse(const Duration(minutes: 10));
      rig.service.discard();
      async.flushMicrotasks();
      expect(rig.recorder.state.value, WorkoutState.idle);
      expect(rig.repository.saves, 0);
      rig.dispose();
    });
  });

  group('automatic recording off', () {
    test('pedalling records nothing', () {
      fakeAsync((async) {
        prefs.setAutoRecord(false);
        final rig = _Rig(async, prefs)..boot();
        rig.ride(600);
        expect(rig.repository.saves, 0);
        rig.dispose();
      });
    });

    test('a manual start runs the same flow to the same summary', () {
      fakeAsync((async) {
        prefs.setAutoRecord(false);
        final rig = _Rig(async, prefs)..boot();
        expect(rig.service.canStartManually, isTrue);
        expect(rig.service.startManual(), isTrue);
        rig.trainer.cadence.value = 90;
        rig.trainer.power.value = 200;
        async.elapse(const Duration(minutes: 10));
        rig.service.finish();
        async.flushMicrotasks();
        final s = rig.service.summaryRide.value!.summary!;
        expect(s.autoStarted, isFalse);
        expect(s.activeDuration.inMinutes, 10);
        rig.dispose();
      });
    });

    test('without a source there is nothing to start', () {
      fakeAsync((async) {
        prefs.setAutoRecord(false);
        final rig = _Rig(async, prefs)..boot();
        rig.connected = false;
        expect(rig.service.canStartManually, isFalse);
        expect(rig.service.startManual(), isFalse);
        rig.dispose();
      });
    });
  });

  group('Health', () {
    test('asked once, on the first ride; Ja writes it and every later ride, with no Pro anywhere', () {
      fakeAsync((async) {
        final rig = _Rig(async, prefs)..boot();
        expect(rig.service.asksHealthQuestion, isTrue);
        rig.ride(600);
        expect(rig.fake.saved, isEmpty, reason: 'nothing written before the answer');

        rig.service.answerHealthQuestion(yes: true);
        async.flushMicrotasks();
        expect(rig.fake.saved, hasLength(1));
        expect(rig.service.asksHealthQuestion, isFalse);
        expect(rig.service.summaryRide.value!.summary!.savedToHealth, isTrue);

        rig.ride(600);
        expect(rig.fake.saved, hasLength(2));
        rig.dispose();
      });
    });

    test('Nein closes the question for good and writes nothing', () {
      fakeAsync((async) {
        final rig = _Rig(async, prefs)..boot();
        rig.ride(600);
        rig.service.answerHealthQuestion(yes: false);
        async.flushMicrotasks();
        expect(rig.service.asksHealthQuestion, isFalse);
        expect(prefs.saveToHealth, isFalse);
        rig.ride(600);
        expect(rig.fake.saved, isEmpty);
        rig.dispose();
      });
    });

    test('Nein is the default when Zwift or Rouvy run on this device', () {
      fakeAsync((async) {
        final rig = _Rig(async, prefs)..boot();
        rig.app = Zwift();
        expect(rig.service.healthQuestionDefaultsToNo, isTrue);
        rig.app = Rouvy();
        expect(rig.service.healthQuestionDefaultsToNo, isTrue);
        rig.target = Target.otherDevice;
        expect(rig.service.healthQuestionDefaultsToNo, isFalse);
        rig.app = MyWhoosh();
        rig.target = Target.thisDevice;
        expect(rig.service.healthQuestionDefaultsToNo, isFalse);
        rig.dispose();
      });
    });

    test('a refused permission keeps the question and the setting off', () {
      fakeAsync((async) {
        final rig = _Rig(async, prefs)..boot();
        rig.fake.authorization = HealthKitAuthorization.denied;
        rig.ride(600);
        rig.service.answerHealthQuestion(yes: true);
        async.flushMicrotasks();
        expect(rig.feedback.failed, [true]);
        expect(prefs.saveToHealth, isNull);
        expect(rig.fake.saved, isEmpty);
        rig.dispose();
      });
    });

    test('exporting a ride twice writes it once', () {
      fakeAsync((async) {
        final rig = _Rig(async, prefs)..boot();
        rig.ride(600);
        var ride = rig.service.summaryRide.value!;
        rig.service.exportToHealth(ride).then((r) => ride = r);
        async.flushMicrotasks();
        rig.service.exportToHealth(ride);
        async.flushMicrotasks();
        expect(rig.fake.saved, hasLength(1));
        expect(rig.feedback.saved, [HealthStore.appleHealth]);
        // Read back from the .fit: the whole ride, not just its averages.
        expect(rig.fake.saved.single.power.values, hasLength(599));
        rig.dispose();
      });
    });

    test('a failed write keeps its sync id so the retry replaces', () {
      fakeAsync((async) {
        final rig = _Rig(async, prefs)..boot();
        rig.ride(600);
        rig.fake.saveError = Exception('boom');
        var ride = rig.service.summaryRide.value!;
        rig.service.exportToHealth(ride).then((r) => ride = r);
        async.flushMicrotasks();
        expect(ride.summary!.healthSyncId, 'sync-1');
        rig.fake.saveError = null;
        rig.service.exportToHealth(ride);
        async.flushMicrotasks();
        expect(rig.fake.saved.single.syncId, 'sync-1');
        rig.dispose();
      });
    });

    test('Health Connect not installed: no question, but the store is known', () {
      fakeAsync((async) {
        final hc = FakeHealthWorkoutChannel(store: HealthStore.healthConnect)..status = HealthAvailability.notInstalled;
        final rig = _Rig(async, prefs, health: hc)..boot();
        expect(rig.service.healthStore, HealthStore.healthConnect);
        expect(rig.service.healthReady, isFalse);
        expect(rig.service.asksHealthQuestion, isFalse);
        rig.service.installHealth();
        async.flushMicrotasks();
        expect(hc.openInstallCalls, 1);
        rig.dispose();
      });
    });

    test('no store on desktop: no question, rides still recorded', () {
      fakeAsync((async) {
        final rig = _Rig(async, prefs, noHealth: true)..boot();
        expect(rig.service.healthStore, isNull);
        expect(rig.service.asksHealthQuestion, isFalse);
        rig.ride(600);
        expect(rig.repository.saves, 1);
        rig.dispose();
      });
    });
  });

  group('notification', () {
    test('a ride that ends in the background is pushed', () {
      fakeAsync((async) {
        final rig = _Rig(async, prefs)..boot();
        rig.foreground = false;
        rig.ride(600);
        expect(rig.feedback.notified.single.fileName, rig.service.summaryRide.value!.fileName);
        rig.dispose();
      });
    });

    test('not while the app is on screen', () {
      fakeAsync((async) {
        final rig = _Rig(async, prefs)..boot();
        rig.ride(600);
        expect(rig.feedback.notified, isEmpty);
        rig.dispose();
      });
    });
  });

  group('history', () {
    test('delete and delete all; deleting the card ride hides the card', () {
      fakeAsync((async) {
        final rig = _Rig(async, prefs)..boot();
        rig.ride(600);
        rig.ride(600);
        late List<PastWorkout> rides;
        rig.service.list().then((r) => rides = r);
        async.flushMicrotasks();
        expect(rides, hasLength(2));
        rig.service.delete(rides.first);
        async.flushMicrotasks();
        expect(rig.service.summaryRide.value, isNull);
        rig.service.deleteAll();
        async.flushMicrotasks();
        rig.service.list().then((r) => rides = r);
        async.flushMicrotasks();
        expect(rides, isEmpty);
        rig.dispose();
      });
    });

    test('sharing the .fit marks it', () {
      fakeAsync((async) {
        final rig = _Rig(async, prefs)..boot();
        rig.ride(600);
        rig.service.markFitExported(rig.service.summaryRide.value!);
        async.flushMicrotasks();
        expect(rig.service.summaryRide.value!.summary!.fitExported, isTrue);
        rig.dispose();
      });
    });
  });
}
