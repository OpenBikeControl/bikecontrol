import 'dart:io';

import 'package:bike_control/gen/l10n.dart';
import 'package:bike_control/main.dart' show OtherLocalizationsDelegate;
import 'package:bike_control/pages/activity/rides_view.dart';
import 'package:bike_control/pages/rides/ride_details_page.dart';
import 'package:bike_control/services/health/health_workout_channel.dart';
import 'package:bike_control/services/rides/ride_format.dart';
import 'package:bike_control/services/workout/past_workout.dart';
import 'package:bike_control/services/workout/trainer_metrics.dart';
import 'package:bike_control/services/workout/workout_summary.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

import '../../helpers/ride_fixtures.dart';
import '../../helpers/ride_rig.dart';
import '../../widget_snapshot.dart';

PastWorkout _ride(DateTime start, Duration moving) => PastWorkout(
  file: File('/x/${start.toIso8601String()}.fit'),
  startedAt: start.toUtc(),
  sizeBytes: 1,
  summary: WorkoutSummary(
    startedAt: start,
    activeDuration: moving,
    avgPowerW: 200,
    maxPowerW: 400,
    avgCadenceRpm: 90,
    avgSpeedKph: 30,
    distanceKm: 10,
    avgHeartRateBpm: 0,
    maxHeartRateBpm: 0,
    sampleCount: 1,
  ),
);

Future<void> main() async {
  await ensureSnapshotHarness();
  late AppLocalizations l10n;
  setUpAll(() async {
    await initializeDateFormatting('de');
    await initializeDateFormatting('en');
    l10n = await AppLocalizations.load(const Locale('en'));
  });
  setUp(RideRig.reset);

  group('weeks', () {
    // Monday 5 October 2026.
    final now = DateTime(2026, 10, 5, 18, 45);
    final rides = [
      _ride(DateTime(2026, 10, 5, 17, 56), const Duration(minutes: 42)),
      _ride(DateTime(2026, 10, 4, 10, 12), const Duration(hours: 1, minutes: 31)),
      _ride(DateTime(2026, 10, 2, 18, 30), const Duration(minutes: 55)),
      _ride(DateTime(2026, 9, 30, 19, 5), const Duration(minutes: 33)),
      _ride(DateTime(2026, 9, 23, 18, 2), const Duration(hours: 1)),
    ];

    test('grouped by calendar week (Monday start), newest first, with totals', () {
      final weeks = groupRidesByWeek(rides.reversed.toList());
      expect(weeks.map((w) => w.count), [1, 3, 1]);
      expect(weeks[0].rides.single.startedAt, rides[0].startedAt);
      expect(weeks[1].total, const Duration(hours: 2, minutes: 59));
      expect(formatRideTotal(weeks[1].total), '2:59 h');
      expect(weeks[1].rides.first.startedAt, rides[1].startedAt, reason: 'newest first inside a week');
    });

    test('this week, last week, then the dates', () {
      final weeks = groupRidesByWeek(rides);
      expect(rideWeekLabel(weeks[0], l10n, 'de', now: now), l10n.ridesThisWeek);
      expect(rideWeekLabel(weeks[1], l10n, 'de', now: now), l10n.ridesLastWeek);
      expect(rideWeekLabel(weeks[2], l10n, 'de', now: now), '21.–27. Sept.');
      expect(rideWeekLabel(weeks[2], l10n, 'en', now: now), 'Sep 21–27');
    });
  });

  Future<void> pump(WidgetTester tester, {bool desktop = false}) async {
    tester.view.physicalSize = const Size(390, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ShadcnApp(
        localizationsDelegates: const [
          ...ShadcnLocalizations.localizationsDelegates,
          OtherLocalizationsDelegate(),
          AppLocalizations.delegate,
        ],
        supportedLocales: const [Locale('en')],
        theme: ThemeData(colorScheme: ColorSchemes.lightSlate, radius: 0.7),
        home: DrawerOverlay(
          child: Scaffold(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const RidesMenuButton(),
                  RidesView(desktop: desktop),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('empty: how it works, no button while recording is automatic', (tester) async {
    await RideRig.install();
    await pump(tester);
    expect(find.text(l10n.ridesEmptyTitle), findsOneWidget);
    expect(find.text(l10n.ridesEmptyBody), findsOneWidget);
    expect(find.byKey(const ValueKey('rides-empty-start')), findsNothing);
  });

  testWidgets('empty with automatic recording off: the manual start', (tester) async {
    RideRig.source = TrainerMetrics(
      powerW: ValueNotifier<int?>(0),
      cadenceRpm: ValueNotifier<int?>(0),
      speedKph: ValueNotifier<double?>(null),
      heartRateBpm: ValueNotifier<int?>(null),
    );
    await RideRig.install(prefs: {'rides_auto_record': false});
    await pump(tester);
    expect(find.text(l10n.ridesEmptyBodyManual), findsOneWidget);
    expect(find.byKey(const ValueKey('rides-empty-start')), findsOneWidget);
  });

  testWidgets('rows: when, the numbers, the sparkline and where it went; tap opens Details', (tester) async {
    final rig = await RideRig.install();
    final ride = await saveSampleRide(rig.repository);
    await rig.service.markFitExported(ride);
    await pump(tester);

    expect(find.text(l10n.ridesThisWeek.toUpperCase()), findsOneWidget);
    expect(find.text('${l10n.ridesCount(1)} · 42 min'), findsOneWidget);
    expect(find.textContaining('42:18 · '), findsOneWidget);
    expect(find.text('.fit'), findsOneWidget);
    expect(find.text(l10n.ridesBadgeHealth), findsNothing);

    await tester.tap(find.byKey(ValueKey('ride-row-${ride.fileName}')));
    await tester.pumpAndSettle();
    expect(find.byType(RideDetailsPage), findsOneWidget);
  });

  testWidgets('swipe left deletes, after a confirm', (tester) async {
    final rig = await RideRig.install();
    final ride = await saveSampleRide(rig.repository);
    await pump(tester);

    await tester.drag(find.byKey(ValueKey('ride-row-${ride.fileName}')), const Offset(-500, 0));
    await tester.pumpAndSettle();
    expect(find.text(l10n.ridesDeleteTitle), findsOneWidget);
    await tester.tap(find.text(l10n.cancel));
    await tester.pumpAndSettle();
    expect(await rig.repository.find(ride.fileName), isNotNull);

    await tester.drag(find.byKey(ValueKey('ride-row-${ride.fileName}')), const Offset(-500, 0));
    await tester.pumpAndSettle();
    await tester.tap(find.text(l10n.delete).last);
    await tester.pumpAndSettle();
    expect(await rig.repository.find(ride.fileName), isNull);
    expect(find.text(l10n.ridesEmptyTitle), findsOneWidget);
  });

  testWidgets('Alle löschen: confirms with the count and what stays in Health, then empties', (tester) async {
    final rig = await RideRig.install(store: HealthStore.appleHealth);
    await saveSampleRide(rig.repository, start: DateTime.now().subtract(const Duration(hours: 3)));
    await saveSampleRide(rig.repository, start: DateTime.now().subtract(const Duration(days: 9)));
    await pump(tester);

    await tester.tap(find.byKey(const ValueKey('rides-menu')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('rides-delete-all')));
    await tester.pumpAndSettle();
    expect(find.text(l10n.ridesDeleteAllTitle), findsOneWidget);
    expect(
      find.text(
        '${l10n.ridesDeleteAllBodyNoHealth(2)} '
        '${l10n.ridesHealthStaysNote(healthStoreName(HealthStore.appleHealth, l10n))}',
      ),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const ValueKey('rides-delete-all-confirm')));
    await tester.pumpAndSettle();
    expect(await rig.repository.list(), isEmpty);
    expect(find.text(l10n.ridesEmptyTitle), findsOneWidget);
  });
}
