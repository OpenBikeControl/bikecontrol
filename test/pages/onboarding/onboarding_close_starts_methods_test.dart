// Closing the wizard with X must bring up the connection methods the rider
// already turned on, exactly like "Start riding" and "Later" do. The
// launch-time start is skipped while the wizard holds the screen, so leaving
// through X used to leave every method switched on but silent.
import 'package:bike_control/gen/l10n.dart';
import 'package:bike_control/main.dart' show OtherLocalizationsDelegate;
import 'package:bike_control/pages/onboarding/onboarding_page.dart';
import 'package:bike_control/utils/core.dart';
import 'package:bike_control/utils/settings/settings.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

import '../../widget_snapshot.dart';

Future<void> main() async {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(ensureSnapshotAppState);

  testWidgets('X starts the enabled connection methods', (tester) async {
    // Re-run from the menu: no welcome screen, straight into step 1.
    await core.settings.setOnboardingState(Settings.onboardingStateCompleted);

    var starts = 0;
    final original = onboardingStartConnectionMethods;
    onboardingStartConnectionMethods = () => starts++;
    addTearDown(() => onboardingStartConnectionMethods = original);

    tester.view.physicalSize = const Size(390, 800) * 3.0;
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ShadcnApp(
        debugShowCheckedModeBanner: false,
        localizationsDelegates: [
          ...ShadcnLocalizations.localizationsDelegates,
          const OtherLocalizationsDelegate(),
          AppLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.delegate.supportedLocales,
        home: const OnboardingPage(),
      ),
    );
    await tester.pump(const Duration(milliseconds: 500));
    expect(starts, 0, reason: 'precondition: nothing starts while the wizard is open');

    await tester.tap(find.byIcon(LucideIcons.x));
    await tester.pump();

    expect(starts, 1, reason: 'leaving through X must bring the enabled methods up');
  });
}
