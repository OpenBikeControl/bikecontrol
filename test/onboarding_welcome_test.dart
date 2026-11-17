// The wizard opens on the welcome screen on every platform — desktop riders
// used to be dropped straight into step 1's rail, so the one screen that says
// what BikeControl does and how long setup takes was the one they never saw.
// "I'll set this up later" must record completion so a rider who declines
// isn't asked again on the next launch.
import 'package:bike_control/gen/l10n.dart';
import 'package:bike_control/main.dart' show OtherLocalizationsDelegate;
import 'package:bike_control/pages/onboarding/onboarding_page.dart';
import 'package:bike_control/pages/onboarding/steps/step_app.dart' show OnboardingAppTile;
import 'package:bike_control/pages/onboarding/steps/step_welcome.dart';
import 'package:bike_control/utils/core.dart';
import 'package:bike_control/utils/settings/settings.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

import 'widget_snapshot.dart';

Future<void> main() async {
  await ensureSnapshotHarness();

  Future<void> pumpWizard(WidgetTester tester, Size size) async {
    tester.view.physicalSize = size * 3.0;
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    core.connection.isScanning.value = true;
    addTearDown(() => core.connection.isScanning.value = false);
    await tester.pumpWidget(
      ShadcnApp(
        debugShowCheckedModeBanner: false,
        localizationsDelegates: [
          ...ShadcnLocalizations.localizationsDelegates,
          const OtherLocalizationsDelegate(),
          AppLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.delegate.supportedLocales,
        theme: ThemeData(colorScheme: ColorSchemes.lightSlate, radius: 0.7),
        home: const OnboardingPage(),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1600));
  }

  testWidgets('mobile opens on the welcome screen and can enter the wizard', (tester) async {
    await core.settings.setOnboardingState(Settings.onboardingStatePending);
    await pumpWizard(tester, const Size(390, 800));

    expect(find.byType(OnboardingWelcome), findsOneWidget);
    expect(find.byType(OnboardingAppTile), findsNothing, reason: 'step 1 comes after the welcome screen');

    await tester.tap(find.byType(PrimaryButton).last);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byType(OnboardingWelcome), findsNothing);
    expect(find.byType(OnboardingAppTile), findsWidgets);
  });

  testWidgets('desktop opens on the welcome screen too, and can enter the wizard', (tester) async {
    await core.settings.setOnboardingState(Settings.onboardingStatePending);
    await pumpWizard(tester, const Size(1100, 800));

    expect(find.byType(OnboardingWelcome), findsOneWidget);
    expect(find.byType(OnboardingAppTile), findsNothing, reason: 'step 1 comes after the welcome screen');

    await tester.tap(find.byType(PrimaryButton).last);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byType(OnboardingWelcome), findsNothing);
    expect(find.byType(OnboardingAppTile), findsWidgets);
  });

  testWidgets('the welcome screen keeps a readable measure on a wide window', (tester) async {
    await core.settings.setOnboardingState(Settings.onboardingStatePending);
    await pumpWizard(tester, const Size(1400, 900));

    // Capped to the same width the wizard's own body uses, so stepping from
    // here into the rail doesn't snap the text narrower.
    final width = tester.getSize(find.byType(OnboardingWelcome)).width;
    expect(width, 1400);
    final column = tester.getSize(find.byType(Wrap).first).width;
    expect(column, lessThanOrEqualTo(kOnboardingBodyMaxWidth));
  });

  testWidgets('with a very large system text size the start button can still be reached', (tester) async {
    // iOS accessibility text sizes blow the welcome copy up far past the
    // screen height; the page must scroll instead of pushing the buttons off
    // screen, or the rider is stuck on the welcome screen.
    tester.platformDispatcher.textScaleFactorTestValue = 3.0;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await core.settings.setOnboardingState(Settings.onboardingStatePending);
    await pumpWizard(tester, const Size(375, 812));

    expect(tester.takeException(), isNull, reason: 'the welcome page must not overflow');
    final start = find.byType(PrimaryButton).last;
    await tester.ensureVisible(start);
    await tester.pump(const Duration(milliseconds: 500));
    expect(tester.getRect(start).bottom, lessThanOrEqualTo(812));

    await tester.tap(start);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byType(OnboardingWelcome), findsNothing);
    expect(find.byType(OnboardingAppTile), findsWidgets);
  });

  testWidgets('"set up later" records completion so the wizard stops nagging', (tester) async {
    await core.settings.setOnboardingState(Settings.onboardingStatePending);
    await pumpWizard(tester, const Size(390, 800));

    await tester.tap(find.byType(GhostButton).last);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(core.settings.getOnboardingState(), Settings.onboardingStateCompleted);
  });
}
