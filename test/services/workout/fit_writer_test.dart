import 'package:bike_control/services/workout/fit_reader.dart';
import 'package:bike_control/services/workout/fit_writer.dart';
import 'package:bike_control/services/workout/workout_recorder.dart' show WorkoutPause;
import 'package:bike_control/services/workout/workout_sample.dart';
import 'package:bike_control/services/workout/workout_summary.dart';
import 'package:fit_tool/fit_tool.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('encodes a non-empty FIT file that round-trips', () {
    final start = DateTime.utc(2026, 4, 24, 10, 0, 0);
    final samples = List.generate(
      60,
      (i) => WorkoutSample(
        timestamp: start.add(Duration(seconds: i)),
        powerW: 200 + i,
        cadenceRpm: 90,
        speedKph: 30.0,
        heartRateBpm: 140,
      ),
    );
    final summary = WorkoutSummary.fromSamples(
      samples,
      startedAt: start,
      activeDuration: const Duration(minutes: 1),
    );
    final bytes = FitFileWriter.encode(samples: samples, summary: summary);
    expect(bytes.length, greaterThan(100));

    // Round-trip: fit_tool parses its own output.
    // FitFile.records is List<Record>; data messages have record.message as DataMessage.
    final parsed = FitFile.fromBytes(bytes);
    final records = parsed.records
        .where((r) => !r.isDefinition && r.message is RecordMessage)
        .map((r) => r.message as RecordMessage)
        .toList();
    expect(records.length, 60);
    expect(records.first.power, 200);
    expect(records.last.power, 259);
  });

  test('tolerates null telemetry fields', () {
    final start = DateTime.utc(2026, 4, 24, 11, 0, 0);
    final samples = [
      WorkoutSample(timestamp: start, powerW: null, cadenceRpm: null, speedKph: null, heartRateBpm: null),
      WorkoutSample(timestamp: start.add(const Duration(seconds: 1)), powerW: 150),
    ];
    final summary = WorkoutSummary.fromSamples(
      samples,
      startedAt: start,
      activeDuration: const Duration(seconds: 2),
    );
    final bytes = FitFileWriter.encode(samples: samples, summary: summary);
    expect(bytes.length, greaterThan(0));
  });

  group('pauses', () {
    final start = DateTime.utc(2026, 10, 5, 17, 56);
    // 0-60 s riding, 60-90 s paused, 90-150 s riding.
    final pause = WorkoutPause(
      start: start.add(const Duration(seconds: 60)),
      end: start.add(const Duration(seconds: 90)),
    );
    final samples = [
      for (var i = 1; i <= 60; i++)
        WorkoutSample(timestamp: start.add(Duration(seconds: i)), powerW: 200, cadenceRpm: 90),
      for (var i = 91; i <= 150; i++)
        WorkoutSample(timestamp: start.add(Duration(seconds: i)), powerW: 250, cadenceRpm: 95, heartRateBpm: 140),
    ];
    final end = start.add(const Duration(seconds: 150));
    final summary = WorkoutSummary.fromSamples(
      samples,
      startedAt: start,
      activeDuration: const Duration(seconds: 120),
      endedAt: end,
      pauses: [pause],
    );
    final bytes = FitFileWriter.encode(samples: samples, summary: summary, pauses: [pause], endedAt: end);

    test('writes timer stop/start events at each pause', () {
      final events = FitFile.fromBytes(bytes).records
          .where((r) => !r.isDefinition && r.message is EventMessage)
          .map((r) => r.message as EventMessage)
          .toList();
      expect(
        events.map((e) => (e.eventType, e.timestamp)),
        [
          (EventType.start, start.millisecondsSinceEpoch),
          (EventType.stop, pause.start.millisecondsSinceEpoch),
          (EventType.start, pause.end.millisecondsSinceEpoch),
          (EventType.stopAll, end.millisecondsSinceEpoch),
        ],
      );
    });

    test('session: elapsed includes the pause, timer time does not', () {
      final session = FitFile.fromBytes(bytes).records
          .where((r) => !r.isDefinition && r.message is SessionMessage)
          .map((r) => r.message as SessionMessage)
          .single;
      expect(session.totalElapsedTime, closeTo(150, 0.01));
      expect(session.totalTimerTime, closeTo(120, 0.01));
      expect(session.maxCadence, 95);
      expect(session.timestamp, end.millisecondsSinceEpoch);
    });

    test('reads back as a result: samples, pauses, start and end', () {
      final result = FitFileReader.decode(bytes, summary: summary);
      expect(result.startedAt, start);
      expect(result.endedAt, end);
      expect(result.samples, hasLength(120));
      expect(result.samples.last.heartRateBpm, 140);
      expect(result.pauses, hasLength(1));
      expect(result.pauses.single.start, pause.start);
      expect(result.pauses.single.end, pause.end);
      expect(result.activeDuration, const Duration(seconds: 120));
    });
  });

  group('gears', () {
    final start = DateTime.utc(2026, 10, 6, 18);
    final samples = [
      for (var i = 1; i <= 10; i++)
        WorkoutSample(
          timestamp: start.add(Duration(seconds: i)),
          powerW: 200,
          gear: i <= 4 ? 8 : (i <= 7 ? 9 : 7),
        ),
    ];
    final summary = WorkoutSummary.fromSamples(samples, startedAt: start, activeDuration: const Duration(seconds: 10));
    final bytes = FitFileWriter.encode(samples: samples, summary: summary);

    test('writes a rear gear change event whenever the gear changes', () {
      final shifts = FitFile.fromBytes(bytes).records
          .where((r) => !r.isDefinition && r.message is EventMessage)
          .map((r) => r.message as EventMessage)
          .where((e) => e.event == Event.rearGearChange)
          .toList();
      expect(shifts.map((e) => e.rearGearNum), [8, 9, 7]);
      expect(shifts.map((e) => e.eventType), everyElement(EventType.marker));
      expect(shifts.first.timestamp, start.add(const Duration(seconds: 1)).millisecondsSinceEpoch);
    });

    test('reads the gears back onto the samples', () {
      final result = FitFileReader.decode(bytes, summary: summary);
      expect(result.samples.map((s) => s.gear), [8, 8, 8, 8, 9, 9, 9, 7, 7, 7]);
    });

    test('a ride without gears writes no gear events', () {
      final plain = [for (var i = 1; i <= 3; i++) WorkoutSample(timestamp: start.add(Duration(seconds: i)), powerW: 1)];
      final b = FitFileWriter.encode(
        samples: plain,
        summary: WorkoutSummary.fromSamples(plain, startedAt: start, activeDuration: const Duration(seconds: 3)),
      );
      final events = FitFile.fromBytes(b).records
          .where((r) => !r.isDefinition && r.message is EventMessage)
          .map((r) => (r.message as EventMessage).event);
      expect(events, isNot(contains(Event.rearGearChange)));
      expect(FitFileReader.decode(b, summary: summary).samples.map((s) => s.gear), everyElement(isNull));
    });
  });
}
