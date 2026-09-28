// The phone layout at 390x844, at the default text size and at 1.3x: nothing
// overflows, and every tappable is labelled.
//
// Not asserted here: Android's 48 dp target. shadcn's text buttons are
// 35-38 px tall on a phone (28-32 px for size.small) even with the mobile
// scale; the icon-only buttons are checked against 48 dp where they're built.
import 'package:bike_control/gen/l10n.dart';
import 'package:bike_control/main.dart' show OtherLocalizationsDelegate;
import 'package:bike_control/pages/home/home_page.dart';
import 'package:bike_control/pages/onboarding/onboarding_page.dart';
import 'package:bike_control/utils/core.dart';
import 'package:bike_control/utils/keymap/apps/my_whoosh.dart';
import 'package:bike_control/utils/settings/settings.dart';
import 'package:bike_control/widgets/ui/app_theme.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

import '../../widget_snapshot.dart';

Future<void> main() async {
  await ensureSnapshotHarness();

  Future<void> pumpPhone(WidgetTester tester, Widget home, {required double textScale}) async {
    tester.view.physicalSize = const Size(390, 844) * 3.0;
    tester.view.devicePixelRatio = 3.0;
    tester.platformDispatcher.textScaleFactorTestValue = textScale;
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await tester.pumpWidget(
      ShadcnApp(
        debugShowCheckedModeBanner: false,
        localizationsDelegates: [
          ...ShadcnLocalizations.localizationsDelegates,
          const OtherLocalizationsDelegate(),
          AppLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.delegate.supportedLocales,
        theme: BkTheme.build(Brightness.light),
        home: home,
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1600));
  }

  for (final textScale in [1.0, 1.3]) {
    testWidgets('home fits a phone at ${textScale}x text and labels every tap target', (tester) async {
      core.settings.setTrainerApp(MyWhoosh());
      final handle = tester.ensureSemantics();
      await pumpPhone(
        tester,
        Scaffold(child: SingleChildScrollView(child: HomePage(isMobile: true, onUpdate: () {}))),
        textScale: textScale,
      );
      expect(tester.takeException(), isNull);
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      handle.dispose();
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('onboarding fits a phone at ${textScale}x text and labels every tap target', (tester) async {
      await core.settings.setOnboardingState(Settings.onboardingStatePending);
      core.connection.isScanning.value = true;
      addTearDown(() => core.connection.isScanning.value = false);
      final handle = tester.ensureSemantics();
      await pumpPhone(tester, const OnboardingPage(), textScale: textScale);
      expect(tester.takeException(), isNull);
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      handle.dispose();
      await tester.pumpWidget(const SizedBox());
    });
  }
}
