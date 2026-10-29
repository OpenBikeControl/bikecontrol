// Connection settings → Trainer app → Change: the onboarding app grid opens
// right away, as a bottom sheet on a phone that stays clear of the status and
// navigation bars.
import 'package:bike_control/gen/l10n.dart';
import 'package:bike_control/main.dart' show OtherLocalizationsDelegate, screenshotMode;
import 'package:bike_control/pages/onboarding/steps/step_app.dart' show OnboardingAppTile;
import 'package:bike_control/pages/trainer_connection_settings.dart';
import 'package:bike_control/utils/core.dart';
import 'package:bike_control/utils/keymap/apps/my_whoosh.dart';
import 'package:bike_control/utils/requirements/multi.dart';
import 'package:bike_control/widgets/ui/app_theme.dart';
import 'package:bike_control/widgets/ui/safe_area_popover_handler.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

import '../widget_snapshot.dart';

Widget _app(Widget child) => ShadcnApp(
  menuHandler: const SafeAreaPopoverHandler(),
  popoverHandler: const SafeAreaPopoverHandler(),
  localizationsDelegates: [
    ...ShadcnLocalizations.localizationsDelegates,
    const OtherLocalizationsDelegate(),
    AppLocalizations.delegate,
  ],
  supportedLocales: const [Locale('en')],
  scaling: BkTheme.scaling,
  theme: BkTheme.build(Brightness.dark),
  home: child,
);

Future<void> main() async {
  await ensureSnapshotHarness();
  late AppLocalizations l;

  setUp(() async {
    l = AppLocalizations.current;
    core.settings.setTrainerApp(MyWhoosh());
    await core.settings.setLastTarget(Target.thisDevice);
    screenshotMode = false;
  });

  tearDown(() => screenshotMode = true);

  Finder popup() => find.byKey(const ValueKey('trainer-app-picker'));

  Future<void> openPicker(WidgetTester tester) async {
    final card = find.byKey(const ValueKey('connection-trainer-app'));
    await tester.tap(find.descendant(of: card, matching: find.text(l.rideChange)));
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  }

  testWidgets('Change opens the grid of trainer apps at once', (tester) async {
    tester.view.physicalSize = const Size(430, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(_app(const TrainerConnectionSettingsPage()));
    await tester.pump();
    expect(popup(), findsNothing);

    await openPicker(tester);

    expect(popup(), findsOneWidget);
    expect(find.descendant(of: popup(), matching: find.text(l.officiallySupported.toUpperCase())), findsOneWidget);
    expect(find.descendant(of: popup(), matching: find.text(l.otherTrainerApps.toUpperCase())), findsOneWidget);
    expect(find.descendant(of: popup(), matching: find.byType(OnboardingAppTile)), findsWidgets);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('on a phone the grid stays inside the status and navigation bars', (tester) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    tester.view.padding = const FakeViewPadding(top: 40, bottom: 24);
    tester.view.viewPadding = const FakeViewPadding(top: 40, bottom: 24);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(_app(const TrainerConnectionSettingsPage()));
    await tester.pump();

    await openPicker(tester);

    expect(popup(), findsOneWidget);
    final rect = tester.getRect(popup());
    expect(rect.top, greaterThanOrEqualTo(40), reason: '$rect');
    expect(rect.bottom, lessThanOrEqualTo(640 - 24), reason: '$rect');
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
  });
}
