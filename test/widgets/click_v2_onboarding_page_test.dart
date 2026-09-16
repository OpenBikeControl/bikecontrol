import 'package:bike_control/bluetooth/emulation/emulated_ble_platform.dart';
import 'package:bike_control/gen/l10n.dart';
import 'package:bike_control/pages/click_v2_onboarding.dart';
import 'package:bike_control/utils/actions/base_actions.dart';
import 'package:bike_control/utils/core.dart';
import 'package:bike_control/widgets/click_v2/click_contours.dart';
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

  Future<void> swipeNext(WidgetTester tester) async {
    await tester.drag(find.byType(PageView), const Offset(-500, 0));
    await tester.pumpAndSettle();
  }

  // The two decision-page CTAs, checked as an actual tappable Button rather
  // than a blanket "no Button" assertion — the header close icon and the
  // "why is this needed?" / alternatives links are Buttons too, and would
  // make a type-only assertion vacuous.
  Finder decisionButton(String text) => find.widgetWithText(Button, text);

  testWidgets('page 0 shows the right-side option and the swipe hint, with no applying button', (tester) async {
    await pumpPage(tester);

    expect(find.text('Use the right side only'), findsOneWidget);
    expect(find.text('No restarts, no drop-outs mid-ride'), findsOneWidget);
    expect(find.text('Swipe to see the other option'), findsWidgets);
    // The hero now lives inside the pager's own scrollable page content
    // (moved off the fixed chrome above it) rather than as a shared sibling
    // above the PageView -- so it turns up as a descendant of the PageView
    // itself on every page, this one included.
    expect(find.descendant(of: find.byType(PageView), matching: find.byType(ClickContours)), findsWidgets);

    expect(decisionButton('Use the right side'), findsNothing);
    expect(decisionButton('Unlock with Zwift'), findsNothing);
  });

  testWidgets('swiping once reveals the unlock-with-Zwift option, still with no applying button', (tester) async {
    await pumpPage(tester);
    await swipeNext(tester);

    expect(find.text('Unlock with Zwift'), findsWidgets);
    expect(find.text('Needs unlocking with the Zwift app every 24 hours'), findsOneWidget);
    expect(find.text('Swipe to see the other option'), findsWidgets);
    expect(find.descendant(of: find.byType(PageView), matching: find.byType(ClickContours)), findsWidgets);

    expect(decisionButton('Use the right side'), findsNothing);
    expect(decisionButton('Unlock with Zwift'), findsNothing);
  });

  testWidgets('swiping twice shows the decision page with both option buttons', (tester) async {
    await pumpPage(tester);
    await swipeNext(tester);
    await swipeNext(tester);

    expect(find.text('Which one do you want?'), findsOneWidget);
    expect(decisionButton('Use the right side'), findsOneWidget);
    expect(decisionButton('Unlock with Zwift'), findsOneWidget);
    expect(find.text('No Zwift needed · right controller only'), findsOneWidget);
    expect(find.text('Both controllers · unlock every 24 hours'), findsOneWidget);
    // The decision page's own hero (both pucks live) is the third page to
    // carry one inside the pager.
    expect(find.descendant(of: find.byType(PageView), matching: find.byType(ClickContours)), findsWidgets);
  });

  testWidgets('the decision page renders no lock badge, unlike page 1', (tester) async {
    await pumpPage(tester);
    await swipeNext(tester);

    // Page 1 illustrates the Zwift trade-off with the animated padlock.
    expect(find.byKey(const ValueKey('click-contour-lock-badge')), findsOneWidget);

    await swipeNext(tester);

    // The decision page is about choosing, not explaining -- the badge (and
    // its loop) that sells page 1's trade-off would just be noise here.
    expect(find.byKey(const ValueKey('click-contour-lock-badge')), findsNothing);
  });

  testWidgets('tapping the right-side button on the decision page applies that mode', (tester) async {
    await pumpPage(tester);
    await swipeNext(tester);
    await swipeNext(tester);

    await tester.tap(decisionButton('Use the right side'));
    await tester.pumpAndSettle();

    expect(core.settings.getUnlockWithZwift(), isFalse);
    expect(core.settings.getClickV2RightSideOnly(), isTrue);
    expect(core.settings.getClickV2OnboardingDone(), isTrue);
  });

  testWidgets('tapping the Zwift button on the decision page applies that mode', (tester) async {
    await pumpPage(tester);
    await swipeNext(tester);
    await swipeNext(tester);

    await tester.tap(decisionButton('Unlock with Zwift'));
    await tester.pumpAndSettle();

    expect(core.settings.getUnlockWithZwift(), isTrue);
    expect(core.settings.getClickV2RightSideOnly(), isFalse);
    expect(core.settings.getClickV2OnboardingDone(), isTrue);
    // This mode also folds the split representation back into the unified
    // controller, which restarts the scan — so the app is genuinely still
    // scanning when the assertions above pass. Wind it down, or the periodic
    // scan timer outlives the widget tree and trips the pending-timer check.
    await core.connection.stop();
  });

  testWidgets('closing without choosing writes nothing', (tester) async {
    await pumpPage(tester);

    await tester.tap(find.byKey(const ValueKey('click-onboarding-close')));
    await tester.pumpAndSettle();

    expect(core.settings.getClickV2OnboardingDone(), isFalse);
  });

  testWidgets('tapping the swipe hint on page 0 advances to page 1', (tester) async {
    await pumpPage(tester);

    await tester.tap(find.byKey(const ValueKey('click-onboarding-swipe-hint-0')));
    await tester.pumpAndSettle();

    expect(find.text('Unlock with Zwift'), findsWidgets);
    expect(find.text('Needs unlocking with the Zwift app every 24 hours'), findsOneWidget);
  });

  testWidgets('tapping the swipe hint on page 1 advances to the decision page', (tester) async {
    await pumpPage(tester);
    await swipeNext(tester);

    await tester.tap(find.byKey(const ValueKey('click-onboarding-swipe-hint-1')));
    await tester.pumpAndSettle();

    expect(find.text('Which one do you want?'), findsOneWidget);
    expect(decisionButton('Use the right side'), findsOneWidget);
    expect(decisionButton('Unlock with Zwift'), findsOneWidget);
  });

  // The swipe hint is a "next" affordance, not a choice -- it must never
  // apply either unlock mode itself.
  testWidgets('tapping the swipe hint never applies a choice', (tester) async {
    await pumpPage(tester);

    await tester.tap(find.byKey(const ValueKey('click-onboarding-swipe-hint-0')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('click-onboarding-swipe-hint-1')));
    await tester.pumpAndSettle();

    expect(core.settings.getClickV2OnboardingDone(), isFalse);
  });

  testWidgets('the dot indicator renders three dots', (tester) async {
    await pumpPage(tester);

    // Scoped to the dot row itself — shadcn's own widgets use AnimatedContainer
    // internally too, so a blanket byType(AnimatedContainer) would overcount.
    expect(
      find.descendant(of: find.byKey(const ValueKey('click-onboarding-dots')), matching: find.byType(AnimatedContainer)),
      findsNWidgets(3),
    );
  });

  testWidgets('advantage and disadvantage rows settle into place', (tester) async {
    await pumpPage(tester);

    // The stagger is a one-shot entrance; once settled every row is opaque and
    // at its resting offset, so the page is never left half-faded.
    // Every row on page 0: two pros and its one con.
    for (final text in [
      'No Zwift unlock — ever',
      'No restarts, no drop-outs mid-ride',
      'Only the right controller sends button presses',
    ]) {
      final opacity = tester.widget<FadeTransition>(
        find.ancestor(of: find.text(text), matching: find.byType(FadeTransition)).first,
      );
      expect(opacity.opacity.value, closeTo(1.0, 0.001), reason: 'row not fully faded in: $text');
    }
  });

  testWidgets('caps content width and centers it on a wide desktop window, matching the Help Center / '
      'instruction-videos idiom', (tester) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await pumpPage(tester);

    // The whole page's content — header, pager and footer link alike — sits
    // inside one Center + ConstrainedBox(maxWidth: 720), the same idiom
    // instruction_videos_section.dart's "Bug 3" fix uses. On this 1400-wide
    // window that must actually clamp the rendered width, not just exist
    // somewhere unused in the tree.
    final cap = find.byWidgetPredicate((w) => w is ConstrainedBox && w.constraints.maxWidth == 720);
    expect(cap, findsOneWidget);
    expect(tester.getSize(cap).width, 720);

    // Centered, not pinned to an edge: equal empty space on both sides of
    // the capped content within the 1400-wide window.
    final capLeft = tester.getTopLeft(cap).dx;
    final capRight = tester.getTopRight(cap).dx;
    expect(capLeft, closeTo(1400 - capRight, 0.5));
  });
}
