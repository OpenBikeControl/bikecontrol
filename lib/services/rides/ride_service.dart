import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../../utils/keymap/apps/supported_app.dart';
import '../../utils/requirements/multi.dart';
import '../health/health_workout_channel.dart';
import '../health/health_workout_payload.dart';
import '../sensors/health_kit_channel.dart';
import '../workout/fit_reader.dart';
import '../workout/fit_writer.dart';
import '../workout/past_workout.dart';
import '../workout/trainer_metrics.dart';
import '../workout/workout_recorder.dart';
import '../workout/workout_repository.dart';
import '../workout/workout_summary.dart';
import 'ride_detector.dart';
import 'ride_preferences.dart';

void _noopLog(String message) {}

/// The user-facing side effects of rides (toasts, the push), behind an
/// interface so the service stays testable without a widget tree.
abstract class RideFeedback {
  /// The rider pressed Beenden on a ride too short to keep.
  void onTooShort();

  /// A ride the rider sent to Health by hand (or with "Ja") arrived.
  void onHealthSaved(HealthStore store);

  /// [denied]: the store refused access; the rider can fix that there.
  void onHealthFailed(HealthStore store, {required bool denied});

  /// A ride ended while BikeControl was in the background.
  Future<void> onRideFinishedInBackground(PastWorkout ride);
}

/// Every ride, from the first pedal stroke to its place in the history:
/// records it (automatically or by hand, through one [RideDetector]),
/// drops spin-ups, saves the `.fit` with its summary, keeps the summary card
/// on Ride, sends it to Apple Health / Health Connect once the rider said
/// yes, and pushes a notification when the ride ended in the background.
///
/// Nothing here depends on Pro.
class RideService {
  RideService({
    required this.recorder,
    required this.prefs,
    required this.repository,
    required this.source,
    required this.health,
    required this.feedback,
    required this.trainerName,
    required this.appName,
    required this.trainerApp,
    required this.target,
    required this.isForeground,
    required this.onError,
    DateTime Function()? now,
    String Function()? newSyncId,
    this.log = _noopLog,
  }) : _newSyncId = newSyncId ?? newRideSyncId {
    detector = RideDetector(
      recorder: recorder,
      source: source,
      autoRecord: () => prefs.autoRecord,
      onRideFinished: (result, reason) => unawaited(_onRideFinished(result, reason)),
      now: now,
      log: log,
    );
    recorder.state.addListener(_onRecorderState);
  }

  final WorkoutRecorder recorder;
  final RidePreferences prefs;

  /// Not final: tests and captures swap in an in-memory one.
  WorkoutRepository repository;

  /// What BikeControl receives power / cadence from right now.
  final TrainerMetrics? Function() source;

  /// Null where there is no Health store (desktop).
  final HealthWorkoutChannel? health;
  final RideFeedback feedback;

  /// The trainer (or sensor) and the trainer app, for the summary header.
  final String? Function() trainerName;
  final String? Function() appName;
  final SupportedApp? Function() trainerApp;
  final Target? Function() target;

  /// Whether the app is on screen; a ride that ends otherwise is pushed.
  final bool Function() isForeground;
  final void Function(Object error, StackTrace stack, String context) onError;
  final void Function(String message) log;
  final String Function() _newSyncId;

  late final RideDetector detector;

  final ValueNotifier<PastWorkout?> _summaryRide = ValueNotifier(null);
  final ValueNotifier<HealthAvailability> _healthAvailability = ValueNotifier(HealthAvailability.unsupported);
  final ValueNotifier<int> _ridesVersion = ValueNotifier(0);
  var _lastState = WorkoutState.idle;

  /// The source's name when the ride started: by the time an automatic
  /// ride ends the trainer may be long gone.
  String? _rideSourceName;

  /// The ride the summary card shows, until dismissed or the next ride.
  ValueListenable<PastWorkout?> get summaryRide => _summaryRide;

  /// Bumped whenever the saved rides change (a ride saved, exported or
  /// deleted), for the history to reload.
  ValueListenable<int> get ridesVersion => _ridesVersion;

  ValueListenable<HealthAvailability> get healthAvailability => _healthAvailability;

  /// Everything the Ride tab, Settings and the history depend on.
  late final Listenable changes = Listenable.merge([
    prefs,
    _summaryRide,
    _healthAvailability,
    _ridesVersion,
    recorder.state,
    detector.startedAutomatically,
  ]);

  /// [detect] off leaves the 1 Hz detection timer stopped (widget tests).
  Future<void> start({bool detect = true}) async {
    try {
      final name = prefs.summaryRide;
      if (name != null) _summaryRide.value = await repository.find(name);
    } catch (e, s) {
      onError(e, s, 'RideService.loadSummary');
    }
    final channel = health;
    if (channel != null) {
      try {
        _healthAvailability.value = await channel.availability();
      } catch (e, s) {
        onError(e, s, 'RideService.healthAvailability');
      }
    }
    log('start: autoRecord=${prefs.autoRecord} health=${health?.store.name}:${_healthAvailability.value.name}');
    if (detect) detector.start();
  }

  void dispose() {
    recorder.state.removeListener(_onRecorderState);
    detector.dispose();
    _summaryRide.dispose();
    _healthAvailability.dispose();
    _ridesVersion.dispose();
  }

  // ── Recording ─────────────────────────────────────────────────────────

  bool get autoRecord => prefs.autoRecord;

  Future<void> setAutoRecord(bool enabled) => prefs.setAutoRecord(enabled);

  /// Whether a manual start has anything to record from.
  bool get canStartManually => source() != null;

  bool startManual() => detector.startManual();

  /// Beenden: ends the ride; the summary card follows at once.
  void finish() => detector.finish();

  /// Verwerfen: the running ride is thrown away, nowhere saved.
  void discard() => detector.discard();

  void _onRecorderState() {
    final state = recorder.state.value;
    if (_lastState == WorkoutState.idle && state != WorkoutState.idle) {
      _rideSourceName = trainerName();
      // A new ride replaces the last one's summary card.
      if (_summaryRide.value != null) unawaited(dismissSummary());
    }
    _lastState = state;
  }

  Future<void> _onRideFinished(WorkoutResult result, RideEndReason reason) async {
    if (RideDetector.isTooShort(result)) {
      log(
        'ride dropped: too short, moving=${result.activeDuration} work=${result.summary.workKj.toStringAsFixed(1)} kJ',
      );
      if (reason == RideEndReason.finished) feedback.onTooShort();
      return;
    }
    final PastWorkout ride;
    try {
      ride = await _save(result);
    } catch (e, s) {
      onError(e, s, 'RideService.save');
      return;
    }
    _summaryRide.value = ride;
    await prefs.setSummaryRide(ride.fileName);
    _ridesVersion.value++;
    log('ride saved: ${ride.fileName} reason=${reason.name}');

    if (savesToHealth) await _writeToHealth(ride, result, announce: false);

    if (!isForeground()) {
      try {
        await feedback.onRideFinishedInBackground(_summaryRide.value ?? ride);
      } catch (e, s) {
        onError(e, s, 'RideService.notify');
      }
    }
  }

  Future<PastWorkout> _save(WorkoutResult result) async {
    final summary = WorkoutSummary.fromSamples(
      result.samples,
      startedAt: result.startedAt,
      activeDuration: result.activeDuration,
      endedAt: result.endedAt,
      pauses: result.pauses,
      gearChanges: result.gearChanges,
      trainerName: _rideSourceName ?? trainerName(),
      appName: appName(),
      autoStarted: result.summary.autoStarted || detector.lastRideWasAutomatic,
    );
    final bytes = FitFileWriter.encode(
      samples: result.samples,
      summary: summary,
      pauses: result.pauses,
      endedAt: result.endedAt,
    );
    final file = await repository.save(startedAt: result.startedAt, fitBytes: bytes, summary: summary);
    return PastWorkout(file: file, startedAt: result.startedAt.toUtc(), sizeBytes: bytes.length, summary: summary);
  }

  /// Hides the summary card.
  Future<void> dismissSummary() async {
    _summaryRide.value = null;
    await prefs.setSummaryRide(null);
  }

  // ── History ───────────────────────────────────────────────────────────

  Future<List<PastWorkout>> list() => repository.list();

  /// Removes the ride and its .fit from this device. What is already in
  /// Health stays there.
  Future<void> delete(PastWorkout ride) async {
    await repository.delete(ride.file);
    if (_summaryRide.value?.fileName == ride.fileName) await dismissSummary();
    _ridesVersion.value++;
  }

  Future<void> deleteAll() async {
    await repository.deleteAll();
    await dismissSummary();
    _ridesVersion.value++;
  }

  /// The .fit was shared or saved: the history shows a badge for it.
  Future<PastWorkout> markFitExported(PastWorkout ride) async {
    final summary = ride.summary;
    if (summary == null || summary.fitExported) return ride;
    return _replace(ride, summary.copyWith(fitExported: true));
  }

  Future<PastWorkout> _replace(PastWorkout ride, WorkoutSummary summary) async {
    final updated = await repository.update(ride, summary);
    if (_summaryRide.value?.fileName == ride.fileName) _summaryRide.value = updated;
    _ridesVersion.value++;
    return updated;
  }

  // ── Health ────────────────────────────────────────────────────────────

  /// The store on this device, also while it still needs installing.
  HealthStore? get healthStore => _healthAvailability.value == HealthAvailability.unsupported ? null : health?.store;

  bool get healthReady => _healthAvailability.value == HealthAvailability.available;

  /// Every recorded ride goes to Health on its own.
  bool get savesToHealth => healthReady && prefs.saveToHealth == true;

  /// The one-time question on the first ride's summary card.
  bool get asksHealthQuestion => healthReady && prefs.saveToHealth == null && !prefs.healthQuestionAnswered;

  /// "Nein" is the default when the trainer app on this device may already
  /// write the ride to Health itself.
  bool get healthQuestionDefaultsToNo => healthDefaultsToNo(trainerApp(), target());

  bool get showsDuplicateHint => healthQuestionDefaultsToNo;

  /// The first-ride question. Ja asks the store for access, turns saving on
  /// and writes the summary card's ride; Nein closes the question for good.
  Future<void> answerHealthQuestion({required bool yes}) async {
    if (!yes) {
      await prefs.setHealthQuestionAnswered();
      await prefs.setSaveToHealth(false);
      return;
    }
    if (!await _authorize()) return;
    await prefs.setHealthQuestionAnswered();
    await prefs.setSaveToHealth(true);
    if (_summaryRide.value case final ride?) await exportToHealth(ride);
  }

  /// The Settings toggle. Turning on asks for access first.
  Future<bool> setSavesToHealth(bool enabled) async {
    if (enabled && !await _authorize()) return false;
    await prefs.setHealthQuestionAnswered();
    await prefs.setSaveToHealth(enabled);
    return enabled;
  }

  Future<void> openHealthSettings() async {
    try {
      await health?.openHealthSettings();
    } catch (e, s) {
      onError(e, s, 'RideService.openHealthSettings');
    }
  }

  Future<void> openHealthApp() async {
    try {
      await health?.openHealthApp();
    } catch (e, s) {
      onError(e, s, 'RideService.openHealthApp');
    }
  }

  Future<void> installHealth() async {
    try {
      await health?.openInstall();
    } catch (e, s) {
      onError(e, s, 'RideService.installHealth');
    }
  }

  /// Sends [ride] to Health by hand (Export). A ride already there is not
  /// written twice; its sync id is reused so a retry replaces.
  Future<PastWorkout> exportToHealth(PastWorkout ride) async {
    final summary = ride.summary;
    if (summary == null || summary.savedToHealth || health == null) return ride;
    if (!await _authorize()) return ride;
    final WorkoutResult result;
    try {
      final bytes = await repository.readBytes(ride);
      result = FitFileReader.decode(Uint8List.fromList(bytes), summary: summary);
    } catch (e, s) {
      onError(e, s, 'RideService.readFit');
      feedback.onHealthFailed(health!.store, denied: false);
      return ride;
    }
    return _writeToHealth(ride, result, announce: true);
  }

  Future<PastWorkout> _writeToHealth(PastWorkout ride, WorkoutResult result, {required bool announce}) async {
    final channel = health;
    final summary = ride.summary;
    if (channel == null || summary == null || summary.savedToHealth) return ride;
    final syncId = summary.healthSyncId ?? _newSyncId();
    final payload = HealthWorkoutPayload.fromResult(result, syncId: syncId);
    if (payload == null) return ride;
    try {
      await channel.saveWorkout(payload);
      log('ride written to ${channel.store.name}: $syncId');
      if (announce) feedback.onHealthSaved(channel.store);
      return await _replace(ride, summary.copyWith(savedToHealth: true, healthSyncId: syncId));
    } catch (e, s) {
      onError(e, s, 'RideService.saveWorkout');
      feedback.onHealthFailed(channel.store, denied: e is PlatformException && e.code == 'denied');
      // Keep the id: the retry replaces rather than duplicates.
      if (summary.healthSyncId == null) {
        try {
          return await _replace(ride, summary.copyWith(healthSyncId: syncId));
        } catch (e, s) {
          onError(e, s, 'RideService.keepSyncId');
        }
      }
      return ride;
    }
  }

  Future<bool> _authorize() async {
    final channel = health;
    if (channel == null || !healthReady) return false;
    try {
      final verdict = await channel.authorize();
      log('authorize verdict=$verdict');
      if (verdict == HealthKitAuthorization.denied) {
        feedback.onHealthFailed(channel.store, denied: true);
        return false;
      }
      // `unknown` proceeds: Health does not always tell, and a real refusal
      // surfaces on the write.
      return true;
    } catch (e, s) {
      onError(e, s, 'RideService.authorize');
      feedback.onHealthFailed(channel.store, denied: false);
      return false;
    }
  }
}
