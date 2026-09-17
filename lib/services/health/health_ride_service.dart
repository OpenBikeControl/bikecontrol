import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../../utils/keymap/apps/supported_app.dart';
import '../../utils/requirements/multi.dart';
import '../sensors/health_kit_channel.dart';
import '../workout/trainer_metrics.dart';
import '../workout/workout_recorder.dart';
import 'auto_ride_controller.dart';
import 'health_ride_preferences.dart';
import 'health_workout_channel.dart';
import 'health_workout_payload.dart';

/// What the rider is told after a ride was written.
class HealthRideSaved {
  final Duration activeDuration;
  final int avgPowerW;
  final double energyKcal;
  const HealthRideSaved({required this.activeDuration, required this.avgPowerW, required this.energyKcal});
}

/// The user-facing side of saving (toasts). Kept behind an interface so the
/// service stays testable without a widget tree.
abstract class HealthRideFeedback {
  void onSaved(HealthRideSaved ride);

  /// [denied]: Health refused access — the rider can fix that in Health.
  void onFailed({required bool denied});
}

/// "Save rides to Apple Health": decides when rides are recorded on their
/// own, and writes finished rides (automatic or manual) to Health.
///
/// A ride is written only once the rider has said yes — via the toggle or the
/// home prompt, both of which ask Health for access first. Until then the
/// per-app default still decides whether rides are recorded, and a finished
/// ride is held in [pendingRide] for the prompt to offer.
class HealthRideService {
  HealthRideService({
    required this.recorder,
    required this.prefs,
    required this.channel,
    required this.feedback,
    required this.isPlatformSupported,
    required this.isPro,
    required this.trainerApp,
    required this.target,
    required TrainerMetrics? Function() connectedTrainer,
    required this.saveFit,
    required this.onError,
    DateTime Function()? now,
    String Function()? newSyncId,
    this.minRide = defaultMinRide,
  }) : _newSyncId = newSyncId ?? newRideSyncId {
    _controller = AutoRideController(
      recorder: recorder,
      connectedTrainer: connectedTrainer,
      shouldRecord: () => isEnabled,
      shouldDetect: () => isSupported && _undecided && !prefs.rideDetected,
      onRideFinished: (result) => unawaited(_onAutoRideFinished(result)),
      onRideDetected: _onRideDetected,
      now: now,
      minRide: minRide,
    );
  }

  /// A shorter spin is not a ride — for detection and for saving alike.
  static const defaultMinRide = AutoRideController.defaultMinRide;

  /// Injectable so debug builds can shorten it; production and tests keep
  /// [defaultMinRide].
  final Duration minRide;

  final WorkoutRecorder recorder;
  final HealthRidePreferences prefs;
  final HealthWorkoutChannel channel;
  final HealthRideFeedback feedback;
  final bool Function() isPlatformSupported;
  final bool Function() isPro;
  final SupportedApp? Function() trainerApp;
  final Target? Function() target;

  /// Persists an automatic ride's FIT file, exactly like a manual stop does.
  final Future<void> Function(WorkoutResult result) saveFit;

  final void Function(Object error, StackTrace stack, String context) onError;

  final String Function() _newSyncId;
  late final AutoRideController _controller;
  bool _healthAvailable = false;

  final ValueNotifier<WorkoutResult?> _pendingRide = ValueNotifier(null);

  /// An automatic ride that finished while the rider had not decided yet.
  ValueListenable<WorkoutResult?> get pendingRide => _pendingRide;

  ValueListenable<bool> get isAutoRecording => _controller.isAutoRecording;

  /// Everything the toggle, prompt and chip depend on.
  late final Listenable changes = Listenable.merge([prefs, _pendingRide, _controller.isAutoRecording]);

  /// iOS/iPadOS with Health on the device. Everything is hidden otherwise.
  bool get isSupported => _healthAvailable && isPlatformSupported();

  bool get _undecided => prefs.explicitChoice == null && !prefs.promptDismissed;

  /// Whether the toggle reads on — and whether rides are recorded on their own.
  bool get isEnabled => resolveSaveRidesToHealth(
    platformSupported: isSupported,
    isPro: isPro(),
    explicitChoice: prefs.explicitChoice,
    trainerApp: trainerApp(),
    target: target(),
  );

  bool get _writes => isEnabled && prefs.explicitChoice == true;

  bool get showsPrompt => isSupported && _undecided && (prefs.rideDetected || _pendingRide.value != null);

  /// The selected trainer app may write the ride to Health itself.
  bool get showsDuplicateHint => isSupported && mayAlreadySaveToHealth(trainerApp());

  Future<void> start() async {
    if (!isPlatformSupported()) return;
    try {
      _healthAvailable = await channel.isAvailable();
    } catch (e, s) {
      onError(e, s, 'HealthRideService.isAvailable');
      return;
    }
    if (_healthAvailable) _controller.start();
  }

  void dispose() {
    _controller.dispose();
    _pendingRide.dispose();
  }

  /// The toggle. Turning on asks Health for access first (the caller has
  /// already made sure of Pro); returns the resulting state.
  Future<bool> setEnabled(bool enabled) async {
    if (!enabled) {
      await prefs.setExplicitChoice(false);
      _pendingRide.value = null;
      return false;
    }
    if (!await _authorize()) return false;
    await prefs.setExplicitChoice(true);
    return isEnabled;
  }

  /// "Save this ride to Apple Health?" → yes (the caller checked Pro).
  Future<void> acceptPrompt() async {
    if (!await _authorize()) return;
    await prefs.setExplicitChoice(true);
    final pending = _pendingRide.value;
    _pendingRide.value = null;
    if (pending != null) await _write(pending);
  }

  /// "Save this ride to Apple Health?" → no, and don't ask again.
  Future<void> dismissPrompt() async {
    _pendingRide.value = null;
    await prefs.setPromptDismissed();
    await prefs.setExplicitChoice(false);
  }

  void finishNow() => _controller.finishNow();

  void discard() => _controller.discard();

  /// A ride stopped from the workout card; its FIT is already saved.
  Future<void> onManualRideFinished(WorkoutResult result) async {
    if (result.activeDuration >= minRide) _onRideDetected();
    if (_writes) await _write(result);
  }

  Future<void> openHealthSettings() async {
    try {
      await channel.openHealthSettings();
    } catch (e, s) {
      onError(e, s, 'HealthRideService.openHealthSettings');
    }
  }

  void _onRideDetected() {
    if (prefs.explicitChoice == null && !prefs.rideDetected) unawaited(prefs.setRideDetected());
  }

  Future<void> _onAutoRideFinished(WorkoutResult result) async {
    // Too short to be a ride: not worth a FIT file or a Health workout.
    if (result.activeDuration < minRide) return;
    try {
      await saveFit(result);
    } catch (e, s) {
      onError(e, s, 'HealthRideService.saveFit');
    }
    if (_writes) {
      await _write(result);
    } else if (_undecided) {
      _pendingRide.value = result;
    }
  }

  Future<bool> _authorize() async {
    try {
      final verdict = await channel.authorize();
      if (verdict == HealthKitAuthorization.denied) {
        feedback.onFailed(denied: true);
        return false;
      }
      // `unknown` proceeds: Health does not always tell, and a real refusal
      // surfaces on the write.
      return true;
    } catch (e, s) {
      onError(e, s, 'HealthRideService.authorize');
      feedback.onFailed(denied: false);
      return false;
    }
  }

  Future<void> _write(WorkoutResult result) async {
    final payload = HealthWorkoutPayload.fromResult(result, syncId: _newSyncId(), minActiveDuration: minRide);
    if (payload == null) return;
    try {
      await channel.saveWorkout(payload);
      feedback.onSaved(
        HealthRideSaved(
          activeDuration: result.activeDuration,
          avgPowerW: result.summary.avgPowerW,
          energyKcal: payload.totalEnergyKcal,
        ),
      );
    } catch (e, s) {
      onError(e, s, 'HealthRideService.saveWorkout');
      feedback.onFailed(denied: e is PlatformException && e.code == 'denied');
    }
  }
}
