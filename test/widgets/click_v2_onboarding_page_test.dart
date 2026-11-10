import 'package:bike_control/bluetooth/emulation/emulated_ble_platform.dart';
import 'package:bike_control/gen/l10n.dart';
import 'package:bike_control/pages/click_v2_onboarding.dart';
import 'package:bike_control/utils/actions/base_actions.dart';
import 'package:bike_control/utils/core.dart';
import 'package:bike_control/widgets/click_v2/click_contours.dart';
import 'package:bike_control/widgets/ui/bk_page_column.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:universal_ble/universal_ble.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    // Applying a choice reaches the connection layer (rescan, availability
    // check). Against the real platform channel those calls go through the BLE
    // command queue, whose 10s timeout is a Timer armed in the fake zone that
    // outlives the widget tree — "A Timer is still pending even after the
    // widget tree was disposed". The fake platform answers in process.
    UniversalBle.setInstance(FakeUniversalBlePlatform());
    SharedPreferences.setMockInitialValues({});
    core.settings.prefs = await SharedPreferences.getInstance();
    // The app assigns this in Settings.init() (initializeActions) before any
    // page can open, and choosing right-side-only reads it to remap the
    // keymap. With these empty prefs nothing has been picked yet, which in the
    // app means StubActions with no trainer app.
    core.actionHandler = StubActions();
    await AppLocalizations.load(const Locale('en'));
  });

  // Harness matching test/widgets/emulation_card_test.dart — ShadcnApp with the
  // single English delegate is the pattern that works in this repo.
  Future<void> pumpPage(WidgetTester tester) async {
    // The hero's lock badge loops for as long as the page is
    // visible (see ClickContours) — these tests exercise CTA/text/navigation
    // behaviour, not that loop, so animations are disabled here to keep
    // pumpAndSettle deterministic instead of waiting out a Ticker that never
    // stops on its own.
    tester.platformDispatcher.accessibilityFeaturesTestValue = const FakeAccessibilityFeatures(disableAnimations: true);
    await tester.pumpWidget(
      const ShadcnApp(
        localizationsDelegates: [AppLocalizations.delegate],
        supportedLocales: [Locale('en')],
        home: ClickV2OnboardingPage(),
      ),
    );
    await tester.pumpAndSettle();
  }

  Finder cta() => find.byKey(const ValueKey('click-onboarding-cta'));
  Finder leftSwitch() => find.descendant(
    of: find.byKey(const ValueKey('click-onboarding-left-toggle')),
    matching: find.byType(Switch),
  );

  Future<void> tapKey(WidgetTester tester, String key) async {
    await tester.ensureVisible(find.byKey(ValueKey(key)));
    await tester.tap(find.byKey(ValueKey(key)));
    await tester.pumpAndSettle();
  }

  Future<void> tapCta(WidgetTester tester) async {
    await tester.tap(cta());
    await tester.pumpAndSettle();
  }

  bool ctaEnabled(WidgetTester tester) => tester.widget<Button>(cta()).onPressed != null;

  testWidgets('both paths are on one screen, nothing pre-selected and the CTA disabled', (tester) async {
    await pumpPage(tester);

    expect(find.text('Skip the Zwift unlock'), findsOneWidget);
    expect(find.text('Unlock with Zwift'), findsOneWidget);
    expect(find.text('Needs unlocking with the Zwift app every 24 hours'), findsOneWidget);
    expect(find.byType(PageView), findsNothing);
    expect(find.byType(ClickContours), findsOneWidget);
    expect(find.text('Pick an option'), findsOneWidget);
    expect(ctaEnabled(tester), isFalse);
    // The left-puck opt-in belongs to the no-unlock path, so it waits for it.
    expect(leftSwitch(), findsNothing);
  });

  testWidgets('picking no-unlock reveals the left-side opt-in and names the right-side CTA', (tester) async {
    await pumpPage(tester);
    await tapKey(tester, 'click-onboarding-option-no-unlock');

    expect(leftSwitch(), findsOneWidget);
    expect(find.text('Use the right side'), findsOneWidget);
    expect(find.text('No restarts, no drop-outs mid-ride'), findsOneWidget);
    expect(ctaEnabled(tester), isTrue);
  });

  testWidgets('switching the left side on says plainly that it drops out', (tester) async {
    await pumpPage(tester);
    await tapKey(tester, 'click-onboarding-option-no-unlock');
    await tester.tap(leftSwitch());
    await tester.pumpAndSettle();

    expect(find.textContaining('drops out for 1–2 seconds'), findsOneWidget);
    // "No drop-outs" would now be false, so it must be gone.
    expect(find.text('No restarts, no drop-outs mid-ride'), findsNothing);
    expect(find.text('Use both controllers'), findsOneWidget);
    expect(find.byKey(const ValueKey('click-contour-restart-badge')), findsOneWidget);
  });

  testWidgets('selecting an option alone applies nothing', (tester) async {
    await pumpPage(tester);
    await tapKey(tester, 'click-onboarding-option-no-unlock');
    await tapKey(tester, 'click-onboarding-option-zwift');

    expect(core.settings.getClickV2OnboardingDone(), isFalse);
  });

  testWidgets('right side only applies that mode', (tester) async {
    await pumpPage(tester);
    await tapKey(tester, 'click-onboarding-option-no-unlock');
    await tapCta(tester);

    expect(core.settings.getUnlockWithZwift(), isFalse);
    expect(core.settings.getClickV2RightSideOnly(), isTrue);
    expect(core.settings.getClickV2OnboardingDone(), isTrue);
  });

  testWidgets('right side plus left side applies the restart mode', (tester) async {
    await pumpPage(tester);
    await tapKey(tester, 'click-onboarding-option-no-unlock');
    await tester.tap(leftSwitch());
    await tester.pumpAndSettle();
    await tapCta(tester);

    expect(core.settings.getUnlockWithZwift(), isFalse);
    expect(core.settings.getClickV2RightSideOnly(), isFalse);
    expect(core.settings.getUseNewUnlockMethod(), isTrue);
    expect(core.settings.getClickV2OnboardingDone(), isTrue);
    await core.connection.stop();
  });

  testWidgets('unlock with Zwift applies that mode', (tester) async {
    await pumpPage(tester);
    await tapKey(tester, 'click-onboarding-option-zwift');
    await tapCta(tester);

    expect(core.settings.getUnlockWithZwift(), isTrue);
    expect(core.settings.getClickV2RightSideOnly(), isFalse);
    expect(core.settings.getClickV2OnboardingDone(), isTrue);
    // This mode also folds the split representation back into the unified
    // controller, which restarts the scan. Wind it down, or the periodic scan
    // timer outlives the widget tree and trips the pending-timer check.
    await core.connection.stop();
  });

  testWidgets('reopening starts on the mode that is set', (tester) async {
    await core.settings.setClickV2OnboardingDone(true);
    await core.settings.setClickV2RightSideOnly(false);
    await pumpPage(tester);

    // Done, not right-only, not Zwift: the restart mode.
    expect(tester.widget<Switch>(leftSwitch()).value, isTrue);
    expect(find.text('Use both controllers'), findsOneWidget);
  });

  testWidgets('closing without choosing writes nothing', (tester) async {
    await pumpPage(tester);

    await tester.tap(find.byKey(const ValueKey('click-onboarding-close')));
    await tester.pumpAndSettle();

    expect(core.settings.getClickV2OnboardingDone(), isFalse);
  });

  testWidgets('caps content width and centres it on a wide desktop window, like every pushed page', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await pumpPage(tester);

    // The whole page's content — header, pager and footer link alike — sits
    // in one page column. On this 1400-wide window that must actually clamp
    // the rendered width, not just exist somewhere unused in the tree.
    final cap = find.byKey(BkPageColumn.columnKey);
    expect(cap, findsOneWidget);
    expect(tester.getSize(cap).width, BkPageColumn.defaultMaxWidth);

    // Centred in the window, like every pushed page.
    expect(tester.getTopLeft(cap).dx, (1400 - BkPageColumn.defaultMaxWidth) / 2);
  });
}
