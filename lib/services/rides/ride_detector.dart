import 'dart:async';

import 'package:flutter/foundation.dart';

import '../workout/trainer_metrics.dart';
import '../workout/workout_recorder.dart';

void _noopLog(String message) {}

/// Why a ride ended.
enum RideEndReason {
  /// No pedalling for [RideDetector.stopAfterIdle].
  idle,

  /// The source was gone for [RideDetector.stopAfterDisconnect].
  disconnected,

  /// The rider pressed Beenden.
  finished,
}

/// Runs every ride, automatic or started by hand: starts one at the first
/// pedal stroke (while [autoRecord] is on), pauses it after
/// [pauseAfter] without pedalling (backdated to the last stroke), resumes on
/// the next one, and ends it after [stopAfterIdle] idle or
/// [stopAfterDisconnect] without a source.
///
/// "Pedalling" is power or cadence from whatever BikeControl receives: a
/// trainer it bridges or an external power / cadence sensor. Heart rate alone
/// is not a ride.
///
/// Polls once per [tick] rather than listening: the trainer's notifiers are
/// rebuilt on every reconnect, and a poll against [source] follows that
/// without any rebinding.
class RideDetector {
  RideDetector({
    required this.recorder,
    required this.source,
    required this.autoRecord,
    required this.onRideFinished,
    DateTime Function()? now,
    this.tick = const Duration(seconds: 1),
    this.log = _noopLog,
  }) : _now = now ?? DateTime.now;

  /// TUNABLE. Standstill before an automatic pause.
  static const pauseAfter = Duration(seconds: 10);

  /// TUNABLE. Standstill before the ride is considered over.
  static const stopAfterIdle = Duration(minutes: 5);

  /// TUNABLE. How long a disconnected source may take to come back.
  static const stopAfterDisconnect = Duration(minutes: 2);

  /// TUNABLE. A ride with less moving time AND less work than this is a
  /// spin-up, not a ride: it is dropped without a word.
  static const minMovingTime = Duration(minutes: 2);
  static const minWorkKj = 10.0;

  static bool isTooShort(WorkoutResult result) =>
      result.activeDuration < minMovingTime && result.summary.workKj < minWorkKj;

  final WorkoutRecorder recorder;

  /// What BikeControl currently receives power / cadence from, or null.
  final TrainerMetrics? Function() source;

  /// The "record rides automatically" setting.
  final bool Function() autoRecord;

  /// A ride ended (idle, disconnect or [finish]); [discard] does not report.
  final void Function(WorkoutResult result, RideEndReason reason) onRideFinished;

  final Duration tick;
  final DateTime Function() _now;

  /// Diagnostic logging, one concise line per decision. No-op unless wired.
  final void Function(String message) log;

  final ValueNotifier<bool> _startedAutomatically = ValueNotifier(false);

  /// Whether the running ride was started by the first pedal stroke.
  ValueListenable<bool> get startedAutomatically => _startedAutomatically;

  Timer? _timer;
  DateTime? _lastPedalAt;
  DateTime? _disconnectedSince;

  /// After [finish]/[discard] the rider may still be pedalling; wait for a
  /// break before starting the next ride, or it would restart at once.
  bool _waitForBreak = false;

  bool get isRiding => recorder.state.value != WorkoutState.idle;

  /// Whether the ride that ended last (or runs now) started automatically.
  bool get lastRideWasAutomatic => _lastRideWasAutomatic;
  bool _lastRideWasAutomatic = false;

  void start() {
    _timer ??= Timer.periodic(tick, (_) => _onTick());
  }

  void dispose() {
    _timer?.cancel();
    _timer = null;
    _startedAutomatically.dispose();
  }

  /// "Aufzeichnung starten": false when there is nothing to record from.
  bool startManual() {
    if (isRiding) return true;
    final metrics = source();
    if (metrics == null) return false;
    _begin(metrics, automatic: false);
    log('ride started by hand');
    return true;
  }

  /// Beenden: ends the ride now and reports it.
  WorkoutResult? finish() {
    if (!isRiding) return null;
    final result = recorder.stop();
    _end(waitForBreak: true);
    log('ride ended reason=finished activeDuration=${result.activeDuration}');
    onRideFinished(result, RideEndReason.finished);
    return result;
  }

  /// Verwerfen: throws the running ride away.
  void discard() {
    if (!isRiding) return;
    final result = recorder.stop();
    _end(waitForBreak: true);
    log('ride discarded activeDuration=${result.activeDuration}');
  }

  void _begin(TrainerMetrics metrics, {required bool automatic}) {
    _startedAutomatically.value = automatic;
    _lastRideWasAutomatic = automatic;
    _lastPedalAt = _now();
    _disconnectedSince = null;
    recorder.start(metrics);
  }

  void _onTick() {
    final now = _now();
    final metrics = source();
    final pedalling = metrics != null && _isPedalling(metrics);

    if (!pedalling) _waitForBreak = false;

    if (isRiding) {
      _followRide(now, metrics, pedalling);
      return;
    }

    if (autoRecord() && pedalling && !_waitForBreak) {
      _begin(metrics, automatic: true);
      log('ride started cadence=${metrics.cadenceRpm.value} power=${metrics.powerW.value}');
    }
  }

  void _followRide(DateTime now, TrainerMetrics? metrics, bool pedalling) {
    if (metrics == null) {
      _disconnectedSince ??= now;
    } else {
      _disconnectedSince = null;
      recorder.updateMetrics(metrics);
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
      _end(waitForBreak: false);
      final reason = goneTooLong ? RideEndReason.disconnected : RideEndReason.idle;
      log('ride ended reason=${reason.name} activeDuration=${result.activeDuration}');
      onRideFinished(result, reason);
    }
  }

  void _end({required bool waitForBreak}) {
    _startedAutomatically.value = false;
    _lastPedalAt = null;
    _disconnectedSince = null;
    _waitForBreak = waitForBreak;
  }

  static bool _isPedalling(TrainerMetrics m) => (m.cadenceRpm.value ?? 0) > 0 || (m.powerW.value ?? 0) > 0;
}
