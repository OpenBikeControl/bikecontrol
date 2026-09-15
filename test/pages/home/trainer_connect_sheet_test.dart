// Regression: with onboarding skipped no trainer app is chosen, yet the home
// screen's trainer card still lists a discovered trainer with a Connect
// button. Tapping it used to fall back to the generic "Need a hand?" help
// sheet instead of the trainer picker — the picker never needed an app.
//
// Deliberately on the plain test binding rather than the snapshot harness:
// that one selects IntegrationTestWidgetsFlutterBinding, which co-running
// files poison with a stray app_links platform-stream error (see
// fulgaz_connection_copy_test).
import 'package:bike_control/gen/l10n.dart';
import 'package:bike_control/main.dart' show OtherLocalizationsDelegate;
import 'package:bike_control/pages/home/home_sheets.dart';
import 'package:bike_control/utils/actions/base_actions.dart' show StubActions;
import 'package:bike_control/utils/core.dart';
import 'package:bike_control/utils/keymap/apps/my_whoosh.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    // Fresh prefs per test: nothing under `trainer_app`, so getTrainerApp() is
    // null exactly like a rider who skipped onboarding.
    SharedPreferences.setMockInitialValues({});
    core.settings.prefs = await SharedPreferences.getInstance();
    core.settings.trainerAppListenable.value = null;
    core.actionHandler = StubActions();
  });

  Future<void> pumpAndOpen(WidgetTester tester) async {
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
        locale: const Locale('en'),
        theme: ThemeData(colorScheme: ColorSchemes.lightSlate, radius: 0.7),
        // Sheets need the DrawerOverlay that Scaffold provides, so open from a
        // context captured beneath it — same as the home screen's trainer card.
        home: Scaffold(
          child: Builder(
            builder: (context) => GhostButton(
              onPressed: () => openTrainerConnectSheet(context),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.tap(find.text('open'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(tester.takeException(), isNull, reason: 'opening the trainer sheet must not crash');
  }

  testWidgets('opens the trainer picker when no trainer app is selected', (tester) async {
    expect(core.settings.getTrainerApp(), isNull);

    await pumpAndOpen(tester);

    final l10n = AppLocalizations.current;
    expect(find.text(l10n.onboardingTrainerTitle), findsOneWidget);
    expect(find.text(l10n.onboardingHelpSheetTitle), findsNothing);
  });

  testWidgets('still opens the trainer picker with a trainer app selected', (tester) async {
    core.settings.setTrainerApp(MyWhoosh());

    await pumpAndOpen(tester);

    final l10n = AppLocalizations.current;
    expect(find.text(l10n.onboardingTrainerTitle), findsOneWidget);
    expect(find.text(l10n.onboardingHelpSheetTitle), findsNothing);
  });
}
