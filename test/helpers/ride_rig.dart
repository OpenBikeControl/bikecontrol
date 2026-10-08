import 'package:bike_control/services/health/fake_health_workout_channel.dart';
import 'package:bike_control/services/health/health_workout_channel.dart';
import 'package:bike_control/services/rides/ride_preferences.dart';
import 'package:bike_control/services/rides/ride_service.dart';
import 'package:bike_control/services/workout/memory_workout_repository.dart';
import 'package:bike_control/services/workout/past_workout.dart';
import 'package:bike_control/services/workout/trainer_metrics.dart';
import 'package:bike_control/services/workout/workout_recorder.dart';
import 'package:bike_control/utils/core.dart';
import 'package:bike_control/utils/keymap/apps/supported_app.dart';
import 'package:bike_control/utils/requirements/multi.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class RecordingRideFeedback implements RideFeedback {
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

/// A [RideService] for widget tests, installed as `core.rides`: in-memory
/// rides and prefs, a fake Health store (null for desktop).
class RideRig {
  RideRig._(this.service, this.repository, this.channel, this.feedback, this.prefs);

  final RideService service;
  final MemoryWorkoutRepository repository;
  final FakeHealthWorkoutChannel? channel;
  final RecordingRideFeedback feedback;
  final RidePreferences prefs;
  static TrainerMetrics? source;
  static SupportedApp? app;
  static Target? target = Target.thisDevice;

  static Future<RideRig> install({
    HealthStore? store = HealthStore.appleHealth,
    HealthAvailability availability = HealthAvailability.available,
    List<PastWorkout> rides = const [],
    Map<String, Object> prefs = const {},
    WorkoutRecorder? recorder,
  }) async {
    SharedPreferences.setMockInitialValues(prefs);
    final ridePrefs = RidePreferences(await SharedPreferences.getInstance());
    final repository = MemoryWorkoutRepository(rides: rides);
    final channel = store == null ? null : (FakeHealthWorkoutChannel(store: store)..status = availability);
    final feedback = RecordingRideFeedback();
    final service = RideService(
      recorder: recorder ?? WorkoutRecorder(),
      prefs: ridePrefs,
      repository: repository,
      source: () => source,
      health: channel,
      feedback: feedback,
      trainerName: () => source?.sourceName,
      appName: () => app?.name,
      trainerApp: () => app,
      target: () => target,
      isForeground: () => true,
      onError: (e, s, context) => throw StateError('$context: $e'),
    );
    await service.start(detect: false);
    // Put the app's own back afterwards, so a later test does not inherit
    // this one's settings. Building it needs core.settings, which only the
    // snapshot harness bootstraps.
    RideService? previous;
    try {
      previous = core.rides;
    } on Error {
      previous = null;
    }
    addTearDown(() {
      if (previous != null) core.rides = previous;
    });
    core.rides = service;
    return RideRig._(service, repository, channel, feedback, ridePrefs);
  }

  static void reset() {
    source = null;
    app = null;
    target = Target.thisDevice;
  }
}
