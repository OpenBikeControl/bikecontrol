import 'package:bike_control/services/workout/fit_writer.dart';
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
      WorkoutSample(
          timestamp: start,
          powerW: null,
          cadenceRpm: null,
          speedKph: null,
          heartRateBpm: null),
      WorkoutSample(
          timestamp: start.add(const Duration(seconds: 1)), powerW: 150),
    ];
    final summary = WorkoutSummary.fromSamples(
      samples,
      startedAt: start,
      activeDuration: const Duration(seconds: 2),
    );
    final bytes = FitFileWriter.encode(samples: samples, summary: summary);
    expect(bytes.length, greaterThan(0));
  });
}
