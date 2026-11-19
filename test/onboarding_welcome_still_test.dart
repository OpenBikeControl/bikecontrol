// The welcome screen fits a phone, so a drag must not move it. Its scroll view
// (there for very large text sizes) was the primary one, and a primary scroll
// view can always be dragged: with the app's bouncing physics the whole screen
// slid about under a finger with nothing below it.
import 'package:bike_control/gen/l10n.dart';
import 'package:bike_control/main.dart' show OtherLocalizationsDelegate;
import 'package:bike_control/pages/onboarding/steps/step_welcome.dart';
import 'package:bike_control/widgets/ui/app_theme.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

import 'widget_snapshot.dart';

Future<void> main() async {
  await ensureSnapshotHarness();

  testWidgets('a drag does not move the welcome screen when it fits', (tester) async {
    tester.view.physicalSize = const Size(396, 909);
    tester.view.devicePixelRatio = 1;
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
        home: Scaffold(child: OnboardingWelcome(onStart: () {}, onLater: () {})),
      ),
    );
    await tester.pump(const Duration(seconds: 2));
    final position = tester.state<ScrollableState>(find.byType(Scrollable).first).position;
    expect(position.maxScrollExtent, 0, reason: 'everything fits');

    final gesture = await tester.startGesture(const Offset(200, 400));
    await gesture.moveBy(const Offset(0, -120));
    await tester.pump();
    expect(position.pixels, 0);
    await gesture.up();
    await tester.pumpAndSettle();
  });
}
