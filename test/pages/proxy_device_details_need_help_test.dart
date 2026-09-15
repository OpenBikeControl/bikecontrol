// "Need help?" round: the trainer page's feedback box ("Works" / "No
// difference" / "Not working") is gone. "Works" never told support anything
// actionable, and the two negative buttons were just two doors into the same
// Help Center route — so the box is now a single dismissible "Need help?"
// card whose one CTA takes that route. The route itself is unchanged: the
// Help Center's "Your setup" section, carrying the same trainer-specific
// diagnostic payload (a lazy, memoized telemetry builder plus a screenshot)
// so continuing from there into "Tell us what's wrong" doesn't lose it. See
// help_center_support_context.dart for the value object that carries that
// payload, and lazy_async_test.dart for the memoization mechanism's own unit
// coverage.
//
// Dismissal is global, not per trainer: a rider who closed the card on one
// trainer has said "I know where help lives" — showing it again on the next
// trainer would be nagging.
//
// Deliberately never *awaits* telemetryBuilder()/diagnosticPreviewFuture to
// completion: both bottom out in the real, unmocked debugText() ->
// DebugDiagnostics.gather() -> MdnsDiscoveryScan().run(), which stalls for
// minutes rather than failing fast in this sandbox (confirmed by isolating
// a single test past the 120s mark). Calling the builder — starting it,
// never awaiting the result — is safe (confirmed empirically: this whole
// file, including the calls below, runs in ~1s with no pending-timer
// teardown failures); only awaiting it to completion hangs. Propagation and
// memoization are both verified with reference identity on the (unawaited)
// Future objects instead.
import 'package:bike_control/bluetooth/devices/proxy/proxy_device.dart';
import 'package:bike_control/gen/l10n.dart';
import 'package:bike_control/main.dart' show OtherLocalizationsDelegate, installLoggerErrorListener, navigatorKey;
import 'package:bike_control/pages/help_center/help_center_page.dart';
import 'package:bike_control/pages/proxy_device_details.dart';
import 'package:bike_control/pages/proxy_device_details/need_help_card.dart';
import 'package:bike_control/pages/support_chat/support_chat_page.dart';
import 'package:bike_control/services/overview_screenshot.dart';
import 'package:bike_control/utils/actions/base_actions.dart';
import 'package:bike_control/utils/core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:prop/utils/shared.dart' show Logger;
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:universal_ble/universal_ble.dart';

Future<void> main() async {
  TestWidgetsFlutterBinding.ensureInitialized();
  await AppLocalizations.load(const Locale('en'));

  // HelpCenterPage's "Known issues" section fires a real, unmocked network
  // fetch on initState (same as help_center_page_test.dart) — point Supabase
  // at a bogus loopback endpoint so that fails fast (connection refused)
  // instead of hanging, and SupportChatPage's default SupportChatService()
  // has a real (if unusable) client to read `auth.currentSession` from.
  setUpAll(() async {
    await initializeDateFormatting();
    SharedPreferences.setMockInitialValues({});
    // Every recordError() in the app funnels into _persistCrash ->
    // debugText(), whose 6 s diagnostics timeout is itself recordError'ed on
    // expiry -> _persistCrash -> debugText() ... Under fake async that is an
    // unbounded chain of pending 6 s timers (the gather never completes in
    // this sandbox), and the Known-issues fetch failure below starts it on
    // every Help Center push. Keep the print, drop the persist: the listener
    // is installed once (idempotent) and then swapped for a plain log.
    installLoggerErrorListener();
    Logger.onRecordError = (message, error, _) => debugPrint('recordError($message): $error');
    await Supabase.initialize(
      url: 'http://127.0.0.1:9',
      anonKey: 'proxy-device-details-need-help-test-anon-key',
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

  ProxyDevice device() => ProxyDevice(BleDevice(deviceId: 'x', name: 'Wahoo KICKR'));

  // The card (and, on the pushed Help Center page, the support row) sits
  // below the fold at the default 800x600 test viewport — scroll it into
  // view first so the tap actually lands on it instead of silently missing
  // (Flutter still "succeeds" a tap dispatched outside the render tree's
  // bounds, it just never reaches the widget).
  Future<void> tapKey(WidgetTester tester, String key) async {
    final finder = find.byKey(ValueKey(key));
    await tester.ensureVisible(finder);
    await tester.pump();
    await tester.tap(finder);
  }

  // The CTA's first step is captureOverviewScreenshot(): its
  // RenderRepaintBoundary.toImage() only completes on the real event loop
  // (matchesGoldenFile wraps its own capture in runAsync for the same
  // reason), and the stitched capture awaits `endOfFrame` once per viewport
  // of page — frames the test binding only produces when pumped. So: real
  // time, plus a short pump loop to feed it frames; the push then follows
  // on the same continuation chain.
  Future<void> tapOpenHelp(WidgetTester tester) async {
    await tester.runAsync(() async {
      await tapKey(tester, 'need-help-open');
      for (var i = 0; i < 12 && find.byType(HelpCenterPage).evaluate().isEmpty; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 50));
        await tester.pump();
      }
    });
  }

  // Wired to the app's real navigatorKey and the fuller shadcn delegate set,
  // matching network_troubleshooting_page_test.dart's setup.
  Future<void> pumpPage(WidgetTester tester, ProxyDevice device) async {
    await tester.pumpWidget(
      ShadcnApp(
        debugShowCheckedModeBanner: false,
        navigatorKey: navigatorKey,
        localizationsDelegates: [
          ...ShadcnLocalizations.localizationsDelegates,
          const OtherLocalizationsDelegate(),
          AppLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.delegate.supportedLocales,
        // In the app this boundary wraps the Navigation scaffold; mounting it
        // here is what lets captureOverviewScreenshot() return a real
        // attachment instead of null (its "no boundary" early-out), so the
        // payload assertions below exercise the actual capture.
        home: RepaintBoundary(
          key: overviewScreenshotKey,
          child: ProxyDeviceDetailsPage(device: device),
        ),
      ),
    );
    await tester.pump();
  }

  // Calling telemetryBuilder() starts debugText(), which parks a 6 s
  // diagnostics-timeout Timer flutter_test would flag as pending at teardown.
  // Advancing fake time past it lets it fire and be collected — bounded fake
  // time, not the real-time wait the header warns against.
  Future<void> drainDebugTextTimer(WidgetTester tester) async {
    await tester.pump(const Duration(seconds: 7));
  }

  testWidgets('the Need-help card is shown by default, with no trace of the old feedback buttons', (tester) async {
    await pumpPage(tester, device());

    expect(core.settings.getNeedHelpCardDismissed(), isFalse);
    expect(find.byType(NeedHelpCard), findsOneWidget);
    expect(find.byKey(const ValueKey('need-help-open')), findsOneWidget);
    expect(find.byKey(const ValueKey('need-help-dismiss')), findsOneWidget);
    expect(find.byKey(const ValueKey('feedback-works')), findsNothing);
    expect(find.byKey(const ValueKey('feedback-no-difference')), findsNothing);
    expect(find.byKey(const ValueKey('feedback-not-working')), findsNothing);
  });

  testWidgets('the CTA routes into the Help Center focused on Your setup, with the trainer payload attached', (
    tester,
  ) async {
    await pumpPage(tester, device());

    await tapOpenHelp(tester);
    // Not pumpAndSettle: HelpCenterPage's "Known issues" section fires a
    // real, unmocked network fetch on initState.
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.byType(SupportChatPage), findsNothing, reason: 'routes through the Help Center, not straight to chat');
    expect(find.byType(HelpCenterPage), findsOneWidget);

    final page = tester.widget<HelpCenterPage>(find.byType(HelpCenterPage));
    expect(page.focus, HelpCenterFocus.yourSetup);
    final launchContext = page.launchContext;
    expect(launchContext, isNotNull, reason: 'the trainer-specific payload must ride along');
    expect(launchContext!.initialAttachment, isNotNull, reason: 'the page screenshot is captured up front');
    // memoizeAsync: calling the builder twice must return the exact same
    // in-flight Future rather than starting a second (slow, mDNS-scanning)
    // gather, so the composer's diagnostic preview and the telemetry that
    // rides along with the first send agree.
    expect(identical(launchContext.telemetryBuilder(), launchContext.telemetryBuilder()), isTrue);
    // Opening the Help Center is not a dismissal: the rider may bounce off it
    // without finding what they need, and should still have the card to come
    // back to.
    expect(core.settings.getNeedHelpCardDismissed(), isFalse);
    await drainDebugTextTimer(tester);
  });

  testWidgets(
    'continuing from the Help Center "Tell us what\'s wrong" row carries that same payload into the chat, '
    'composer left empty',
    (tester) async {
      await pumpPage(tester, device());

      await tapOpenHelp(tester);
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byType(HelpCenterPage), findsOneWidget);
      final launchContext = tester.widget<HelpCenterPage>(find.byType(HelpCenterPage)).launchContext!;

      await tapKey(tester, 'help-center-chat-with-support');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.byType(SupportChatPage), findsOneWidget);
      final chatPage = tester.widget<SupportChatPage>(find.byType(SupportChatPage));
      expect(chatPage.initialText, isNull, reason: 'nothing prefills the composer body');
      // Reference equality, not content equality: proves ContactCommunitySection
      // handed SupportChatPage the *exact* trainer-specific objects
      // _routeToHelpCenter gathered, rather than rebuilding a fresh generic
      // payload the way it does when launchContext is absent.
      expect(identical(chatPage.telemetryBuilder, launchContext.telemetryBuilder), isTrue);
      expect(identical(chatPage.initialAttachment, launchContext.initialAttachment), isTrue);
      expect(chatPage.diagnosticPreviewFuture, isNotNull);
      await drainDebugTextTimer(tester);
    },
  );

  testWidgets('tapping x hides the card at once and persists the dismissal for every trainer', (tester) async {
    await pumpPage(tester, device());
    expect(find.byType(NeedHelpCard), findsOneWidget);

    await tapKey(tester, 'need-help-dismiss');
    await tester.pump();

    expect(find.byType(NeedHelpCard), findsNothing);
    expect(core.settings.getNeedHelpCardDismissed(), isTrue);

    // A freshly built page — for a *different* trainer — must not bring the
    // card back: dismissal is global, not per trainer.
    await pumpPage(tester, ProxyDevice(BleDevice(deviceId: 'y', name: 'Tacx NEO')));
    expect(find.byType(NeedHelpCard), findsNothing);
    expect(find.byKey(const ValueKey('need-help-open')), findsNothing);
  });

  testWidgets('a previously dismissed card stays hidden on a cold page', (tester) async {
    await core.settings.setNeedHelpCardDismissed(true);
    await pumpPage(tester, device());
    expect(find.byType(NeedHelpCard), findsNothing);
  });
}
