// Regression: shadcn's DrawerOverlay is created by Scaffold, so opening a
// sheet with the page State's own context (which sits above the Scaffold)
// asserted "No DrawerOverlay found in the widget tree". The wizard must open
// all sheets through a context captured under its Scaffold.
import 'package:bike_control/gen/l10n.dart';
import 'package:bike_control/main.dart' show OtherLocalizationsDelegate;
import 'package:bike_control/pages/onboarding/onboarding_page.dart';
import 'package:bike_control/widgets/guided_operation_sheet.dart' show StageBadge;
import 'package:flutter_test/flutter_test.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

import 'widget_snapshot.dart';

Future<void> main() async {
  await ensureSnapshotHarness();

  testWidgets('help sheet opens from the wizard page', (tester) async {
    tester.view.physicalSize = const Size(380, 760) * 3.0;
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
        theme: ThemeData(colorScheme: ColorSchemes.lightSlate, radius: 0.7),
        // Prod pushes the wizard as a fullscreenDialog MaterialPageRoute —
        // reproduce that exactly instead of mounting it as home.
        home: Builder(
          builder: (context) => GhostButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(fullscreenDialog: true, builder: (_) => const OnboardingPage()),
            ),
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.tap(find.text('open'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    // Mobile opens on the welcome screen — enter the wizard first.
    await tester.tap(find.byType(PrimaryButton).last);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    // Mobile header Help button.
    final help = find.byIcon(LucideIcons.circleHelp).first;
    await tester.tap(help);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(tester.takeException(), isNull, reason: 'opening the help sheet must not crash');
    // The help sheet body leads with a StageBadge — presence proves the sheet
    // actually rendered inside a DrawerOverlay.
    expect(find.byType(StageBadge), findsWidgets);
  });
}
