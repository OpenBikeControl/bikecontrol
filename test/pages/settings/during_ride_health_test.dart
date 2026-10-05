// "Save rides to Apple Health / Health Connect" in Settings → During the
// ride: only where the store exists, never Pro-gated, and a hint under it
// when the selected trainer app may already save the ride itself.
import 'package:bike_control/gen/l10n.dart';
import 'package:bike_control/main.dart' show OtherLocalizationsDelegate;
import 'package:bike_control/pages/settings/settings_page.dart';
import 'package:bike_control/services/health/health_workout_channel.dart';
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

  testWidgets('hidden where there is no Health store', (tester) async {
    await RideRig.install(store: null);
    await pump(tester);

    expect(find.text(AppLocalizations.current.healthRideToggleTitle), findsNothing);
  });

  testWidgets('shown where Health exists, off until the rider says yes', (tester) async {
    final rig = await RideRig.install();
    await pump(tester);

    expect(find.text(AppLocalizations.current.healthRideToggleTitle), findsOneWidget);
    expect(rig.service.savesToHealth, isFalse);
  });

  testWidgets('no duplicate hint for an app that does not write to Health itself', (tester) async {
    RideRig.app = MyWhoosh();
    await RideRig.install();
    await pump(tester);

    expect(find.text(AppLocalizations.current.healthRideDuplicateHint('MyWhoosh')), findsNothing);
  });

  testWidgets('duplicate hint shown for Zwift, naming the app', (tester) async {
    RideRig.app = Zwift();
    await RideRig.install();
    await pump(tester);

    expect(find.text(AppLocalizations.current.healthRideDuplicateHint('Zwift')), findsOneWidget);
  });

  testWidgets('without Pro: flipping the switch on authorizes and stores the choice, no paywall', (tester) async {
    IAPManager.instance.setProForTesting(enabled: false);
    final rig = await RideRig.install(store: HealthStore.healthConnect);
    await pump(tester);

    await tester.tap(find.text(AppLocalizations.current.healthRideToggleTitle));
    await tester.pumpAndSettle();

    expect(rig.channel!.authorizeCalls, 1);
    expect(rig.service.savesToHealth, isTrue);
  });
}
