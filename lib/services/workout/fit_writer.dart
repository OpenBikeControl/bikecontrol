import 'dart:typed_data';

import 'package:fit_tool/fit_tool.dart';

import 'workout_sample.dart';
import 'workout_summary.dart';

/// Encodes a completed workout to a standard FIT Activity file (.fit).
///
/// Layout mirrors the Garmin FIT cookbook recipe for Activity files:
/// FileId → Event(start) → Record × N → Event(stop) → Lap →
/// Session → Activity.
class FitFileWriter {
  static const int _manufacturerDevelopment = 255; // development manufacturer id

  static Uint8List encode({
    required List<WorkoutSample> samples,
    required WorkoutSummary summary,
  }) {
    final startMs = summary.startedAt.toUtc().millisecondsSinceEpoch;
    final endMs = startMs + summary.activeDuration.inMilliseconds;

    final builder = FitFileBuilder(autoDefine: true);

    builder.add(
      FileIdMessage()
        ..type = FileType.activity
        ..manufacturer = _manufacturerDevelopment
        ..product = 1
        ..timeCreated = startMs
        ..serialNumber = 0,
    );

    builder.add(
      EventMessage()
        ..timestamp = startMs
        ..event = Event.timer
        ..eventType = EventType.start,
    );

    for (final s in samples) {
      final msg = RecordMessage()
        ..timestamp = s.timestamp.toUtc().millisecondsSinceEpoch;
      if (s.powerW != null) msg.power = s.powerW;
      if (s.cadenceRpm != null) msg.cadence = s.cadenceRpm;
      if (s.speedKph != null) msg.speed = s.speedKph! / 3.6; // FIT stores m/s
      if (s.heartRateBpm != null) msg.heartRate = s.heartRateBpm;
      builder.add(msg);
    }

    builder.add(
      EventMessage()
        ..timestamp = endMs
        ..event = Event.timer
        ..eventType = EventType.stopAll,
    );

    // Every FIT activity file MUST contain at least one Lap message.
    final elapsedTimeSeconds = summary.activeDuration.inSeconds.toDouble();
    builder.add(
      LapMessage()
        ..timestamp = endMs
        ..startTime = startMs
        ..totalElapsedTime = elapsedTimeSeconds
        ..totalTimerTime = elapsedTimeSeconds,
    );

    final avgHr = summary.avgHeartRateBpm == 0 ? null : summary.avgHeartRateBpm;
    final maxHr = summary.maxHeartRateBpm == 0 ? null : summary.maxHeartRateBpm;

    builder.add(
      SessionMessage()
        ..timestamp = endMs
        ..startTime = startMs
        ..sport = Sport.cycling
        ..subSport = SubSport.indoorCycling
        ..totalElapsedTime = elapsedTimeSeconds
        ..totalTimerTime = elapsedTimeSeconds
        ..totalDistance = summary.distanceKm * 1000.0
        ..avgPower = summary.avgPowerW
        ..maxPower = summary.maxPowerW
        ..avgCadence = summary.avgCadenceRpm
        ..avgSpeed = summary.avgSpeedKph / 3.6
        ..avgHeartRate = avgHr
        ..maxHeartRate = maxHr
        ..firstLapIndex = 0
        ..numLaps = 1,
    );

    builder.add(
      ActivityMessage()
        ..timestamp = endMs
        ..totalTimerTime = elapsedTimeSeconds
        ..numSessions = 1
        ..type = Activity.manual
        ..event = Event.activity
        ..eventType = EventType.stop,
    );

    final fit = builder.build();
    return Uint8List.fromList(fit.toBytes());
  }
}
