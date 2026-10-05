import 'package:intl/intl.dart';

import '../../gen/l10n.dart';
import '../../utils/units.dart';
import '../health/health_workout_channel.dart';
import '../workout/past_workout.dart';
import '../workout/workout_summary.dart';

/// "42:18", or "1:31:05" from an hour on.
String formatRideDuration(Duration d) {
  String two(int v) => v.toString().padLeft(2, '0');
  final h = d.inHours;
  final m = d.inMinutes.remainder(60);
  final s = d.inSeconds.remainder(60);
  return h > 0 ? '$h:${two(m)}:${two(s)}' : '${two(m)}:${two(s)}';
}

/// "2:59 h" / "42 min" for week totals.
String formatRideTotal(Duration d) {
  if (d.inHours == 0) return '${d.inMinutes} min';
  return '${d.inHours}:${d.inMinutes.remainder(60).toString().padLeft(2, '0')} h';
}

/// The distance's number in the rider's units ("29,4" in German), no unit.
String formatRideDistance(double km, UnitSystem units, String locale) =>
    NumberFormat.decimalPatternDigits(locale: locale, decimalDigits: 1).format(units.fromKm(km));

String formatInt(num v, String locale) => NumberFormat.decimalPattern(locale).format(v.round());

/// "17:56–18:40".
String formatRideClockRange(WorkoutSummary s, String locale) {
  final f = DateFormat.Hm(locale);
  final start = s.startedAt.toLocal();
  final end = (s.endedAt ?? s.startedAt.add(s.activeDuration)).toLocal();
  return '${f.format(start)}–${f.format(end)}';
}

/// The store's name as the platform shows it ("Apple Santé" in French).
String healthStoreName(HealthStore store, [AppLocalizations? l10n]) => switch (store) {
  HealthStore.appleHealth => (l10n ?? AppLocalizations.current).ridesAppleHealth,
  HealthStore.healthConnect => 'Health Connect',
};

/// The push sent when a ride ended in the background: the summary card's
/// numbers. "42:18 · 29,4 km · Ø 212 W" / "538 kJ · Ø 142 bpm · 37 gear changes".
({String title, String body}) rideNotificationContent(
  WorkoutSummary s,
  AppLocalizations l10n, {
  required UnitSystem units,
  required String locale,
}) {
  final distance = s.shownDistanceKm;
  final title = [
    formatRideDuration(s.activeDuration),
    if (distance != null) '${formatRideDistance(distance, units, locale)} ${units.distanceSymbol}',
    if (s.avgPowerW > 0) 'Ø ${s.avgPowerW} W',
  ].join(' · ');
  final body = [
    '${formatInt(s.workKj, locale)} kJ',
    if (s.avgHeartRateBpm > 0) 'Ø ${s.avgHeartRateBpm} bpm',
    if (s.gearChanges case final g?) l10n.ridesGearChangeCount(g),
  ].join(' · ');
  return (title: title, body: body);
}

const _payloadPrefix = 'ride:';

/// What the ride's notification carries, for the tap to open its Details.
String rideNotificationPayload(PastWorkout ride) => '$_payloadPrefix${ride.fileName}';

/// The ride's file name from a notification payload, or null for any other
/// notification.
String? rideFileFromPayload(String? payload) {
  if (payload == null || !payload.startsWith(_payloadPrefix)) return null;
  final name = payload.substring(_payloadPrefix.length);
  return name.isEmpty ? null : name;
}
