// Settings → During the ride: "Record rides automatically" (on by default,
// every platform), then "Save rides to Apple Health / Health Connect" only
// where the store exists, never Pro-gated, with a hint under it when the
// selected trainer app may already save the ride itself.
import 'package:bike_control/gen/l10n.dart';
import 'package:bike_control/main.dart' show OtherLocalizationsDelegate;
import 'package:bike_control/pages/settings/settings_page.dart';
import 'package:bike_control/services/health/health_workout_channel.dart';
import 'package:bike_control/services/rides/ride_format.dart';
import 'package:bike_control/utils/iap/iap_manager.dart';
import 'package:bike_control/utils/keymap/apps/my_whoosh.dart';
import 'package:bike_control/utils/keymap/apps/zwift.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

import '../../helpers/ride_rig.dart';
import '../../widget_snapshot.dart';

Future<void> main() async {
  await ensureSnapshotHarness();

  setUp(RideRig.reset);
  tearDown(() => IAPManager.instance.setProForTesting(enabled: false));

  Future<void> pump(WidgetTester tester) async {
    await tester.pumpWidget(
      ShadcnApp(
        localizationsDelegates: const [
          ...ShadcnLocalizations.localizationsDelegates,
          OtherLocalizationsDelegate(),
          AppLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.delegate.supportedLocales,
        theme: ThemeData(colorScheme: ColorSchemes.lightSlate, radius: 0.7),
        home: SingleChildScrollView(child: const DuringRideSection()),
      ),
    );
    await tester.pumpAndSettle();
  }

  String toggle(HealthStore store) => AppLocalizations.current.ridesHealthToggle(healthStoreName(store));
  final apple = HealthStore.appleHealth;

  group('Record rides automatically', () {
    testWidgets('on by default, everywhere (no Health needed)', (tester) async {
      final rig = await RideRig.install(store: null);
      await pump(tester);

      expect(find.text(AppLocalizations.current.ridesAutoRecordTitle), findsOneWidget);
      expect(find.text(AppLocalizations.current.ridesAutoRecordSubtitle), findsOneWidget);
      expect(rig.service.autoRecord, isTrue);
    });

    testWidgets('turning it off says where the manual start is', (tester) async {
      final rig = await RideRig.install(store: null);
      await pump(tester);

      await tester.tap(find.text(AppLocalizations.current.ridesAutoRecordTitle));
      await tester.pumpAndSettle();
      expect(rig.service.autoRecord, isFalse);
      expect(find.text(AppLocalizations.current.ridesAutoRecordOffFooter), findsOneWidget);
    });

    testWidgets('comes first in During the ride', (tester) async {
      await RideRig.install();
      await pump(tester);
      final auto = tester.getTopLeft(find.text(AppLocalizations.current.ridesAutoRecordTitle)).dy;
      expect(auto, lessThan(tester.getTopLeft(find.text(toggle(apple))).dy));
    });
  });

  testWidgets('hidden where there is no Health store', (tester) async {
    await RideRig.install(store: null);
    await pump(tester);

    expect(find.text(toggle(apple)), findsNothing);
    expect(find.text(toggle(HealthStore.healthConnect)), findsNothing);
  });

  testWidgets('shown where Health exists, off until the rider says yes', (tester) async {
    final rig = await RideRig.install();
    await pump(tester);

    expect(find.text(toggle(apple)), findsOneWidget);
    expect(find.text(AppLocalizations.current.ridesHealthOnlyRecorded), findsOneWidget);
    expect(rig.service.savesToHealth, isFalse);
  });

  testWidgets('no duplicate hint for an app that does not write to Health itself', (tester) async {
    RideRig.app = MyWhoosh();
    await RideRig.install();
    await pump(tester);

    expect(find.textContaining('MyWhoosh'), findsNothing);
  });

  testWidgets('duplicate hint shown for Zwift, naming the app', (tester) async {
    RideRig.app = Zwift();
    await RideRig.install();
    await pump(tester);

    expect(
      find.text(AppLocalizations.current.ridesHealthDuplicateHint('Zwift', healthStoreName(apple))),
      findsOneWidget,
    );
  });

  testWidgets('without Pro: flipping the switch on authorizes and stores the choice, no paywall', (tester) async {
    IAPManager.instance.setProForTesting(enabled: false);
    final rig = await RideRig.install(store: HealthStore.healthConnect);
    await pump(tester);

    await tester.tap(find.text(toggle(HealthStore.healthConnect)));
    await tester.pumpAndSettle();

    expect(rig.channel!.authorizeCalls, 1);
    expect(rig.service.savesToHealth, isTrue);
  });

  testWidgets('Health Connect not installed: the row offers the install', (tester) async {
    final rig = await RideRig.install(
      store: HealthStore.healthConnect,
      availability: HealthAvailability.notInstalled,
    );
    await pump(tester);

    expect(find.text(AppLocalizations.current.ridesHealthConnectNotInstalled), findsOneWidget);
    await tester.tap(find.text(toggle(HealthStore.healthConnect)));
    await tester.pumpAndSettle();
    expect(rig.channel!.openInstallCalls, 1);
    expect(rig.channel!.authorizeCalls, 0);
  });
}
