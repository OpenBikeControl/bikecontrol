import 'dart:async';

import 'package:flutter/foundation.dart';

import 'trainer_metrics.dart';
import 'workout_sample.dart';
import 'workout_summary.dart';

enum WorkoutState { idle, recording, paused }

/// One paused stretch of a ride. Exported to Apple Health as a pause/resume
/// event pair so the workout's duration reflects active time only.
class WorkoutPause {
  final DateTime start;
  final DateTime end;
  const WorkoutPause({required this.start, required this.end});
}

class WorkoutResult {
  final List<WorkoutSample> samples;
  final DateTime startedAt;
  final DateTime endedAt;
  final Duration activeDuration;
  final List<WorkoutPause> pauses;
  final WorkoutSummary summary;

  /// Shifts during the ride; null when the source has no gears.
  final int? gearChanges;
  WorkoutResult({
    required this.samples,
    required this.startedAt,
    required this.endedAt,
    required this.activeDuration,
    required this.pauses,
    required this.summary,
    this.gearChanges,
  });
}

class WorkoutRecorder {
  /// The clock the ride is timed by. Settable so tests on a fake clock can
  /// point the app's own recorder there.
  DateTime Function() nowProvider;
  final Duration tick;

  final ValueNotifier<WorkoutState> state = ValueNotifier(WorkoutState.idle);
  final ValueNotifier<Duration> elapsed = ValueNotifier(Duration.zero);
  final List<WorkoutSample> samples = [];

  /// Shifts (rear and front) since the ride started.
  final ValueNotifier<int> gearChanges = ValueNotifier(0);
  bool _hasGearSource = false;
  ValueListenable<int>? _gear;
  ValueListenable<Object?>? _frontRing;

  DateTime? _startedAt;
  DateTime? _lastResumedAt;
  DateTime? _pausedAt;
  final List<WorkoutPause> _pauses = [];
  Duration _accumulatedActive = Duration.zero;
  Timer? _timer;
  TrainerMetrics? _metrics;

  WorkoutRecorder({DateTime Function()? nowProvider, this.tick = const Duration(seconds: 1)})
    : nowProvider = nowProvider ?? DateTime.now;

  DateTime? get startedAt => _startedAt;

  void start(TrainerMetrics metrics) {
    if (state.value != WorkoutState.idle) return;
    _metrics = metrics;
    _startedAt = nowProvider();
    _lastResumedAt = _startedAt;
    _accumulatedActive = Duration.zero;
    samples.clear();
    _pauses.clear();
    gearChanges.value = 0;
    _hasGearSource = false;
    _bindGears(metrics);
    state.value = WorkoutState.recording;
    _timer = Timer.periodic(tick, (_) => _onTick());
  }

  /// Follows [metrics]' gears. Rebinding (a reconnect rebuilt the
  /// definition) only listens from here on: the fresh notifier's starting
  /// gear is not a shift.
  void _bindGears(TrainerMetrics metrics) {
    _unbindGears();
    _gear = metrics.gear?..addListener(_onShift);
    _frontRing = metrics.frontRing?..addListener(_onShift);
    if (_gear != null || _frontRing != null) _hasGearSource = true;
  }

  void _unbindGears() {
    _gear?.removeListener(_onShift);
    _frontRing?.removeListener(_onShift);
    _gear = null;
    _frontRing = null;
  }

  void _onShift() {
    if (state.value == WorkoutState.idle) return;
    gearChanges.value++;
  }

  /// Points sampling at a new source without touching timing — the trainer
  /// reconnected and its definition (and notifiers) were rebuilt.
  void updateMetrics(TrainerMetrics metrics) {
    if (state.value == WorkoutState.idle) return;
    if (!identical(metrics.gear, _gear) || !identical(metrics.frontRing, _frontRing)) _bindGears(metrics);
    _metrics = metrics;
  }

  /// [at] backdates the pause (never before the last resume): automatic
  /// pausing only notices a standstill some seconds after it began.
  void pause({DateTime? at}) {
    if (state.value != WorkoutState.recording) return;
    final resumedAt = _lastResumedAt!;
    var pausedAt = at ?? nowProvider();
    if (pausedAt.isBefore(resumedAt)) pausedAt = resumedAt;
    _accumulatedActive += pausedAt.difference(resumedAt);
    _lastResumedAt = null;
    _pausedAt = pausedAt;
    state.value = WorkoutState.paused;
  }

  void resume() {
    if (state.value != WorkoutState.paused) return;
    final now = nowProvider();
    _pauses.add(WorkoutPause(start: _pausedAt!, end: now));
    _pausedAt = null;
    _lastResumedAt = now;
    state.value = WorkoutState.recording;
  }

  /// [at] sets the ride's end (default: now) — an automatic stop ends the
  /// ride at the last pedal stroke, not minutes later when it is detected.
  WorkoutResult stop({DateTime? at}) {
    final startedAt = _startedAt ?? nowProvider();
    final endedAt = at ?? nowProvider();
    if (state.value == WorkoutState.recording && _lastResumedAt != null) {
      _accumulatedActive += endedAt.difference(_lastResumedAt!);
    }
    final pausedAt = _pausedAt;
    if (state.value == WorkoutState.paused && pausedAt != null && endedAt.isAfter(pausedAt)) {
      _pauses.add(WorkoutPause(start: pausedAt, end: endedAt));
    }
    _timer?.cancel();
    _timer = null;
    final active = _accumulatedActive;
    final captured = List<WorkoutSample>.unmodifiable(samples);
    final pauses = List<WorkoutPause>.unmodifiable(_pauses);
    final shifts = _hasGearSource ? gearChanges.value : null;
    final summary = WorkoutSummary.fromSamples(
      captured,
      startedAt: startedAt,
      activeDuration: active,
      endedAt: endedAt,
      pauses: pauses,
      gearChanges: shifts,
    );
    _reset();
    return WorkoutResult(
      samples: captured,
      startedAt: startedAt,
      endedAt: endedAt,
      activeDuration: active,
      pauses: pauses,
      summary: summary,
      gearChanges: shifts,
    );
  }

  void _reset() {
    state.value = WorkoutState.idle;
    _startedAt = null;
    _lastResumedAt = null;
    _pausedAt = null;
    _pauses.clear();
    _accumulatedActive = Duration.zero;
    elapsed.value = Duration.zero;
    samples.clear();
    _metrics = null;
    _unbindGears();
    _hasGearSource = false;
    gearChanges.value = 0;
  }

  void _onTick() {
    if (state.value != WorkoutState.recording) return;
    final m = _metrics;
    if (m == null) return;
    final now = nowProvider();
    samples.add(
      WorkoutSample(
        timestamp: now,
        powerW: m.powerW.value,
        cadenceRpm: m.cadenceRpm.value,
        speedKph: m.speedKph.value,
        heartRateBpm: m.heartRateBpm.value,
        heartRateFromHealth: m.isHeartRateFromHealth?.call() ?? false,
      ),
    );
    elapsed.value = _accumulatedActive + now.difference(_lastResumedAt!);
  }

  void dispose() {
    _timer?.cancel();
    _unbindGears();
    state.dispose();
    elapsed.dispose();
    gearChanges.dispose();
  }
}
