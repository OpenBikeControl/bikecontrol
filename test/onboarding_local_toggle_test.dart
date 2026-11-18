// Regression: tapping the Local method tile opened the permission sheet with a
// context above the wizard's Scaffold ("No DrawerOverlay found") because
// _body/_footer were built with the page-level context. This walks the real
// wizard to the ride step and taps Local among its connection methods.
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

  testWidgets('Local tile on the ride step opens the permission sheet without crashing', (tester) async {
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

    // Step 1: pick the first app and "on this device", continue.
    await tester.tap(find.byType(OnboardingAppTile).first);
    await settle();
    await tester.ensureVisible(find.byKey(const ValueKey('onboarding-where-thisDevice')));
    await tester.tap(find.byKey(const ValueKey('onboarding-where-thisDevice')));
    await settle();
    await tapContinue();

    // Step 2 (controller + trainer): skip the trainer.
    await tester.tap(find.byKey(const ValueKey('onboarding-gear-skip-trainer')));
    await settle();

    // Step 3: unfold the connection methods if they are folded, tap Local.
    if (find.byIcon(LucideIcons.keyboard).evaluate().isEmpty) {
      await tester.ensureVisible(find.byKey(const ValueKey('onboarding-methods-toggle')));
      await tester.tap(find.byKey(const ValueKey('onboarding-methods-toggle')));
      await settle();
    }
    expect(find.byIcon(LucideIcons.keyboard), findsOneWidget, reason: 'should be on the ride step');
    await tester.ensureVisible(find.byIcon(LucideIcons.keyboard));
    await tester.tap(find.byIcon(LucideIcons.keyboard));
    await settle();
    await tester.pump(const Duration(milliseconds: 400));

    expect(tester.takeException(), isNull, reason: 'Local toggle must not crash (DrawerOverlay regression)');
    // Permissions were denied — Local must not report itself enabled.
    expect(core.settings.getLocalEnabled(), isFalse,
        reason: 'Local must stay off when its permissions are not granted');
  });
}
