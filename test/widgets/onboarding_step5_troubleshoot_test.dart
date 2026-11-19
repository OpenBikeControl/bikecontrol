// The connection method tiles used to say nothing while a network method sat
// there not connecting. The only route to the self-test was the wizard's help
// button, which nobody presses while they still think it is working.
import 'package:bike_control/gen/l10n.dart';
import 'package:bike_control/main.dart' show OtherLocalizationsDelegate, screenshotMode;
import 'package:bike_control/pages/onboarding/onboarding_methods.dart';
import 'package:bike_control/pages/onboarding/steps/step_connection.dart';
import 'package:bike_control/utils/core.dart';
import 'package:bike_control/utils/keymap/apps/supported_app.dart';
import 'package:bike_control/utils/requirements/multi.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

import '../widget_snapshot.dart';

Future<void> main() async {
  await ensureSnapshotHarness();

  testWidgets('offers the self-test while a network method waits, and hides it once connected', (tester) async {
    screenshotMode = false;
    addTearDown(() => screenshotMode = true);

    final app = SupportedApp.supportedApps.firstWhere(
      (a) => onboardingMethodVisible(OnboardingMethod.network, a),
    );
    core.settings.setTrainerApp(app);
    await core.settings.setLastTarget(Target.otherDevice);
    final connection = onboardingMethodConnection(OnboardingMethod.network, app)!;
    // Switched on, nothing arrived yet — the state the rider is stuck in.
    core.settings.setObpMdnsEnabled(true);
    core.settings.setZwiftMdnsEmulatorEnabled(true);
    connection.isConnected.value = false;
    addTearDown(() => connection.isConnected.value = false);

    await tester.pumpWidget(
      ShadcnApp(
        debugShowCheckedModeBanner: false,
        localizationsDelegates: [
          ...ShadcnLocalizations.localizationsDelegates,
          const OtherLocalizationsDelegate(),
          AppLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.delegate.supportedLocales,
        home: Scaffold(
          child: SingleChildScrollView(
            child: Builder(
              builder: (context) => Column(children: onboardingMethodTiles(context, app: app, onUpdate: () {})),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    final label = AppLocalizations.of(tester.element(find.byType(Scaffold))).networkTroubleshootTroubleshoot;
    expect(find.text(label), findsOneWidget, reason: 'a method that is on but not connected must offer the self-test');

    // Once the trainer app arrives there is nothing to troubleshoot.
    connection.isConnected.value = true;
    await tester.pump();
    expect(find.text(label), findsNothing);
  });
}
