@Tags(['screenshots'])
library;

import 'dart:io';

import 'package:bike_control/bluetooth/emulation/emulated_ble_platform.dart';
import 'package:bike_control/gen/l10n.dart';
import 'package:bike_control/main.dart' show OtherLocalizationsDelegate, navigatorKey, screenshotMode;
import 'package:bike_control/pages/click_v2_onboarding.dart';
import 'package:bike_control/utils/actions/base_actions.dart';
import 'package:bike_control/utils/core.dart';
import 'package:bike_control/widgets/ui/app_theme.dart';
import 'package:flutter/material.dart' as m;
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_screenshot/golden_screenshot.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:universal_ble/universal_ble.dart';

import 'widget_snapshot.dart';
import 'widget_to_png.dart';

/// The Zwift Click V2 setup explainer in each of its states, rendered to PNGs
/// for review. Run:
/// `flutter test --run-skipped test/click_v2_screenshot_test.dart`
/// Output: /tmp/click-v2-shots/ (override with CLICK_V2_SHOTS).
Future<void> main() async {
  await ensureSnapshotHarness();
  screenshotMode = false;
  UniversalBle.setInstance(FakeUniversalBlePlatform());
  core.actionHandler = StubActions();

  final outDir = Platform.environment['CLICK_V2_SHOTS'] ?? '/tmp/click-v2-shots';
  const phone = Size(390, 844);
  const desktop = Size(1160, 860);

  /// What to tap before the capture, in order.
  final states = <String, List<String>>{
    'a_nothing_chosen': [],
    'b_no_unlock': ['click-onboarding-option-no-unlock'],
    'c_no_unlock_with_left': ['click-onboarding-option-no-unlock', 'click-onboarding-left-toggle'],
    'd_zwift': ['click-onboarding-option-zwift'],
  };

  Future<void> shoot(
    WidgetTester tester,
    String name, {
    required Size size,
    required double dpr,
    required Locale locale,
    required List<String> taps,
    Brightness brightness = Brightness.light,
  }) async {
    tester.view.physicalSize = size * dpr;
    tester.view.devicePixelRatio = dpr;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await AppLocalizations.load(locale);
    final key = GlobalKey();
    final app = RepaintBoundary(
      key: key,
      child: ShadcnApp(
        navigatorKey: navigatorKey,
        debugShowCheckedModeBanner: false,
        locale: locale,
        localizationsDelegates: [
          ...ShadcnLocalizations.localizationsDelegates,
          const OtherLocalizationsDelegate(),
          AppLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.delegate.supportedLocales,
        scaling: BkTheme.scaling,
        theme: snapshotTheme(Brightness.light),
        darkTheme: snapshotTheme(Brightness.dark),
        themeMode: brightness == Brightness.dark ? ThemeMode.dark : ThemeMode.light,
        materialTheme: m.ThemeData(),
        home: const ClickV2OnboardingPage(),
      ),
    );
    await tester.pumpWidget(app);
    await tester.pump();
    await tester.loadAssets();
    await tester.binding.reassembleApplication();
    await remountWithLoadedFonts(tester, app);
    for (final tap in taps) {
      final finder = tap == 'click-onboarding-left-toggle'
          ? find.descendant(of: find.byKey(ValueKey(tap)), matching: find.byType(Switch))
          : find.byKey(ValueKey(tap));
      await tester.ensureVisible(finder);
      await tester.tap(finder);
      await tester.pump(const Duration(milliseconds: 500));
    }
    // The hero's badges loop forever, so settle by time, not pumpAndSettle.
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 250));
    }
    await tester.loadAssets();
    await tester.pump();
    await captureBoundaryToPng(tester, key, outputPath: '$outDir/$name.png');
    await tester.pumpWidget(const SizedBox());
  }

  for (final entry in states.entries) {
    testWidgets('phone en ${entry.key}', (tester) async {
      await shoot(
        tester,
        'phone_en_${entry.key}',
        size: phone,
        dpr: 3,
        locale: const Locale('en'),
        taps: entry.value,
      );
    });
    testWidgets('desktop de ${entry.key}', (tester) async {
      await shoot(
        tester,
        'desktop_de_${entry.key}',
        size: desktop,
        dpr: 2,
        locale: const Locale('de'),
        taps: entry.value,
      );
    });
  }

  testWidgets('phone en dark, left side on', (tester) async {
    await shoot(
      tester,
      'phone_en_dark_c_no_unlock_with_left',
      size: phone,
      dpr: 3,
      locale: const Locale('en'),
      taps: states['c_no_unlock_with_left']!,
      brightness: Brightness.dark,
    );
  });
}
