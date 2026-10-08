import 'package:bike_control/gen/l10n.dart';
import 'package:bike_control/main.dart' show OtherLocalizationsDelegate;
import 'package:bike_control/pages/shell/app_shell.dart';
import 'package:bike_control/widgets/ui/app_theme.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

import '../../widget_snapshot.dart';

// The phone's bottom tab bar has to clear the whole home indicator, in logical
// pixels (MediaQuery's insets already are — dividing by the pixel ratio again
// once left the old help pill clearing only a third of it on a 3x phone).
Future<void> main() async {
  await ensureSnapshotHarness();

  Future<void> pump(
    WidgetTester tester,
    ShellController shell, {
    required double bottomInset,
    required double dpr,
  }) async {
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
        theme: BkTheme.build(Brightness.light),
        home: Align(
          alignment: Alignment.bottomCenter,
          child: ShellTabBar(controller: shell),
        ),
      ),
    );
    await tester.pump();
  }

  for (final dpr in [1.0, 2.0, 3.0]) {
    testWidgets('the tab bar clears the whole bottom inset at ${dpr}x', (tester) async {
      final shell = ShellController();
      addTearDown(shell.dispose);
      await pump(tester, shell, bottomInset: 0, dpr: dpr);
      final bare = tester.getSize(find.byType(ShellTabBar)).height;

      await pump(tester, shell, bottomInset: 34, dpr: dpr);
      final inset = tester.getSize(find.byType(ShellTabBar)).height;

      expect(inset - bare, closeTo(34, 0.5));
      await tester.pumpWidget(const SizedBox());
    });
  }

  testWidgets('the icons sit a breath below the bar\'s top line, not against it', (tester) async {
    final shell = ShellController();
    addTearDown(shell.dispose);
    await pump(tester, shell, bottomInset: 0, dpr: 1);
    final bar = tester.getRect(find.byType(ShellTabBar));
    final firstItem = tester.getRect(find.byType(ShellNavItem).first);
    expect(firstItem.top - bar.top, greaterThanOrEqualTo(8));
    await tester.pumpWidget(const SizedBox());
  });
}
