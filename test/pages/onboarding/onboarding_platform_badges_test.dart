// A badge naming a platform only makes sense on that platform: "Best on iOS"
// on an Android phone or a Windows PC reads as "not for you".
import 'package:bike_control/gen/l10n.dart';
import 'package:bike_control/main.dart' show OtherLocalizationsDelegate;
import 'package:bike_control/pages/onboarding/steps/step_connection.dart';
import 'package:bike_control/utils/actions/base_actions.dart';
import 'package:bike_control/utils/core.dart';
import 'package:bike_control/utils/host_platform.dart';
import 'package:bike_control/utils/keymap/apps/rouvy.dart';
import 'package:bike_control/utils/requirements/multi.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

import '../../widget_snapshot.dart';

Future<void> main() async {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(ensureSnapshotAppState);

  tearDown(() {
    debugHostPlatformOverride = null;
    core.actionHandler = StubActions();
  });

  Future<AppLocalizations> pump(WidgetTester tester, {required TargetPlatform platform, required Target target}) async {
    debugHostPlatformOverride = platform;
    final app = Rouvy();
    core.settings.setTrainerApp(app);
    await core.settings.setLastTarget(target);
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
              builder: (c) => onboardingConnectionBody(
                c,
                app: app,
                target: target,
                hasTrainer: false,
                trainerName: null,
                onUpdate: () {},
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(seconds: 1));
    return AppLocalizations.of(tester.element(find.byType(SingleChildScrollView)));
  }

  for (final platform in [TargetPlatform.android, TargetPlatform.windows, TargetPlatform.macOS]) {
    testWidgets('${platform.name}: no "Best on iOS" on the Bluetooth tile', (tester) async {
      final l = await pump(tester, platform: platform, target: Target.otherDevice);
      expect(find.text(l.onboardingMethodBluetooth), findsOneWidget, reason: 'precondition: tile shown');
      expect(find.text(l.onboardingMethodBluetoothBadge), findsNothing);
    });
  }

  testWidgets('iOS: the Bluetooth tile keeps its badge', (tester) async {
    final l = await pump(tester, platform: TargetPlatform.iOS, target: Target.otherDevice);
    expect(find.text(l.onboardingMethodBluetoothBadge), findsOneWidget);
  });

  testWidgets('iOS, this device: the disabled Local tile drops its platform list', (tester) async {
    final l = await pump(tester, platform: TargetPlatform.iOS, target: Target.thisDevice);
    expect(find.text(l.onboardingMethodLocal), findsOneWidget, reason: 'precondition: tile shown');
    expect(find.text(l.onboardingMethodLocalBadge), findsNothing);
  });
}
