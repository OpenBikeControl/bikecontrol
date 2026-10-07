// Task 8: Help Center page skeleton, since grown into the full page (Guides
// & videos, Your setup, Known issues, Pricing & account, Contact &
// community — the standalone Troubleshooting section was dropped in design
// round 1). These tests pin: every section header renders, the
// `focus: HelpCenterFocus.yourSetup` constructor scrolls the your-setup
// placeholder into view, and the help button pushes this page instead of
// opening the old dropdown.
import 'package:bike_control/gen/l10n.dart';
import 'package:bike_control/pages/help_center/help_center_page.dart';
import 'package:bike_control/utils/actions/base_actions.dart';
import 'package:bike_control/utils/core.dart';
import 'package:bike_control/widgets/ui/help_button.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

Future<void> _pump(WidgetTester tester, Widget child) {
  return tester.pumpWidget(
    ShadcnApp(
      debugShowCheckedModeBanner: false,
      localizationsDelegates: const [AppLocalizations.delegate],
      supportedLocales: AppLocalizations.delegate.supportedLocales,
      home: child,
    ),
  );
}

Future<void> main() async {
  TestWidgetsFlutterBinding.ensureInitialized();
  final l10n = await AppLocalizations.load(const Locale('en'));

  // HelpButton's re-check-on-return fix touches `core.supabase`; give it an
  // offline dummy instance (no session, so no request is ever made) rather
  // than crashing on the un-initialized singleton.
  setUpAll(() async {
    await initializeDateFormatting();
    SharedPreferences.setMockInitialValues({});
    await Supabase.initialize(
      url: 'http://127.0.0.1:9',
      anonKey: 'help-center-test-anon-key',
      debug: false,
      authOptions: const FlutterAuthClientOptions(
        localStorage: EmptyLocalStorage(),
        detectSessionInUri: false,
        autoRefreshToken: false,
      ),
    );
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    core.settings.prefs = await SharedPreferences.getInstance();
    core.actionHandler = StubActions();
  });

  testWidgets('renders every always-on section header', (tester) async {
    await _pump(tester, const HelpCenterPage());
    await tester.pump();

    expect(find.text(l10n.helpCenterGuides), findsOneWidget);
    expect(find.text(l10n.helpCenterYourSetup), findsOneWidget);
    expect(find.text(l10n.helpCenterPricingFaq), findsOneWidget);
    expect(find.text(l10n.helpCenterContact), findsOneWidget);
  });

  testWidgets('Known Issues renders nothing — not even its header — when the fetch fails', (tester) async {
    // KnownIssuesSection fires a real, unmocked network fetch on initState
    // (see the "help button push" test below) against the bogus
    // 127.0.0.1:9 endpoint set up in setUpAll, which fails fast (loopback
    // connection-refused, not a real timeout). Usage-fix round 3 (Jonas): a
    // "Bekannte Probleme" card with a header and an empty body must not
    // render at all — this pins that the whole card, header included, is
    // gone once the fetch resolves to "no issues".
    await _pump(tester, const HelpCenterPage());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text(l10n.helpCenterKnownIssues), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('focus: yourSetup scrolls the your-setup placeholder into view', (tester) async {
    // Shrink the viewport so the your-setup section (several sections deep)
    // starts out of view — otherwise "scrolled into view" is a no-op. Design
    // round 1 dropped the Troubleshooting card ahead of "Your setup", so it
    // now sits higher up the page — the viewport needs to be shorter than
    // before to still push it below the fold. Dropping the instruction
    // videos row from Guides & videos moved it up again.
    const viewportHeight = 180.0;
    tester.view.physicalSize = const Size(400, viewportHeight);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await _pump(tester, const HelpCenterPage());
    await tester.pump();
    final unfocusedRect = tester.getRect(find.byKey(const ValueKey('help-your-setup')));
    expect(
      unfocusedRect.top,
      greaterThan(viewportHeight),
      reason: 'sanity: section starts below the fold without focus',
    );

    // Force a full unmount before the next pump — reusing the same element
    // tree would reuse the State object too, and this page's focus handling
    // (like `revealOverlaySection` on the proxy details page) runs from
    // `initState`, mirroring how a freshly-pushed route always behaves.
    await tester.pumpWidget(const SizedBox());
    await _pump(tester, const HelpCenterPage(focus: HelpCenterFocus.yourSetup));
    // Not pumpAndSettle: KnownIssuesSection fires a real, unmocked network
    // fetch on initState — bounded pumps sidestep waiting on that. The
    // scroll animation itself is a fixed 350ms tween, so a couple of bounded
    // pumps is enough to let it finish.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    final focusedRect = tester.getRect(find.byKey(const ValueKey('help-your-setup')));
    expect(focusedRect.top, greaterThanOrEqualTo(0));
    expect(focusedRect.top, lessThan(viewportHeight), reason: 'ensureVisible scrolled the section onto screen');
  });

  testWidgets('help button push opens HelpCenterPage', (tester) async {
    await _pump(tester, const HelpButton());
    await tester.pump();

    expect(find.byType(HelpCenterPage), findsNothing);

    await tester.tap(find.byType(HelpButton));
    // Not pumpAndSettle: HelpCenterPage's "Known issues" section fires a
    // real, unmocked network fetch on initState.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.byType(HelpCenterPage), findsOneWidget);
  });

  testWidgets('help button awaits the pushed HelpCenterPage and re-checks unread on return', (tester) async {
    // Regression: HelpButton stays mounted under the pushed route and its
    // own `_hasUnread` badge was never re-synced when the rider returned —
    // only ContactCommunitySection's local flag got reset. `onPressed` now
    // awaits `context.push` and re-runs `_checkForUnread` afterwards; this
    // pins that the round trip completes cleanly (no session in tests, so
    // `_checkForUnread` no-ops past its `currentSession == null` guard, but
    // the awaited continuation must still run without throwing).
    await _pump(tester, const HelpButton());
    await tester.pump();

    await tester.tap(find.byType(HelpButton));
    // Not pumpAndSettle: see the "help button push opens HelpCenterPage"
    // test above.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byType(HelpCenterPage), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('page-header-back')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1000));

    expect(find.byType(HelpCenterPage), findsNothing);
    expect(find.byType(HelpButton), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
