// Android 11 and older only find Bluetooth devices with the Location
// permission, so the system asks for Location right after the step promised
// BikeControl "never uses this for location". The step explains why on those
// phones. The scanning screen gives its "powered on, in range" advice once.
import 'package:bike_control/gen/l10n.dart';
import 'package:bike_control/main.dart' show OtherLocalizationsDelegate;
import 'package:bike_control/pages/onboarding/onboarding_models.dart';
import 'package:bike_control/pages/onboarding/steps/step_controller.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

import '../../widget_snapshot.dart';

Future<void> main() async {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(ensureSnapshotAppState);

  Future<AppLocalizations> pump(WidgetTester tester, ControllerPhase phase, {bool locationNeeded = false}) async {
    await tester.pumpWidget(
      ShadcnApp(
        localizationsDelegates: [
          ...ShadcnLocalizations.localizationsDelegates,
          const OtherLocalizationsDelegate(),
          AppLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.delegate.supportedLocales,
        home: Scaffold(
          child: SingleChildScrollView(
            child: Builder(
              builder: (c) => onboardingControllerBody(
                c,
                phase: phase,
                devices: const [],
                appName: 'Zwift',
                locationNeededForBluetooth: locationNeeded,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(seconds: 1));
    return AppLocalizations.of(tester.element(find.byType(SingleChildScrollView)));
  }

  testWidgets('Android 11 or older: explains the Location prompt', (tester) async {
    final l = await pump(tester, ControllerPhase.permission, locationNeeded: true);
    expect(find.text(l.onboardingBluetoothLocationNote), findsOneWidget);
  });

  testWidgets('newer systems: no Location explanation', (tester) async {
    final l = await pump(tester, ControllerPhase.permission);
    expect(find.text(l.onboardingBluetoothLocationNote), findsNothing);
  });

  testWidgets('scanning: the hint appears once', (tester) async {
    final l = await pump(tester, ControllerPhase.scanning);
    expect(find.text(l.onboardingScanSubtitle), findsOneWidget);
    expect(find.text(l.scanningForDevices), findsNothing, reason: 'same advice, said twice');
  });
}
