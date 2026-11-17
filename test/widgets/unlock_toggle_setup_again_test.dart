import 'package:bike_control/gen/l10n.dart';
import 'package:bike_control/pages/click_v2_onboarding.dart';
import 'package:bike_control/utils/actions/base_actions.dart';
import 'package:bike_control/utils/core.dart';
import 'package:bike_control/utils/keymap/apps/rouvy.dart';
import 'package:bike_control/utils/keymap/apps/zwift.dart';
import 'package:bike_control/widgets/unlock_toggle.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    core.actionHandler = StubActions();
    core.settings.prefs = await SharedPreferences.getInstance();
    await AppLocalizations.load(const Locale('en'));
  });

  testWidgets('offers a way back into the onboarding explainer', (tester) async {
    // "Set up again" below navigates into ClickV2OnboardingPage, whose hero
    // badges loop for as long as it's visible (see ClickContours) — this
    // test exercises the navigation, not that loop, so animations are
    // disabled to keep pumpAndSettle deterministic instead of waiting out a
    // Ticker that never stops on its own.
    tester.platformDispatcher.accessibilityFeaturesTestValue = const FakeAccessibilityFeatures(disableAnimations: true);
    await tester.pumpWidget(
      ShadcnApp(
        localizationsDelegates: const [AppLocalizations.delegate],
        supportedLocales: const [Locale('en')],
        home: Scaffold(child: const UnlockToggle(children: [])),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Set up again'), findsOneWidget);

    await tester.tap(find.text('Set up again'));
    await tester.pumpAndSettle();

    expect(find.byType(ClickV2OnboardingPage), findsOneWidget);
  });

  // The explainer is the only place the unlock mode is chosen — a dropdown
  // beside it could set the setting without doing the work each mode needs.
  testWidgets('offers no unlock-mode picker of its own', (tester) async {
    tester.platformDispatcher.accessibilityFeaturesTestValue = const FakeAccessibilityFeatures(disableAnimations: true);
    await tester.pumpWidget(
      ShadcnApp(
        localizationsDelegates: const [AppLocalizations.delegate],
        supportedLocales: const [Locale('en')],
        home: Scaffold(child: const UnlockToggle(children: [])),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(Select<bool>), findsNothing);
  });

  // Without this the card looked identical whichever mode was set, so coming
  // back from the explainer read as if the choice had done nothing.
  group('names the mode that is actually set', () {
    Future<void> pump(WidgetTester tester) async {
      tester.platformDispatcher.accessibilityFeaturesTestValue = const FakeAccessibilityFeatures(
        disableAnimations: true,
      );
      await tester.pumpWidget(
        ShadcnApp(
          localizationsDelegates: const [AppLocalizations.delegate],
          supportedLocales: const [Locale('en')],
          home: Scaffold(child: const UnlockToggle(children: [])),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('unlock with Zwift', (tester) async {
      await core.settings.setUnlockWithZwift(true);
      await pump(tester);
      expect(find.text(AppLocalizations.current.unlock_modeZwift), findsOneWidget);
    });

    testWidgets('right side only', (tester) async {
      await core.settings.setClickV2RightSideOnly(true);
      await pump(tester);
      expect(find.text(AppLocalizations.current.clickV2Onboarding_rightOnlyTitle), findsOneWidget);
    });

    testWidgets('the legacy restart loop is the fallback', (tester) async {
      await pump(tester);
      expect(find.text(AppLocalizations.current.unlock_modeRestart), findsOneWidget);
    });
  });

  // The "unlock now" action lives on the left puck and needs it connected, so
  // in Zwift mode without one there is nothing to show — say where unlocking
  // happens rather than leaving the card looking like the mode did nothing.
  testWidgets('points at the left puck when Zwift mode has none connected', (tester) async {
    await core.settings.setUnlockWithZwift(true);
    tester.platformDispatcher.accessibilityFeaturesTestValue = const FakeAccessibilityFeatures(
      disableAnimations: true,
    );
    await tester.pumpWidget(
      ShadcnApp(
        localizationsDelegates: const [AppLocalizations.delegate],
        supportedLocales: const [Locale('en')],
        home: Scaffold(
          child: UnlockToggle(children: [Text('unlock action')]),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text(AppLocalizations.current.unlock_zwiftNeedsLeftSide), findsOneWidget);
    expect(find.text('unlock action'), findsNothing);
  });

  // Zwift and Rouvy unlock the controller themselves, so there is no mode to
  // show or pick — only a rider who chose right-side-only keeps the way back.
  group('with a trainer app that unlocks the controller itself', () {
    Future<void> pump(WidgetTester tester) async {
      tester.platformDispatcher.accessibilityFeaturesTestValue = const FakeAccessibilityFeatures(
        disableAnimations: true,
      );
      await tester.pumpWidget(
        ShadcnApp(
          localizationsDelegates: const [AppLocalizations.delegate],
          supportedLocales: const [Locale('en')],
          home: Scaffold(child: const UnlockToggle(children: [])),
        ),
      );
      await tester.pumpAndSettle();
    }

    for (final app in [Zwift(), Rouvy()]) {
      testWidgets('${app.name}: shows no unlock mode', (tester) async {
        core.settings.setTrainerApp(app);
        await pump(tester);
        expect(find.text(AppLocalizations.current.unlock_mode), findsNothing);
        expect(find.text('Set up again'), findsNothing);
      });
    }

    testWidgets('keeps the way back from right-side-only', (tester) async {
      core.settings.setTrainerApp(Zwift());
      await core.settings.setClickV2RightSideOnly(true);
      await pump(tester);
      expect(find.text('Set up again'), findsOneWidget);
    });
  });
}
