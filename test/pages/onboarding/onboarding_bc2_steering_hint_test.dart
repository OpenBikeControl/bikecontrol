// Over Bluetooth MyWhoosh takes BikeControl as a steering device, which is not
// where a rider looks for a controller — both tiles say where to find it.
import 'package:bike_control/gen/l10n.dart';
import 'package:bike_control/main.dart' show OtherLocalizationsDelegate, debugKeepsTrainerAppNamesInScreenshotMode;
import 'package:bike_control/pages/onboarding/steps/step_connection.dart';
import 'package:bike_control/utils/actions/base_actions.dart';
import 'package:bike_control/utils/core.dart';
import 'package:bike_control/utils/keymap/apps/my_whoosh.dart';
import 'package:bike_control/utils/keymap/apps/rouvy.dart';
import 'package:bike_control/utils/keymap/apps/supported_app.dart';
import 'package:bike_control/utils/requirements/multi.dart';
import 'package:bike_control/widgets/apps/cycplus_bc2_ble_tile.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

import '../../widget_snapshot.dart';

Future<void> main() async {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    await ensureSnapshotAppState();
    debugKeepsTrainerAppNamesInScreenshotMode = true;
  });
  tearDownAll(() => debugKeepsTrainerAppNamesInScreenshotMode = false);

  tearDown(() => core.actionHandler = StubActions());

  Future<AppLocalizations> pump(WidgetTester tester, SupportedApp app, Widget Function(BuildContext) child) async {
    core.settings.setTrainerApp(app);
    await core.settings.setLastTarget(Target.otherDevice);
    await tester.pumpWidget(
      ShadcnApp(
        localizationsDelegates: [
          ...ShadcnLocalizations.localizationsDelegates,
          const OtherLocalizationsDelegate(),
          AppLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.delegate.supportedLocales,
        home: Scaffold(
          child: SingleChildScrollView(child: Builder(builder: child)),
        ),
      ),
    );
    await tester.pump(const Duration(seconds: 1));
    return AppLocalizations.of(tester.element(find.byType(SingleChildScrollView)));
  }

  Widget onboardingTiles(BuildContext c) => Column(
    children: onboardingMethodTiles(c, app: core.settings.getTrainerApp()!, onUpdate: () {}),
  );

  testWidgets('onboarding: the MyWhoosh Bluetooth tile says to add it as a steering device', (tester) async {
    final l = await pump(tester, MyWhoosh(), onboardingTiles);
    expect(find.text(l.onboardingMethodBluetooth), findsOneWidget, reason: 'precondition: tile shown');
    expect(find.text(l.addBikeControlAsSteeringDevice('MyWhoosh')), findsOneWidget);
  });

  testWidgets('onboarding: other apps get no steering hint', (tester) async {
    final l = await pump(tester, Rouvy(), onboardingTiles);
    expect(find.text(l.onboardingMethodBluetooth), findsOneWidget, reason: 'precondition: tile shown');
    expect(find.textContaining(l.addBikeControlAsSteeringDevice('Rouvy')), findsNothing);
  });

  testWidgets('trainer tile: the hint shows before switching on', (tester) async {
    await core.settings.setBc2BleEnabled(false);
    final l = await pump(tester, MyWhoosh(), (_) => const CycplusBc2BluetoothTile(small: false));
    expect(find.textContaining(l.addBikeControlAsSteeringDevice('MyWhoosh')), findsOneWidget);
  });
}
