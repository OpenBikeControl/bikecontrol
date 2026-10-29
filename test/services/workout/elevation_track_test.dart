import 'package:bike_control/services/workout/elevation_track.dart';
import 'package:bike_control/services/workout/workout_sample.dart';
import 'package:flutter_test/flutter_test.dart';

// The trainer app only sends a grade; the climb comes from riding it: the
// distance covered each second, along the slope.
void main() {
  final start = DateTime.utc(2026, 10, 29, 9);
  WorkoutSample s(int sec, {double? kph, double? grade}) => WorkoutSample(
    timestamp: start.add(Duration(seconds: sec)),
    speedKph: kph,
    gradePct: grade,
  );

  test('ten seconds at 36 km/h up 10 % climb about 10 m', () {
    final alt = ElevationTrack.altitudes([for (var i = 0; i <= 10; i++) s(i, kph: 36, grade: 10)])!;
    expect(alt.first, 0);
    // 100 m along a 10 % slope: 100 · sin(atan(0.1)).
    expect(alt.last, closeTo(9.95, 0.01));
  });

  test('down again, and the ascent counts only the way up', () {
    final samples = [
      for (var i = 0; i <= 10; i++) s(i, kph: 36, grade: 10),
      for (var i = 11; i <= 20; i++) s(i, kph: 36, grade: -5),
    ];
    final alt = ElevationTrack.altitudes(samples)!;
    expect(alt.last, closeTo(9.95 - 49.94 / 10, 0.02));
    final climb = ElevationTrack.climb(alt);
    expect(climb.ascent, closeTo(9.95, 0.01));
    expect(climb.descent, closeTo(4.99, 0.02));
  });

  test('a gap (a pause) adds no distance', () {
    final alt = ElevationTrack.altitudes([
      s(0, kph: 36, grade: 10),
      s(1, kph: 36, grade: 10),
      s(120, kph: 36, grade: 10),
    ])!;
    expect(alt[2] - alt[1], lessThan(2.1), reason: 'at most the usual tick, not two minutes of riding');
  });

  test('seconds without a grade (ERG) stay level', () {
    final alt = ElevationTrack.altitudes([s(0, kph: 36, grade: 10), s(1, kph: 36), s(2, kph: 36)])!;
    expect(alt[1], alt[2]);
  });

  test('a ride without any grade has no track', () {
    expect(ElevationTrack.altitudes([s(0, kph: 30), s(1, kph: 30)]), isNull);
    expect(ElevationTrack.altitudes([]), isNull);
  });
}
