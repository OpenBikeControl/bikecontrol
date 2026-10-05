import 'dart:typed_data';

import 'package:fit_tool/fit_tool.dart';

import 'workout_recorder.dart' show WorkoutPause;
import 'workout_sample.dart';
import 'workout_summary.dart';

/// Encodes a completed workout to a standard FIT Activity file (.fit).
///
/// Layout mirrors the Garmin FIT cookbook recipe for Activity files:
/// FileId → Event(timer start) → Record × N, with a timer stop/start event
/// pair at each pause → Event(stop all) → Lap → Session → Activity.
class FitFileWriter {
  static const int _manufacturerDevelopment = 255; // development manufacturer id

  /// [endedAt] defaults to start + moving time (rides from before pauses
  /// were tracked); [pauses] become timer stop/start events so platforms
  /// show moving time and elapsed time apart.
  static Uint8List encode({
    required List<WorkoutSample> samples,
    required WorkoutSummary summary,
    List<WorkoutPause> pauses = const [],
    DateTime? endedAt,
  }) {
    final startMs = summary.startedAt.toUtc().millisecondsSinceEpoch;
    final endMs =
        (endedAt ?? summary.endedAt)?.toUtc().millisecondsSinceEpoch ?? startMs + summary.activeDuration.inMilliseconds;

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

    // Timer events and records in time order: a pause's stop lands before
    // the first record after it.
    final timerEvents = <(int, EventType)>[
      for (final p in pauses) ...[
        (p.start.toUtc().millisecondsSinceEpoch, EventType.stop),
        (p.end.toUtc().millisecondsSinceEpoch, EventType.start),
      ],
    ]..sort((a, b) => a.$1.compareTo(b.$1));
    var nextEvent = 0;
    void flushEventsUntil(int ms) {
      while (nextEvent < timerEvents.length && timerEvents[nextEvent].$1 <= ms) {
        final (at, type) = timerEvents[nextEvent++];
        builder.add(
          EventMessage()
            ..timestamp = at
            ..event = Event.timer
            ..eventType = type,
        );
      }
    }

    for (final s in samples) {
      final at = s.timestamp.toUtc().millisecondsSinceEpoch;
      flushEventsUntil(at);
      final msg = RecordMessage()..timestamp = at;
      if (s.powerW != null) msg.power = s.powerW;
      if (s.cadenceRpm != null) msg.cadence = s.cadenceRpm;
      if (s.speedKph != null) msg.speed = s.speedKph! / 3.6; // FIT stores m/s
      if (s.heartRateBpm != null) msg.heartRate = s.heartRateBpm;
      builder.add(msg);
    }

    flushEventsUntil(endMs);
    builder.add(
      EventMessage()
        ..timestamp = endMs
        ..event = Event.timer
        ..eventType = EventType.stopAll,
    );

    // Every FIT activity file MUST contain at least one Lap message.
    final elapsedTimeSeconds = (endMs - startMs) / 1000.0;
    final timerTimeSeconds = summary.activeDuration.inSeconds.toDouble();
    builder.add(
      LapMessage()
        ..timestamp = endMs
        ..startTime = startMs
        ..totalElapsedTime = elapsedTimeSeconds
        ..totalTimerTime = timerTimeSeconds,
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
        ..totalTimerTime = timerTimeSeconds
        ..totalDistance = summary.hasSpeed ? summary.distanceKm * 1000.0 : null
        ..avgPower = summary.avgPowerW
        ..maxPower = summary.maxPowerW
        ..totalWork = (summary.workKj * 1000).round()
        ..totalCalories = summary.energyKcal.round()
        ..avgCadence = summary.avgCadenceRpm
        ..maxCadence = summary.maxCadenceRpm == 0 ? null : summary.maxCadenceRpm
        ..avgSpeed = summary.hasSpeed ? summary.avgSpeedKph / 3.6 : null
        ..avgHeartRate = avgHr
        ..maxHeartRate = maxHr
        ..firstLapIndex = 0
        ..numLaps = 1,
    );

    builder.add(
      ActivityMessage()
        ..timestamp = endMs
        ..totalTimerTime = timerTimeSeconds
        ..numSessions = 1
        ..type = Activity.manual
        ..event = Event.activity
        ..eventType = EventType.stop,
    );

    final fit = builder.build();
    return Uint8List.fromList(fit.toBytes());
  }
}
