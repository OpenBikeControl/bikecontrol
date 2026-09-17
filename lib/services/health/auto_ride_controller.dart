import 'dart:async';

import 'package:flutter/foundation.dart';

import '../workout/trainer_metrics.dart';
import '../workout/workout_recorder.dart';

void _noopLog(String message) {}

/// Starts, pauses, resumes and ends rides on its own from what the trainer
/// reports, so a ride lands in Apple Health without the rider touching
/// BikeControl.
///
/// Polls once per [tick] rather than listening to the trainer: the trainer's
/// notifiers are rebuilt on every reconnect, and a poll against
/// [connectedTrainer] follows that without any rebinding.
///
/// Recordings the rider started by hand are left completely alone.
class AutoRideController {
  AutoRideController({
    required this.recorder,
    required this.connectedTrainer,
    required this.shouldRecord,
    required this.shouldDetect,
    required this.onRideFinished,
    this.onRideDetected,
    DateTime Function()? now,
    this.tick = const Duration(seconds: 1),
    this.minRide = defaultMinRide,
    this.log = _noopLog,
  }) : _now = now ?? DateTime.now;

  /// TUNABLE. Standstill before an automatic pause.
  static const pauseAfter = Duration(seconds: 10);

  /// TUNABLE. Standstill before the ride is considered over.
  static const stopAfterIdle = Duration(minutes: 5);

  /// TUNABLE. How long a disconnected trainer may take to come back.
  static const stopAfterDisconnect = Duration(minutes: 2);

  /// A shorter spin is not a ride — for detection and for saving alike.
  static const defaultMinRide = Duration(minutes: 5);

  /// A shorter spin is not a ride — for detection and for saving alike.
  /// Injectable so debug builds can shorten it; production and tests keep
  /// [defaultMinRide].
  final Duration minRide;

  final WorkoutRecorder recorder;

  /// The first connected trainer's live metrics, or null when none is.
  final TrainerMetrics? Function() connectedTrainer;

  /// Record automatically (the setting is effectively on).
  final bool Function() shouldRecord;

  /// Watch for a ride without recording it, to cue the home prompt.
  final bool Function() shouldDetect;

  /// An automatic ride ended (idle, disconnect or [finishNow]).
  final void Function(WorkoutResult result) onRideFinished;

  /// A ride of at least [minRide] ended, recorded or only watched.
  final VoidCallback? onRideDetected;

  final Duration tick;
  final DateTime Function() _now;

  /// Diagnostic logging, one concise line per decision. No-op unless wired.
  final void Function(String message) log;

  final ValueNotifier<bool> _isAutoRecording = ValueNotifier(false);

  /// True while the running recording is one this controller started.
  ValueListenable<bool> get isAutoRecording => _isAutoRecording;

  Timer? _timer;
  DateTime? _lastPedalAt;
  DateTime? _disconnectedSince;

  /// After [finishNow]/[discard] the rider may still be pedalling; wait for a
  /// break before starting the next ride, or it would restart at once.
  bool _waitForBreak = false;

  /// Detection-only bookkeeping.
  bool _watching = false;
  Duration _watchedPedalling = Duration.zero;

  void start() {
    _timer ??= Timer.periodic(tick, (_) => _onTick());
  }

  void dispose() {
    _timer?.cancel();
    _timer = null;
    _isAutoRecording.dispose();
  }

  /// Ends the automatic ride now and hands it over like an automatic stop.
  void finishNow() {
    if (!_isAutoRecording.value) return;
    final result = recorder.stop();
    _endAutoRide(waitForBreak: true);
    _reportIfLongEnough(result.activeDuration);
    log('ride ended reason=finishNow activeDuration=${result.activeDuration}');
    onRideFinished(result);
  }

  /// The rider stopped the running recording by hand (automatic or not); the
  /// caller takes over the result. Like [finishNow], an automatic ride waits
  /// for a break before the next one starts.
  WorkoutResult stop() {
    final result = recorder.stop();
    if (_isAutoRecording.value) {
      _endAutoRide(waitForBreak: true);
      log('ride ended reason=manualStop activeDuration=${result.activeDuration}');
    }
    return result;
  }

  /// Throws the automatic ride away.
  void discard() {
    if (!_isAutoRecording.value) return;
    final result = recorder.stop();
    _endAutoRide(waitForBreak: true);
    log('ride ended reason=discard activeDuration=${result.activeDuration}');
  }

  void _onTick() {
    final now = _now();
    final trainer = connectedTrainer();
    final pedalling = trainer != null && _isPedalling(trainer);

    if (!pedalling) _waitForBreak = false;

    if (_isAutoRecording.value) {
      if (recorder.state.value == WorkoutState.idle) {
        // Stopped from elsewhere (the manual stop button) — no longer ours.
        _endAutoRide(waitForBreak: false);
        return;
      }
      _followRide(now, trainer, pedalling);
      return;
    }

    if (recorder.state.value != WorkoutState.idle) return;

    if (shouldRecord()) {
      _watching = false;
      if (pedalling && !_waitForBreak) {
        recorder.start(trainer);
        _isAutoRecording.value = true;
        _lastPedalAt = now;
        _disconnectedSince = null;
        log('ride started cadence=${trainer.cadenceRpm.value} power=${trainer.powerW.value}');
      }
      return;
    }

    if (shouldDetect()) {
      _watch(now, trainer, pedalling);
    } else {
      _watching = false;
    }
  }

  void _followRide(DateTime now, TrainerMetrics? trainer, bool pedalling) {
    if (trainer == null) {
      _disconnectedSince ??= now;
    } else {
      _disconnectedSince = null;
      recorder.updateMetrics(trainer);
    }

    if (pedalling) {
      _lastPedalAt = now;
      if (recorder.state.value == WorkoutState.paused) {
        recorder.resume();
        log('ride resumed');
      }
      return;
    }

    final lastPedal = _lastPedalAt ?? now;
    final idle = now.difference(lastPedal);
    if (recorder.state.value == WorkoutState.recording && idle >= pauseAfter) {
      recorder.pause(at: lastPedal);
      log('ride paused');
    }

    final disconnectedSince = _disconnectedSince;
    final goneTooLong = disconnectedSince != null && now.difference(disconnectedSince) >= stopAfterDisconnect;
    if (idle >= stopAfterIdle || goneTooLong) {
      final result = recorder.stop(at: lastPedal);
      _endAutoRide(waitForBreak: false);
      _reportIfLongEnough(result.activeDuration);
      log('ride ended reason=${goneTooLong ? 'disconnect' : 'idle'} activeDuration=${result.activeDuration}');
      onRideFinished(result);
    }
  }

  void _watch(DateTime now, TrainerMetrics? trainer, bool pedalling) {
    if (pedalling) {
      if (!_watching) {
        _watching = true;
        _watchedPedalling = Duration.zero;
      } else {
        // A gap longer than a pause is a break, not pedalling.
        final gap = now.difference(_lastPedalAt ?? now);
        _watchedPedalling += gap > pauseAfter ? Duration.zero : gap;
      }
      _lastPedalAt = now;
      _disconnectedSince = null;
      return;
    }
    if (!_watching) return;
    if (trainer == null) {
      _disconnectedSince ??= now;
    } else {
      _disconnectedSince = null;
    }
    final idle = now.difference(_lastPedalAt ?? now);
    final disconnectedSince = _disconnectedSince;
    final goneTooLong = disconnectedSince != null && now.difference(disconnectedSince) >= stopAfterDisconnect;
    if (idle >= stopAfterIdle || goneTooLong) {
      _watching = false;
      _disconnectedSince = null;
      _reportIfLongEnough(_watchedPedalling);
    }
  }

  void _endAutoRide({required bool waitForBreak}) {
    _isAutoRecording.value = false;
    _lastPedalAt = null;
    _disconnectedSince = null;
    _waitForBreak = waitForBreak;
  }

  void _reportIfLongEnough(Duration pedalled) {
    if (pedalled >= minRide) onRideDetected?.call();
  }

  static bool _isPedalling(TrainerMetrics m) => (m.cadenceRpm.value ?? 0) > 0 || (m.powerW.value ?? 0) > 0;
}
