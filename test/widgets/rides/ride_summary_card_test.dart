import 'package:bike_control/gen/l10n.dart';
import 'package:bike_control/main.dart' show OtherLocalizationsDelegate;
import 'package:bike_control/pages/rides/ride_details_page.dart';
import 'package:bike_control/services/health/health_workout_channel.dart';
import 'package:bike_control/services/rides/ride_format.dart';
import 'package:bike_control/utils/keymap/apps/my_whoosh.dart';
import 'package:bike_control/utils/keymap/apps/rouvy.dart';
import 'package:bike_control/utils/keymap/apps/zwift.dart';
import 'package:bike_control/utils/requirements/multi.dart';
import 'package:bike_control/widgets/rides/ride_chart.dart';
import 'package:bike_control/widgets/rides/ride_summary_card.dart';
import 'package:bike_control/widgets/ui/bk_pill_button.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

import '../../helpers/ride_fixtures.dart';
import '../../helpers/ride_rig.dart';
import '../../widget_snapshot.dart';

Future<void> main() async {
  await ensureSnapshotHarness();
  late AppLocalizations l10n;
  setUpAll(() async => l10n = await AppLocalizations.load(const Locale('en')));
  setUp(RideRig.reset);

  Future<void> pump(WidgetTester tester, {bool wide = false}) async {
    tester.view.physicalSize = Size(wide ? 640 : 390, 1400);
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
              child: RideSummaryCard(wide: wide),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<RideRig> withRide({
    HealthStore? store = HealthStore.appleHealth,
    Map<String, Object> prefs = const {},
    bool speed = true,
  }) async {
    final rig = await RideRig.install(store: store, prefs: prefs);
    final ride = await saveSampleRide(rig.repository, speed: speed);
    await rig.prefs.setSummaryRide(ride.fileName);
    await rig.service.start(detect: false);
    return rig;
  }

  BkPillButton pill(WidgetTester tester, String key) => tester.widget<BkPillButton>(find.byKey(ValueKey(key)));

  testWidgets('nothing without a finished ride', (tester) async {
    await RideRig.install();
    await pump(tester);
    expect(find.byKey(const ValueKey('ride-summary-card')), findsNothing);
  });

  testWidgets('data only: when, where from, the four numbers, the strips, gear changes', (tester) async {
    await withRide(prefs: {'health_rides_prompt_dismissed': true});
    await pump(tester);

    expect(find.textContaining('${l10n.ridesToday} · '), findsOneWidget);
    expect(find.text('KICKR CORE · MyWhoosh'), findsOneWidget);
    expect(find.textContaining('42:18', findRichText: true), findsOneWidget);
    for (final key in ['duration', 'distance', 'power', 'work']) {
      expect(find.byKey(ValueKey('ride-summary-$key')), findsOneWidget, reason: key);
    }
    expect(find.byType(RideChartView), findsOneWidget);
    expect(find.byKey(const ValueKey('ride-summary-gears')), findsOneWidget);
    expect(find.byKey(const ValueKey('ride-health-question')), findsNothing);
  });

  testWidgets('no speed source: no Distanz column', (tester) async {
    await withRide(speed: false);
    await pump(tester);
    expect(find.byKey(const ValueKey('ride-summary-distance')), findsNothing);
    expect(find.byKey(const ValueKey('ride-summary-work')), findsOneWidget);
  });

  testWidgets('× hides it for good', (tester) async {
    final rig = await withRide();
    await pump(tester);
    await tester.tap(find.byKey(const ValueKey('ride-summary-dismiss')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('ride-summary-card')), findsNothing);
    expect(rig.prefs.summaryRide, isNull);
  });

  group('first-ride Health question', () {
    testWidgets('asks once; Ja is the default, and writes this ride', (tester) async {
      RideRig.app = MyWhoosh();
      final rig = await withRide();
      await pump(tester);

      final store = healthStoreName(HealthStore.appleHealth, l10n);
      expect(find.text(l10n.ridesAskHealth(store)), findsOneWidget);
      expect(pill(tester, 'ride-health-yes').secondary, isFalse, reason: 'Ja is filled');
      expect(pill(tester, 'ride-health-no').secondary, isTrue);

      await tester.tap(find.byKey(const ValueKey('ride-health-yes')));
      await tester.pumpAndSettle();
      expect(rig.channel!.saved, hasLength(1));
      expect(find.byKey(const ValueKey('ride-health-question')), findsNothing);
      expect(rig.prefs.saveToHealth, isTrue);
    });

    for (final app in [Zwift(), Rouvy()]) {
      testWidgets('${app.name} on this device: Nein is the default, with the duplicate hint', (tester) async {
        RideRig.app = app;
        RideRig.target = Target.thisDevice;
        await withRide();
        await pump(tester);

        expect(pill(tester, 'ride-health-no').secondary, isFalse, reason: 'Nein is filled');
        expect(pill(tester, 'ride-health-yes').secondary, isTrue);
        expect(
          find.text(l10n.ridesHealthDuplicateHint(app.name, healthStoreName(HealthStore.appleHealth, l10n))),
          findsOneWidget,
        );
      });
    }

    testWidgets('Nein closes it for good and writes nothing', (tester) async {
      final rig = await withRide();
      await pump(tester);
      await tester.tap(find.byKey(const ValueKey('ride-health-no')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('ride-health-question')), findsNothing);
      expect(rig.prefs.saveToHealth, isFalse);
      expect(rig.prefs.healthQuestionAnswered, isTrue);
      expect(rig.channel!.saved, isEmpty);
    });

    testWidgets('Android asks for Health Connect', (tester) async {
      await withRide(store: HealthStore.healthConnect);
      await pump(tester);
      expect(find.text(l10n.ridesAskHealth('Health Connect')), findsOneWidget);
    });

    testWidgets('never on desktop', (tester) async {
      await withRide(store: null);
      await pump(tester);
      expect(find.byKey(const ValueKey('ride-health-question')), findsNothing);
    });
  });

  testWidgets('Verwerfen asks first, then removes the ride', (tester) async {
    final rig = await withRide();
    await pump(tester);
    final name = rig.service.summaryRide.value!.fileName;
    await tester.tap(find.byKey(const ValueKey('ride-summary-discard')));
    await tester.pumpAndSettle();
    expect(find.text(l10n.healthRideDiscardConfirmTitle), findsOneWidget);
    await tester.tap(find.text(l10n.healthRideDiscardConfirmAction));
    await tester.pumpAndSettle();
    expect(await rig.repository.find(name), isNull);
    expect(find.byKey(const ValueKey('ride-summary-card')), findsNothing);
  });

  testWidgets('Details opens the ride; Exportieren opens the sheet', (tester) async {
    await withRide();
    await pump(tester);
    await tester.tap(find.byKey(const ValueKey('ride-summary-export')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('ride-export')), findsOneWidget);
    await tester.tap(find.text(l10n.cancel));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('ride-summary-details')));
    await tester.pumpAndSettle();
    expect(find.byType(RideDetailsPage), findsOneWidget);
  });

  testWidgets('desktop: Verwerfen as text, Export as a menu', (tester) async {
    await withRide(store: null);
    await pump(tester, wide: true);
    expect(find.byKey(const ValueKey('ride-export-menu')), findsOneWidget);
    expect(find.text(l10n.healthRideDiscard), findsOneWidget);
  });

  testWidgets("a tapped ride notification opens that ride's Details", (tester) async {
    final rig = await withRide();
    final ride = rig.service.summaryRide.value!;
    await pump(tester);
    final navigator = tester.state<NavigatorState>(find.byType(Navigator).first);
    await openRideFromNotification(rideNotificationPayload(ride), navigator: navigator);
    await tester.pumpAndSettle();
    expect(find.byType(RideDetailsPage), findsOneWidget);
  });
}
