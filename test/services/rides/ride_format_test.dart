import 'dart:io';

import 'package:bike_control/gen/l10n.dart';
import 'package:bike_control/services/rides/ride_format.dart';
import 'package:bike_control/services/workout/past_workout.dart';
import 'package:bike_control/services/workout/workout_sample.dart';
import 'package:bike_control/services/workout/workout_summary.dart';
import 'package:bike_control/utils/units.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

void main() {
  late AppLocalizations l10n;

  setUpAll(() async {
    await initializeDateFormatting('de');
    l10n = await AppLocalizations.load(const Locale('de'));
  });

  final start = DateTime.utc(2026, 10, 5, 15, 56);

  WorkoutSummary summary({bool speed = true, bool hr = true, int? gears = 37}) {
    final samples = [
      for (var i = 0; i < 10; i++)
        WorkoutSample(
          timestamp: start.add(Duration(seconds: i)),
          powerW: 212,
          speedKph: speed ? 41.7 : null,
          heartRateBpm: hr ? 142 : null,
        ),
    ];
    return WorkoutSummary.fromSamples(
      samples,
      startedAt: start,
      activeDuration: const Duration(minutes: 42, seconds: 18),
      gearChanges: gears,
    );
  }

  test('durations', () {
    expect(formatRideDuration(const Duration(minutes: 42, seconds: 18)), '42:18');
    expect(formatRideDuration(const Duration(hours: 1, minutes: 31, seconds: 5)), '1:31:05');
    expect(formatRideTotal(const Duration(hours: 2, minutes: 59)), '2:59 h');
    expect(formatRideTotal(const Duration(minutes: 42)), '42 min');
  });

  test('notification carries the summary numbers', () {
    final n = rideNotificationContent(summary(), l10n, units: UnitSystem.metric, locale: 'de');
    expect(n.title, '42:18 · 29,4 km · Ø 212 W');
    expect(n.body, '538 kJ · Ø 142 bpm · ${l10n.ridesGearChangeCount(37)}');
  });

  test('notification leaves out what was not measured', () {
    final n = rideNotificationContent(
      summary(speed: false, hr: false, gears: null),
      l10n,
      units: UnitSystem.metric,
      locale: 'de',
    );
    expect(n.title, '42:18 · Ø 212 W');
    expect(n.body, '538 kJ');
  });

  test('payload names the ride and only rides', () {
    final ride = PastWorkout(file: File('/x/workout-20261005T155600Z.fit'), startedAt: start, sizeBytes: 1);
    final payload = rideNotificationPayload(ride);
    expect(rideFileFromPayload(payload), 'workout-20261005T155600Z.fit');
    expect(rideFileFromPayload('something-else'), isNull);
    expect(rideFileFromPayload(null), isNull);
  });
}
