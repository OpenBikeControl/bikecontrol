import 'dart:async';
import 'dart:io';

import 'package:bike_control/bluetooth/devices/openbikecontrol/obp_mdns_backend.dart';
import 'package:bike_control/gen/l10n.dart';
import 'package:bike_control/main.dart' show OtherLocalizationsDelegate, installLoggerErrorListener, navigatorKey;
import 'package:bike_control/pages/network_troubleshooting_page.dart';
import 'package:bike_control/pages/support_chat/support_chat_page.dart';
import 'package:bike_control/services/bonjour/bonjour_service_advertiser.dart';
import 'package:bike_control/services/network_self_test/network_check.dart';
import 'package:bike_control/services/network_self_test/network_fixes.dart';
import 'package:bike_control/services/network_self_test/network_probe_context.dart';
import 'package:bike_control/services/network_self_test/network_self_test_engine.dart';
import 'package:bike_control/utils/core.dart';
import 'package:bike_control/widgets/network_check_row.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prop/mdns/service_advertiser.dart';
import 'package:prop/utils/shared.dart' show Logger;
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/network_self_test/fake_bonjour_api.dart';
import '../services/network_self_test/recording_advertiser.dart';
import '../widget_snapshot.dart';

/// Pumps [child] inside a real [ShadcnApp], wired to the app's global
/// [navigatorKey] — `buildToast()` (used by the copy-results button) reads
/// `navigatorKey.currentContext`, so the toast test needs the same key the
/// page's toast helper reaches for.
Future<void> _pump(WidgetTester tester, Widget child) {
  return tester.pumpWidget(
    ShadcnApp(
      debugShowCheckedModeBanner: false,
      navigatorKey: navigatorKey,
      localizationsDelegates: [
        ...ShadcnLocalizations.localizationsDelegates,
        const OtherLocalizationsDelegate(),
        AppLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.delegate.supportedLocales,
      home: child,
    ),
  );
}

/// A context with no-op seams; the scripted [ProbeSpec]s below never read it.
NetworkProbeContext _ctx() => NetworkProbeContext(
  snapshot: null,
  snapshotError: null,
  emulatorStarted: true,
  trainerAppConnected: false,
  trainerAppConnectedNow: () => false,
  trainerAppName: 'MyWhoosh',
  backend: ObpMdnsBackend.platformDefault,
  advertisedHostname: null,
  platform: 'macos',
  resolve: (host) async => const [],
  tcpProbe: (address, port) async {},
  runProcess: (executable, arguments) async => ProcessResult(0, 0, '', ''),
  queryLog: () => const [],
  sleep: (d) async {},
  now: () => DateTime(2026, 8, 21),
  onWatchProgress: (progress) {},
);

AppLocalizations _l10n(WidgetTester tester) => AppLocalizations.of(tester.element(find.byType(NetworkTroubleshootingPage)));

/// The variant a [Button] was built with — `Button.primary(...)` stores
/// `ButtonVariance.primary` directly, `Button(style: ButtonStyle.primary())`
/// wraps it; both must count.
AbstractButtonStyle _varianceOf(Button button) {
  final style = button.style;
  return style is ButtonStyle ? style.variance : style;
}

/// Every [Button.primary] under [root].
Iterable<Button> _primaryButtonsIn(WidgetTester tester, Finder root) => tester
    .widgetList<Button>(find.descendant(of: root, matching: find.byType(Button)))
    .where((b) => identical(_varianceOf(b), ButtonVariance.primary));

ProbeSpec _probe(NetworkCheckId id, NetworkVerdict verdict, {List<NetworkFixId> fixes = const []}) => ProbeSpec(
  id: id,
  timeout: const Duration(seconds: 1),
  run: (ctx) async => NetworkCheck(id: id, verdict: verdict, fixes: fixes),
);

/// Pumps the page over the given probes and lets the (instant) run finish.
Future<void> _pumpFinished(WidgetTester tester, List<ProbeSpec> probes) async {
  final engine = NetworkSelfTestEngine(contextBuilder: _ctx, probes: probes);
  await _pump(tester, NetworkTroubleshootingPage(engineFactory: () => engine));
  await tester.pump();
  await tester.pump();
  expect(engine.state.value.result, isNotNull, reason: 'the run should have finished');
}

Future<void> main() async {
  await ensureSnapshotHarness();

  tearDown(() {
    // Task 12's brief-mandated reset: a test that flips this must not leak
    // "already connected" into whichever widget test file runs next in the
    // same process.
    core.obpMdnsEmulator.isConnected.value = false;
  });

  testWidgets('auto-start renders a running row, then result rows, in order', (tester) async {
    final c1 = Completer<NetworkCheck>();
    final c2 = Completer<NetworkCheck>();
    final probes = [
      ProbeSpec(id: NetworkCheckId.methodListening, timeout: const Duration(seconds: 5), run: (ctx) => c1.future),
      ProbeSpec(id: NetworkCheckId.advertisedAddress, timeout: const Duration(seconds: 5), run: (ctx) => c2.future),
    ];
    final engine = NetworkSelfTestEngine(contextBuilder: _ctx, probes: probes);

    await _pump(tester, NetworkTroubleshootingPage(engineFactory: () => engine));
    await tester.pump();

    // First probe in flight: its running placeholder row shows, nothing
    // completed yet.
    expect(find.byKey(const ValueKey('check-methodListening-running')), findsOneWidget);
    expect(find.byKey(const ValueKey('check-methodListening')), findsNothing);

    c1.complete(const NetworkCheck(id: NetworkCheckId.methodListening, verdict: NetworkVerdict.pass));
    await tester.pump();
    await tester.pump();

    // The first check is now a completed row, ABOVE the second probe's own
    // running placeholder.
    final completedFirst = tester.getRect(find.byKey(const ValueKey('check-methodListening')));
    expect(find.byKey(const ValueKey('check-advertisedAddress-running')), findsOneWidget);
    final runningSecond = tester.getRect(find.byKey(const ValueKey('check-advertisedAddress-running')));
    expect(completedFirst.top, lessThan(runningSecond.top));

    c2.complete(const NetworkCheck(id: NetworkCheckId.advertisedAddress, verdict: NetworkVerdict.pass));
    await tester.pump();
    await tester.pump();

    // Both checks are now completed rows, in the order they ran, and the
    // header has switched from "running" to the result view.
    expect(find.byKey(const ValueKey('check-methodListening')), findsOneWidget);
    expect(find.byKey(const ValueKey('check-advertisedAddress')), findsOneWidget);
    expect(find.byKey(const ValueKey('network-run-again')), findsOneWidget);
    expect(find.byKey(const ValueKey('network-cancel')), findsNothing);
  });

  testWidgets('shows the refusal card instead of auto-starting when already connected', (tester) async {
    core.obpMdnsEmulator.isConnected.value = true;

    var built = false;
    final probes = [
      ProbeSpec(
        id: NetworkCheckId.methodListening,
        timeout: const Duration(seconds: 1),
        run: (ctx) async => const NetworkCheck(id: NetworkCheckId.methodListening, verdict: NetworkVerdict.pass),
      ),
    ];
    await _pump(
      tester,
      NetworkTroubleshootingPage(
        engineFactory: () {
          built = true;
          return NetworkSelfTestEngine(contextBuilder: _ctx, probes: probes);
        },
      ),
    );
    await tester.pump();

    expect(built, isFalse, reason: 'a connected trainer app must not auto-start a run');
    expect(find.byType(NetworkCheckRow), findsNothing);
    expect(find.text(_l10n(tester).networkTroubleshootRun), findsOneWidget);
  });

  testWidgets('recommended-fix button appears when a check failed', (tester) async {
    final probes = [
      ProbeSpec(
        id: NetworkCheckId.resolveOwnHostname,
        timeout: const Duration(seconds: 1),
        run: (ctx) async => const NetworkCheck(
          id: NetworkCheckId.resolveOwnHostname,
          verdict: NetworkVerdict.fail,
          fixes: [NetworkFixId.useOsResponderForObc],
        ),
      ),
    ];
    final engine = NetworkSelfTestEngine(contextBuilder: _ctx, probes: probes);

    await _pump(tester, NetworkTroubleshootingPage(engineFactory: () => engine));
    await tester.pump();
    await tester.pump();

    expect(find.byKey(const ValueKey('network-recommended-fix')), findsOneWidget);
  });

  testWidgets('while connected, a recommended backend-switch fix is disabled like restart is', (tester) async {
    core.obpMdnsEmulator.isConnected.value = true;
    final probes = [
      ProbeSpec(
        id: NetworkCheckId.resolveOwnHostname,
        timeout: const Duration(seconds: 1),
        run: (ctx) async => const NetworkCheck(
          id: NetworkCheckId.resolveOwnHostname,
          verdict: NetworkVerdict.fail,
          fixes: [NetworkFixId.useOsResponderForObc, NetworkFixId.switchToLocal],
        ),
      ),
    ];
    await _pump(
      tester,
      NetworkTroubleshootingPage(engineFactory: () => NetworkSelfTestEngine(contextBuilder: _ctx, probes: probes)),
    );
    await tester.pump();

    // Tap through the "already connected" refusal card to run anyway.
    await tester.tap(find.text(_l10n(tester).networkTroubleshootRun));
    await tester.pump();
    await tester.pump();

    final switchButton = tester.widget<Button>(find.byKey(const ValueKey('network-recommended-fix')));
    expect(switchButton.onPressed, isNull, reason: 'switching the backend stops the server and would drop the live connection');

    // The second fix (switchToLocal) does not touch the running server, so it
    // stays tappable. Found by its label rather than by position in the widget
    // tree: which container the fixes sit in is a layout decision, and this
    // test is about which fixes are allowed to run.
    final localLabel = networkFixLabel(
      tester.element(find.byType(NetworkTroubleshootingPage)),
      NetworkFixId.switchToLocal,
    );
    final local = tester
        .widgetList<Button>(find.byType(Button))
        .firstWhere((b) => b.child is Text && (b.child as Text).data == localLabel);
    expect(local.onPressed, isNotNull);
  });

  testWidgets('a second Run again while the engine is still being built does not start a second engine', (tester) async {
    // The production factory awaits DebugDiagnostics.gather() before an
    // engine exists; modelled here by a Completer the second call returns.
    var factoryCalls = 0;
    final gather = Completer<NetworkSelfTestEngine>();
    NetworkSelfTestEngine quickEngine() => NetworkSelfTestEngine(
      contextBuilder: _ctx,
      probes: [
        ProbeSpec(
          id: NetworkCheckId.methodListening,
          timeout: const Duration(seconds: 1),
          run: (ctx) async => const NetworkCheck(id: NetworkCheckId.methodListening, verdict: NetworkVerdict.pass),
        ),
      ],
    );
    await _pump(
      tester,
      NetworkTroubleshootingPage(
        engineFactory: () {
          factoryCalls++;
          return factoryCalls == 1 ? quickEngine() : gather.future;
        },
      ),
    );
    await tester.pump();
    await tester.pump();
    expect(factoryCalls, 1);

    final runAgain = find.byKey(const ValueKey('network-run-again'));
    await tester.tap(runAgain);
    await tester.pump();
    expect(factoryCalls, 2);
    expect(tester.widget<Button>(runAgain).onPressed, isNull, reason: 'disabled while the gather is in flight');

    await tester.tap(runAgain, warnIfMissed: false);
    await tester.pump();
    expect(factoryCalls, 2, reason: 'the second tap during the gather must not build another engine');

    gather.complete(quickEngine());
    await tester.pump();
    await tester.pump();
    expect(factoryCalls, 2);
    expect(tester.widget<Button>(runAgain).onPressed, isNotNull, reason: 're-enabled once the new engine is running');
  });

  testWidgets('copy button copies the bundle and toasts, without throwing', (tester) async {
    final probes = [
      ProbeSpec(
        id: NetworkCheckId.methodListening,
        timeout: const Duration(seconds: 1),
        run: (ctx) async => const NetworkCheck(id: NetworkCheckId.methodListening, verdict: NetworkVerdict.pass),
      ),
    ];
    final engine = NetworkSelfTestEngine(contextBuilder: _ctx, probes: probes);

    await _pump(tester, NetworkTroubleshootingPage(engineFactory: () => engine));
    await tester.pump();
    await tester.pump();

    expect(find.byKey(const ValueKey('network-copy')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('network-copy')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text(_l10n(tester).networkTroubleshootResultsCopied), findsOneWidget);
  });

  testWidgets('cancel mid-run yields a result with completed == false', (tester) async {
    final c1 = Completer<NetworkCheck>();
    final probes = [
      ProbeSpec(id: NetworkCheckId.methodListening, timeout: const Duration(seconds: 5), run: (ctx) => c1.future),
      ProbeSpec(
        id: NetworkCheckId.advertisedAddress,
        timeout: const Duration(seconds: 1),
        run: (ctx) async => const NetworkCheck(id: NetworkCheckId.advertisedAddress, verdict: NetworkVerdict.pass),
      ),
    ];
    final engine = NetworkSelfTestEngine(contextBuilder: _ctx, probes: probes);

    await _pump(tester, NetworkTroubleshootingPage(engineFactory: () => engine));
    await tester.pump();

    expect(find.byKey(const ValueKey('network-cancel')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('network-cancel')));
    await tester.pump();

    // The first probe was already in flight when cancel() was tapped, so it
    // still finishes on its own — cancel() only stops the ones after it.
    c1.complete(const NetworkCheck(id: NetworkCheckId.methodListening, verdict: NetworkVerdict.pass));
    await tester.pump();
    await tester.pump();

    expect(engine.state.value.result, isNotNull);
    expect(engine.state.value.result!.completed, isFalse);
  });

  // The closing card hands the result to support. It used to be a primary
  // "Send to support" that riders tapped straight after the run, sending the
  // bare bundle with no description — a third of all chats. Now it is never
  // the loudest thing on the page, and on a pass it stops pretending there
  // is a report worth sending: the chat asks what the rider sees instead.
  group('footer', () {
    final footer = find.byKey(const ValueKey('network-footer'));

    testWidgets('pass: "Get help" outline button, pass copy, no primary button anywhere', (tester) async {
      await _pumpFinished(tester, [_probe(NetworkCheckId.methodListening, NetworkVerdict.pass)]);
      final l10n = _l10n(tester);

      expect(footer, findsOneWidget);
      expect(find.text(l10n.networkFooterPassTitle), findsOneWidget);
      expect(find.text(l10n.networkFooterPassBody), findsOneWidget);
      expect(find.text(l10n.networkFooterTitle), findsNothing);

      final getHelp = find.byKey(const ValueKey('network-get-help'));
      expect(find.descendant(of: footer, matching: getHelp), findsOneWidget);
      expect(_varianceOf(tester.widget<Button>(getHelp)), same(ButtonVariance.outline));
      expect(find.byKey(const ValueKey('network-send-support')), findsNothing);

      // Still there: the two things support actually needs.
      expect(find.descendant(of: footer, matching: find.byKey(const ValueKey('network-copy'))), findsOneWidget);
      expect(find.descendant(of: footer, matching: find.text(l10n.logs)), findsOneWidget);

      expect(_primaryButtonsIn(tester, footer), isEmpty);
      // With nothing to fix, there is no recommended-fix primary either: on a
      // clean pass nothing on the page shouts.
      expect(_primaryButtonsIn(tester, find.byType(NetworkTroubleshootingPage)), isEmpty);
    });

    testWidgets('fail: "Send to support" is an outline button, never primary', (tester) async {
      await _pumpFinished(tester, [
        _probe(NetworkCheckId.resolveOwnHostname, NetworkVerdict.fail, fixes: [NetworkFixId.useOsResponderForObc]),
      ]);
      final l10n = _l10n(tester);

      expect(find.text(l10n.networkFooterTitle), findsOneWidget);
      expect(find.text(l10n.networkFooterBody), findsOneWidget);
      expect(find.text(l10n.networkFooterPassTitle), findsNothing);

      final send = find.byKey(const ValueKey('network-send-support'));
      expect(find.descendant(of: footer, matching: send), findsOneWidget);
      expect(tester.widget<Button>(send).child, isA<Text>().having((t) => t.data, 'label', l10n.networkTroubleshootSendToSupport));
      expect(_varianceOf(tester.widget<Button>(send)), same(ButtonVariance.outline));
      expect(find.byKey(const ValueKey('network-get-help')), findsNothing);

      expect(_primaryButtonsIn(tester, footer), isEmpty);
      // The one primary on the page is the recommended fix in the verdict
      // card — the thing a rider should try before writing in.
      expect(find.byKey(const ValueKey('network-recommended-fix')), findsOneWidget);
    });

    for (final verdict in [NetworkVerdict.warn, NetworkVerdict.unknown]) {
      testWidgets('$verdict: same footer as fail', (tester) async {
        await _pumpFinished(tester, [_probe(NetworkCheckId.advertisedAddress, verdict)]);
        final l10n = _l10n(tester);

        expect(find.text(l10n.networkFooterTitle), findsOneWidget);
        expect(find.descendant(of: footer, matching: find.byKey(const ValueKey('network-send-support'))), findsOneWidget);
        expect(find.byKey(const ValueKey('network-get-help')), findsNothing);
        expect(_primaryButtonsIn(tester, footer), isEmpty);
      });
    }
  });

  // The tap itself: a real SupportChatPage gets pushed. Its default
  // SupportChatService() reads `core.supabase`, which ensureSnapshotHarness()
  // has already set up (core.settings.init() runs Supabase.initialize); with
  // no session and no pre-answered intake the page makes no request. What
  // does need taming is _openSupport's debugText(): its diagnostics gather
  // ends in a recordError whose crash-persist path starts another gather —
  // under this file's live binding an endless background chain of 6 s
  // timers — so it is swapped for a plain print, the way
  // proxy_device_details_need_help_test.dart does it.
  group('hand-off to support', () {
    setUpAll(() {
      expect(Supabase.instance.client, isNotNull, reason: 'the harness already initialised Supabase');
      installLoggerErrorListener();
      Logger.onRecordError = (message, error, _) => debugPrint('recordError($message): $error');
    });

    Future<SupportChatPage> tapThrough(WidgetTester tester, String key) async {
      await tester.tap(find.byKey(ValueKey(key)));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byType(SupportChatPage), findsOneWidget);
      return tester.widget<SupportChatPage>(find.byType(SupportChatPage));
    }

    testWidgets('"Get help" on a pass pins the result instead of prefilling it', (tester) async {
      await _pumpFinished(tester, [_probe(NetworkCheckId.methodListening, NetworkVerdict.pass)]);
      final label = _l10n(tester).supportPinnedNetworkTest;

      final chat = await tapThrough(tester, 'network-get-help');

      expect(chat.initialText, isNull, reason: 'the bundle must never be the whole message');
      expect(chat.pinnedContext, startsWith('Network self-test: NETWORK PASS,'));
      expect(chat.pinnedContext, contains('methodListening=pass'));
      expect(chat.pinnedContextLabel, label);
      expect(chat.diagnosticPreviewFuture, isNotNull);
    });

    testWidgets('"Send to support" on a fail hands over the same way', (tester) async {
      await _pumpFinished(tester, [_probe(NetworkCheckId.resolveOwnHostname, NetworkVerdict.fail)]);
      final label = _l10n(tester).supportPinnedNetworkTest;

      final chat = await tapThrough(tester, 'network-send-support');

      expect(chat.initialText, isNull);
      expect(chat.pinnedContext, startsWith('Network self-test: NETWORK FAIL,'));
      expect(chat.pinnedContextLabel, label);
    });
  });

  group('runNetworkFix toasts', () {
    /// A bare page inside the navigatorKey-wired app, so `buildToast()` has
    /// a tree to mount into and `runNetworkFix` gets a real BuildContext.
    Future<BuildContext> pumpHost(WidgetTester tester) async {
      await _pump(tester, const Scaffold(child: SizedBox(key: ValueKey('host'))));
      await tester.pump();
      return tester.element(find.byKey(const ValueKey('host')));
    }

    AppLocalizations l10nOf(BuildContext context) => AppLocalizations.of(context);

    testWidgets('restartMethod while connected refuses with a toast instead of silently', (tester) async {
      core.obpMdnsEmulator.isConnected.value = true;
      final context = await pumpHost(tester);
      final l10n = l10nOf(context);
      final app = core.settings.getTrainerApp()?.name;
      final expected = app == null ? l10n.networkFixRefusedConnectedNoApp : l10n.networkFixRefusedConnected(app);

      final ok = await runNetworkFix(context, NetworkFixId.restartMethod);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(ok, isFalse);
      expect(core.obpMdnsEmulator.isConnected.value, isTrue, reason: 'the live connection was left alone');
      expect(find.text(expected), findsOneWidget);
    });

    testWidgets('a failing non-restart arm toasts the generic failure', (tester) async {
      // url_launcher has no platform implementation under `flutter test`, so
      // openFirewallSettings is a real failing arm here, not a stub.
      final context = await pumpHost(tester);
      final l10n = l10nOf(context);

      final ok = await runNetworkFix(context, NetworkFixId.openFirewallSettings);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(ok, isFalse);
      expect(find.text(l10n.networkFixFailed), findsOneWidget);
    });

    testWidgets('a degraded Bonjour switch toasts the Bonjour-missing message', (tester) async {
      final advertiser = RecordingAdvertiser();
      final previousInstance = ServiceAdvertiser.instance;
      ServiceAdvertiser.instance = advertiser;
      core.obpMdnsEmulator.debugIsWindows = () => true;
      core.obpMdnsEmulator.debugBonjourFactory = () => BonjourServiceAdvertiser(api: FakeBonjourApi(isAvailable: false));
      addTearDown(() async {
        core.obpMdnsEmulator.debugIsWindows = null;
        core.obpMdnsEmulator.debugBonjourFactory = null;
        await core.obpMdnsEmulator.stopServer();
        ServiceAdvertiser.instance = previousInstance;
      });
      final context = await pumpHost(tester);
      final l10n = l10nOf(context);

      final ok = await runNetworkFix(context, NetworkFixId.useOsResponderForObc);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(ok, isFalse);
      expect(core.settings.getObpMdnsBackend(), ObpMdnsBackend.platformDefault);
      expect(find.text(l10n.networkFixBonjourMissing), findsOneWidget);
    });
  });
}
