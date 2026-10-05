import 'dart:typed_data';

import 'package:fit_tool/fit_tool.dart';

import 'workout_recorder.dart';
import 'workout_sample.dart';
import 'workout_summary.dart';

/// Reads a ride back from the `.fit` file [FitFileWriter] wrote: its records
/// as samples and its timer stop/start events as pauses. Lets a ride saved
/// earlier still go to Apple Health / Health Connect, which need the series,
/// not just the sidecar's averages.
class FitFileReader {
  static WorkoutResult decode(Uint8List bytes, {required WorkoutSummary summary}) {
    final fit = FitFile.fromBytes(bytes);
    final samples = <WorkoutSample>[];
    final pauses = <WorkoutPause>[];
    DateTime? start;
    DateTime? end;
    DateTime? pausedAt;
    DateTime at(int ms) => DateTime.fromMillisecondsSinceEpoch(ms, isUtc: true);

    for (final record in fit.records) {
      if (record.isDefinition) continue;
      final message = record.message;
      if (message is RecordMessage) {
        final ms = message.timestamp;
        if (ms == null) continue;
        final speed = message.speed;
        samples.add(
          WorkoutSample(
            timestamp: at(ms),
            powerW: message.power,
            cadenceRpm: message.cadence,
            speedKph: speed == null ? null : speed * 3.6,
            heartRateBpm: message.heartRate,
          ),
        );
      } else if (message is EventMessage && message.event == Event.timer) {
        final ms = message.timestamp;
        if (ms == null) continue;
        switch (message.eventType) {
          case EventType.start:
            if (start == null) {
              start = at(ms);
            } else if (pausedAt != null) {
              pauses.add(WorkoutPause(start: pausedAt, end: at(ms)));
              pausedAt = null;
            }
          case EventType.stop:
            pausedAt = at(ms);
          case EventType.stopAll:
            end = at(ms);
          default:
            break;
        }
      }
    }

    final startedAt = start ?? summary.startedAt.toUtc();
    final endedAt = end ?? summary.endedAt?.toUtc() ?? startedAt.add(summary.activeDuration);
    return WorkoutResult(
      samples: samples,
      startedAt: startedAt,
      endedAt: endedAt,
      activeDuration: summary.activeDuration,
      pauses: pauses,
      summary: summary,
      gearChanges: summary.gearChanges,
    );
  }
}
