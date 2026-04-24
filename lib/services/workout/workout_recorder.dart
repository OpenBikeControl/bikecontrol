import 'dart:async';

import 'package:flutter/foundation.dart';

import 'trainer_metrics.dart';
import 'workout_sample.dart';
import 'workout_summary.dart';

enum WorkoutState { idle, recording, paused }

class WorkoutResult {
  final List<WorkoutSample> samples;
  final DateTime startedAt;
  final Duration activeDuration;
  final WorkoutSummary summary;
  WorkoutResult({
    required this.samples,
    required this.startedAt,
    required this.activeDuration,
    required this.summary,
  });
}

class WorkoutRecorder {
  final DateTime Function() nowProvider;
  final Duration tick;

  final ValueNotifier<WorkoutState> state = ValueNotifier(WorkoutState.idle);
  final ValueNotifier<Duration> elapsed = ValueNotifier(Duration.zero);
  final List<WorkoutSample> samples = [];

  DateTime? _startedAt;
  DateTime? _lastResumedAt;
  Duration _accumulatedActive = Duration.zero;
  Timer? _timer;
  TrainerMetrics? _metrics;

  WorkoutRecorder({DateTime Function()? nowProvider, this.tick = const Duration(seconds: 1)})
      : nowProvider = nowProvider ?? DateTime.now;

  void start(TrainerMetrics metrics) {
    if (state.value != WorkoutState.idle) return;
    _metrics = metrics;
    _startedAt = nowProvider();
    _lastResumedAt = _startedAt;
    _accumulatedActive = Duration.zero;
    samples.clear();
    state.value = WorkoutState.recording;
    _timer = Timer.periodic(tick, (_) => _onTick());
  }

  void pause() {
    if (state.value != WorkoutState.recording) return;
    _accumulatedActive += nowProvider().difference(_lastResumedAt!);
    _lastResumedAt = null;
    state.value = WorkoutState.paused;
  }

  void resume() {
    if (state.value != WorkoutState.paused) return;
    _lastResumedAt = nowProvider();
    state.value = WorkoutState.recording;
  }

  WorkoutResult stop() {
    final startedAt = _startedAt ?? nowProvider();
    if (state.value == WorkoutState.recording && _lastResumedAt != null) {
      _accumulatedActive += nowProvider().difference(_lastResumedAt!);
    }
    _timer?.cancel();
    _timer = null;
    final active = _accumulatedActive;
    final captured = List<WorkoutSample>.unmodifiable(samples);
    final summary = WorkoutSummary.fromSamples(captured, startedAt: startedAt, activeDuration: active);
    _reset();
    return WorkoutResult(
      samples: captured,
      startedAt: startedAt,
      activeDuration: active,
      summary: summary,
    );
  }

  void _reset() {
    state.value = WorkoutState.idle;
    _startedAt = null;
    _lastResumedAt = null;
    _accumulatedActive = Duration.zero;
    elapsed.value = Duration.zero;
    samples.clear();
    _metrics = null;
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
      ),
    );
    elapsed.value = _accumulatedActive + now.difference(_lastResumedAt!);
  }

  void dispose() {
    _timer?.cancel();
    state.dispose();
    elapsed.dispose();
  }
}
