import 'dart:async';

import 'package:bike_control/bluetooth/incline/incline_manual_state.dart';
import 'package:bike_control/bluetooth/incline/incline_sink.dart';
import 'package:flutter/foundation.dart';

/// Runs a ~1 Hz loop: read the active bridge's sim grade, pick a sink, and
/// write the clamped incline while the sink follows grade (auto). Flattens once
/// when the grade source disappears after having driven an incline device.
class InclineController {
  InclineController({
    required int? Function() gradeProvider,
    required InclineSink? Function() sinkProvider,
  })  : _gradeProvider = gradeProvider,
        _sinkProvider = sinkProvider;

  final int? Function() _gradeProvider;
  final InclineSink? Function() _sinkProvider;

  /// The grade the last tick read (0.01% signed), null while nothing sends
  /// one. Lets the incline UI tell "waiting for a gradient" from "flat".
  final ValueNotifier<int?> sourceGrade = ValueNotifier(null);

  Timer? _timer;
  int? _lastWritten;
  InclineSink? _lastSink;
  bool _ticking = false;

  void start() {
    _timer ??= Timer.periodic(const Duration(seconds: 1), (_) => tick());
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  Future<void> tick() async {
    if (_ticking) return; // don't overlap if a previous tick's write is still in flight
    _ticking = true;
    try {
      sourceGrade.value = _gradeProvider();
      final sink = _sinkProvider();
      if (sink == null) {
        _lastWritten = null;
        _lastSink = null;
        return;
      }
      // A new sink (e.g. a physical Climb replacing the relay) must get a fresh
      // write, so drop the dedup baseline when the sink identity changes.
      if (!identical(sink, _lastSink)) {
        _lastWritten = null;
        _lastSink = sink;
      }

      final grade = sourceGrade.value;
      if (grade == null) {
        // Source gone (trainer app left / mode swap): flatten once for safety.
        if (_lastWritten != null && _lastWritten != 0 && sink.followsGrade) {
          if (await sink.writeInclineRaw(0)) _lastWritten = 0;
        }
        return;
      }

      if (!sink.followsGrade) {
        // Manual hold: device owns the value. Drop the dedup baseline so returning
        // to auto re-asserts the grade even if it equals the last auto-written value.
        _lastWritten = null;
        return;
      }

      final clamped = grade.clamp(kInclineManualMinGrade001, kInclineManualMaxGrade001);
      if (clamped == _lastWritten) return;
      if (await sink.writeInclineRaw(clamped)) _lastWritten = clamped;
    } finally {
      _ticking = false;
    }
  }
}
