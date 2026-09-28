import 'package:bike_control/gen/l10n.dart';
import 'package:bike_control/main.dart' show OtherLocalizationsDelegate;
import 'package:bike_control/widgets/ui/app_theme.dart';
import 'package:bike_control/widgets/ui/help_button.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

import '../../widget_snapshot.dart';

// MediaQuery.viewPadding is already in logical pixels. The pill divided it by
// the device pixel ratio as well, so on a 3x phone it cleared only a third of
// the home indicator.
Future<void> main() async {
  await ensureSnapshotHarness();

  Future<void> pump(WidgetTester tester, {required double bottomInset, required double dpr}) async {
    tester.view.physicalSize = const Size(390, 844) * dpr;
    tester.view.devicePixelRatio = dpr;
    tester.view.viewPadding = FakeViewPadding(bottom: bottomInset * dpr);
    tester.view.padding = FakeViewPadding(bottom: bottomInset * dpr);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ShadcnApp(
        localizationsDelegates: [
          ...ShadcnLocalizations.localizationsDelegates,
          const OtherLocalizationsDelegate(),
          AppLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.delegate.supportedLocales,
        theme: BkTheme.build(Brightness.light, compact: true),
        home: const Align(alignment: Alignment.bottomCenter, child: HelpButton(isMobile: true)),
      ),
    );
    await tester.pump();
  }

  for (final dpr in [1.0, 2.0, 3.0]) {
    testWidgets('mobile pill clears the whole bottom inset at ${dpr}x', (tester) async {
      await pump(tester, bottomInset: 0, dpr: dpr);
      final bare = tester.getSize(find.byType(HelpButton)).height;

      await pump(tester, bottomInset: 34, dpr: dpr);
      final inset = tester.getSize(find.byType(HelpButton)).height;

      expect(inset - bare, closeTo(34, 0.5));
    });
  }

  testWidgets('mobileFooterClearance covers the pill and the inset', (tester) async {
    await pump(tester, bottomInset: 34, dpr: 3);
    final context = tester.element(find.byType(HelpButton));
    final pill = tester.getSize(find.byType(HelpButton)).height;
    expect(HelpButton.mobileFooterClearance(context), greaterThanOrEqualTo(pill));
  });
}
