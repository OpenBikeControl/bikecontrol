// Regression: tapping the Local method tile on step 5 opened the permission
// sheet with a context above the wizard's Scaffold ("No DrawerOverlay found")
// because _body/_footer were built with the page-level context. This walks
// the real wizard to step 5 and taps Local.
import 'package:bike_control/gen/l10n.dart';
import 'package:bike_control/main.dart' show OtherLocalizationsDelegate;
import 'package:bike_control/pages/onboarding/steps/step_app.dart' show OnboardingAppTile;
import 'package:bike_control/pages/onboarding/onboarding_page.dart';
import 'package:bike_control/utils/core.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

import 'widget_snapshot.dart';

Future<void> main() async {
  await ensureSnapshotHarness();

  testWidgets('Local tile on step 5 opens the permission sheet without crashing', (tester) async {
    // Deny the keypress-simulator permission so the sheet path runs (there's
    // no native plugin in tests) — and the toggle must then stay OFF.
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('dev.leanflutter.plugins/keypress_simulator'),
      (call) async => false,
    );
    addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        const MethodChannel('dev.leanflutter.plugins/keypress_simulator'), null));

    tester.view.physicalSize = const Size(390, 800) * 3.0;
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    // Keep the controller step from kicking off a real BLE scan in the test
    // environment — performScanning early-returns while isScanning is set.
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

    Future<void> settle() async {
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));
    }

    Future<void> tapContinue() async {
      await tester.tap(find.byType(PrimaryButton).last);
      await settle();
    }

    // Mobile now opens on the welcome screen — enter the wizard first.
    await tester.tap(find.byType(PrimaryButton).last);
    await settle();

    // Step 1: pick the first app, continue.
    await tester.tap(find.byType(OnboardingAppTile).first);
    await settle();
    await tapContinue();

    // Step 2: pick "on this device", continue.
    await tester.tap(find.byKey(const ValueKey('onboarding-where-thisDevice')));
    await settle();
    await tapContinue();

    // Step 3 (controller): the footer's "can't find" then "set up later"
    // press through to step 4 (Back sits under them now).
    final l10n = AppLocalizations.current;
    await tester.tap(find.text(l10n.onboardingCantFindController));
    await settle();
    await tester.tap(find.text(l10n.onboardingSetUpLater));
    await settle();

    // Step 4 (virtual shifting): its ghost footer action skips it.
    await tester.tap(find.textContaining(l10n.onboardingLetAppHandleVs('').split('  ').last.trim()));
    await settle();

    // Step 5: tap the Local method tile (keyboard icon).
    expect(find.byIcon(LucideIcons.keyboard), findsOneWidget, reason: 'should be on step 5');
    await tester.tap(find.byIcon(LucideIcons.keyboard));
    await settle();
    await tester.pump(const Duration(milliseconds: 400));

    expect(tester.takeException(), isNull, reason: 'Local toggle must not crash (DrawerOverlay regression)');
    // Permissions were denied — Local must not report itself enabled.
    expect(core.settings.getLocalEnabled(), isFalse,
        reason: 'Local must stay off when its permissions are not granted');
  });
}
