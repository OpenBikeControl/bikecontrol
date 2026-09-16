import 'package:bike_control/bluetooth/devices/proxy/proxy_device.dart';
import 'package:bike_control/gen/l10n.dart';
import 'package:bike_control/main.dart' show installLoggerErrorListener;
import 'package:bike_control/pages/proxy_device_details/self_test_card.dart';
import 'package:bike_control/pages/support_chat/support_chat_page.dart';
import 'package:bike_control/services/trainer_self_test/self_test_engine.dart';
import 'package:bike_control/services/trainer_self_test/self_test_result.dart';
import 'package:bike_control/utils/actions/base_actions.dart';
import 'package:bike_control/utils/core.dart';
import 'package:bike_control/utils/support/intake_options.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prop/utils/shared.dart' show Logger;
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:universal_ble/universal_ble.dart';

import '../../services/trainer_self_test/fake_self_test_harness.dart';

/// wakelock_plus talks to the host over a pigeon channel that no test binding
/// answers, so every `WakelockPlus.toggle` would reject. Answer it with an
/// empty success reply instead — the card's screen-on handling is not what
/// these tests are about.
const _wakelockChannels = [
  'dev.flutter.pigeon.wakelock_plus_platform_interface.WakelockPlusApi.toggle',
  'dev.flutter.pigeon.wakelock_plus_platform_interface.WakelockPlusApi.isEnabled',
];

void _mockWakelock(bool install) {
  final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  for (final channel in _wakelockChannels) {
    messenger.setMockMessageHandler(
      channel,
      install ? (_) async => const StandardMessageCodec().encodeMessage(<Object?>[null]) : null,
    );
  }
}

Future<void> main() async {
  TestWidgetsFlutterBinding.ensureInitialized();
  await AppLocalizations.load(const Locale('en'));

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    core.settings.prefs = await SharedPreferences.getInstance();
    // core.shiftingConfigs is a `late final` — re-initializing it per test
    // (rather than just reassigning core.settings.prefs) is what actually
    // clears its in-memory list; without this, a config an earlier test
    // upserted would still be sitting there for this one to trip over.
    await core.shiftingConfigs.init();
    core.actionHandler = StubActions();
    _mockWakelock(true);
  });

  tearDown(() => _mockWakelock(false));

  // Connected trainer, no trainer app attached — the state both prechecks pass.
  ProxyDevice connectedTrainer() => ProxyDevice(BleDevice(deviceId: 'x', name: 'KICKR CORE'))..isConnected = true;

  /// One engine tick per `sleep`, but parked behind a zero-duration timer
  /// rather than a bare microtask: `pump()` then leaves the engine mid-run so
  /// the running card can be inspected, and `pumpAndSettle()` drains the whole
  /// test in one go.
  SelfTestEngine engineOver(FakeSelfTestHarness harness) => SelfTestEngine(
    harness: harness,
    sleep: (_) async {
      harness.publishTick();
      await Future<void>.delayed(Duration.zero);
    },
    now: () => DateTime(2026, 8, 20),
  );

  Future<void> pumpCard(
    WidgetTester tester,
    ProxyDevice device,
    FakeSelfTestHarness harness, {
    VoidCallback? onShowOverlaySettings,
    Future<void> Function()? reconnect,
  }) async {
    await tester.pumpWidget(
      ShadcnApp(
        localizationsDelegates: const [AppLocalizations.delegate],
        supportedLocales: AppLocalizations.delegate.supportedLocales,
        home: Scaffold(
          child: SelfTestCard(
            device: device,
            engineFactory: () => engineOver(harness),
            onShowOverlaySettings: onShowOverlaySettings,
            // Keep widget tests off the real connection manager.
            reconnectDevice: reconnect ?? () async {},
          ),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('idle card shows start button when trainer connected', (tester) async {
    await pumpCard(tester, connectedTrainer(), FakeSelfTestHarness());

    expect(find.text('Resistance self-test'), findsOneWidget);
    expect(find.text('Test resistance control'), findsOneWidget);
    // Nothing has run yet, so no phase chrome and no stale result.
    expect(find.text('Stop test'), findsNothing);
    expect(find.textContaining('Last test:'), findsNothing);
  });

  testWidgets('refuses while the trainer app is connected', (tester) async {
    final device = connectedTrainer()..debugSetTrainerAppConnected(true);

    await pumpCard(tester, device, FakeSelfTestHarness());
    await tester.tap(find.text('Test resistance control'));
    await tester.pump();

    expect(find.textContaining('exclusive control'), findsOneWidget);
    // Refusal only — the test must not have started behind the message.
    expect(find.text('Stop test'), findsNothing);
    expect(find.text('Test resistance control'), findsOneWidget);
  });

  testWidgets('refuses while the trainer is disconnected', (tester) async {
    final device = ProxyDevice(BleDevice(deviceId: 'x', name: 'KICKR CORE'));

    await pumpCard(tester, device, FakeSelfTestHarness());
    await tester.tap(find.text('Test resistance control'));
    await tester.pump();

    expect(find.text('Connect your trainer first to run the test.'), findsOneWidget);
    expect(find.text('Stop test'), findsNothing);
  });

  testWidgets('running test shows phase progress and stop button, then a verdict', (tester) async {
    final harness = FakeSelfTestHarness();

    await pumpCard(tester, connectedTrainer(), harness);
    await tester.tap(find.text('Test resistance control'));
    await tester.pump();

    // Mid-run: guidance + a way out, and the start button is gone.
    expect(find.text('Measuring baseline'), findsOneWidget);
    expect(find.text('Pedal at a steady, comfortable pace.'), findsOneWidget);
    expect(find.text('Stop test'), findsOneWidget);
    expect(find.text('Test resistance control'), findsNothing);

    await tester.pumpAndSettle();

    // Obedient trainer → PASS.
    expect(find.text('Your trainer responds correctly'), findsOneWidget);
    expect(find.text('Run again'), findsOneWidget);
    expect(find.text('Stop test'), findsNothing);
    // A non-aborted verdict is persisted per trainer for the support bundle.
    expect(core.settings.getSelfTestResultJson('KICKR CORE'), isNotNull);
  });

  testWidgets('a cadence-less trainer is told so during the run and under the verdict', (tester) async {
    // The card is otherwise silent about cadence, so a rider on a trainer that
    // reports none has no way to know why — or that the shift scoring lost its
    // cross-check. Say it while they pedal, and again with the verdict.
    const notice = "Your trainer doesn't report cadence, so this test scores on power alone.";
    final harness = FakeSelfTestHarness()..reportsCadence = false;

    await pumpCard(tester, connectedTrainer(), harness);
    await tester.tap(find.text('Test resistance control'));
    await tester.pump();
    expect(find.text(notice), findsNothing, reason: 'not until the probe has settled');

    // Probe window: cadenceProbe worth of ticks with nothing arriving.
    for (var i = 0; i < 8; i++) {
      await tester.pump(SelfTestEngine.tick);
    }
    expect(find.text(notice), findsOneWidget);

    await tester.pumpAndSettle();
    expect(find.text('Your trainer responds correctly'), findsOneWidget);
    expect(find.text(notice), findsOneWidget, reason: 'the caveat outlives the run');
  });

  testWidgets('a cadence-reporting trainer never shows the no-cadence notice', (tester) async {
    final harness = FakeSelfTestHarness();
    await pumpCard(tester, connectedTrainer(), harness);
    await tester.tap(find.text('Test resistance control'));
    await tester.pumpAndSettle();
    expect(find.textContaining("doesn't report cadence"), findsNothing);
  });

  testWidgets('Run again starts a second run on a fresh engine', (tester) async {
    final harness = FakeSelfTestHarness();

    await pumpCard(tester, connectedTrainer(), harness);
    await tester.tap(find.text('Test resistance control'));
    await tester.pumpAndSettle();
    expect(find.text('Run again'), findsOneWidget);

    await tester.tap(find.text('Run again'));
    await tester.pump();

    // SelfTestEngine.run is single-shot: a reused engine would hand back the
    // finished result instead of measuring again, so the card would jump
    // straight back to the verdict rather than showing a run in progress.
    expect(find.text('Stop test'), findsOneWidget);
    expect(find.text('Run again'), findsNothing);

    await tester.pumpAndSettle();
    expect(find.text('Your trainer responds correctly'), findsOneWidget);
  });

  testWidgets('Run again refuses when the trainer app attaches after a verdict', (tester) async {
    final harness = FakeSelfTestHarness();
    final device = connectedTrainer();

    await pumpCard(tester, device, harness);
    await tester.tap(find.text('Test resistance control'));
    await tester.pumpAndSettle();
    expect(find.text('Run again'), findsOneWidget);

    device.debugSetTrainerAppConnected(true);
    await tester.tap(find.text('Run again'));
    await tester.pump();

    // The refusal must actually be visible — not silently swallowed behind a
    // stale verdict view that a still-attached finished engine would
    // otherwise keep rendering.
    expect(find.textContaining('exclusive control'), findsOneWidget);
    expect(find.text('Test resistance control'), findsOneWidget);
    // No new run was started.
    expect(find.text('Stop test'), findsNothing);
    expect(find.text('Your trainer responds correctly'), findsNothing);
  });

  testWidgets('PASS verdict offers the overlay CTA and fires the callback', (tester) async {
    var revealed = false;

    await pumpCard(
      tester,
      connectedTrainer(),
      FakeSelfTestHarness(),
      onShowOverlaySettings: () => revealed = true,
    );
    await tester.tap(find.text('Test resistance control'));
    await tester.pumpAndSettle();

    expect(find.text('Your trainer responds correctly'), findsOneWidget);
    expect(find.text('Show gear overlay setup'), findsOneWidget);

    await tester.tap(find.text('Show gear overlay setup'));

    expect(revealed, isTrue);
  });

  testWidgets('ergOkVsFail offers mode switch that flips the fake and reruns', (tester) async {
    final harness = FakeSelfTestHarness()..obeysShift = false;

    await pumpCard(tester, connectedTrainer(), harness);
    await tester.tap(find.text('Test resistance control'));
    await tester.pumpAndSettle();

    expect(find.text("Power targets work, shifting doesn't"), findsOneWidget);
    expect(find.text('Switch mode & run again'), findsOneWidget);
    // Also offered on this verdict — a rider who'd rather just report it.
    expect(find.text('Send result to support'), findsOneWidget);
    expect(harness.vsModeName, 'targetPower');

    await tester.tap(find.text('Switch mode & run again'));
    await tester.pump();

    // The switch flips the fake's recorded mode before the fresh run starts.
    expect(harness.vsModeName, 'trackResistance');
    expect(find.text('Stop test'), findsOneWidget);
    // ... and persists it, mirroring the settings-UI path: the pick must
    // stick past the run rather than reverting on the rider's next connect.
    expect(core.shiftingConfigs.activeFor('KICKR CORE').mode.name, 'trackResistance');

    await tester.pumpAndSettle();
    // obeysShift is still false, so the rerun lands on the same verdict.
    expect(find.text("Power targets work, shifting doesn't"), findsOneWidget);
  });

  testWidgets('ergOkVsFail shows mode switch first, protocol CTA second', (tester) async {
    final harness = FakeSelfTestHarness()
      ..obeysShift = false
      ..supportedProtocolNames = ['ftms', 'zwiftHub'];

    await pumpCard(tester, connectedTrainer(), harness);
    await tester.tap(find.text('Test resistance control'));
    await tester.pumpAndSettle();

    expect(find.text("Power targets work, shifting doesn't"), findsOneWidget);
    expect(find.text('Switch mode & run again'), findsOneWidget);
    expect(find.text('Try via Zwift protocol & run again'), findsOneWidget);

    // The mode switch leads; the protocol CTA is the secondary offer below it.
    final switchModeTop = tester.getTopLeft(find.text('Switch mode & run again')).dy;
    final protocolTop = tester.getTopLeft(find.text('Try via Zwift protocol & run again')).dy;
    expect(switchModeTop, lessThan(protocolTop));
  });

  testWidgets('single-protocol trainer never shows the protocol CTA', (tester) async {
    final harness = FakeSelfTestHarness()..obeysShift = false;
    // supportedProtocolNames defaults to ['ftms'], same as protocolName —
    // nothing else to offer.

    await pumpCard(tester, connectedTrainer(), harness);
    await tester.tap(find.text('Test resistance control'));
    await tester.pumpAndSettle();

    expect(find.text("Power targets work, shifting doesn't"), findsOneWidget);
    expect(find.text('Switch mode & run again'), findsOneWidget);
    expect(find.textContaining('Try via'), findsNothing);
  });

  testWidgets('noControl on a dual-protocol trainer leads with the protocol CTA', (tester) async {
    final harness = FakeSelfTestHarness()
      ..obeysErg = false
      ..obeysShift = false
      ..supportedProtocolNames = ['ftms', 'zwiftHub'];

    var reconnects = 0;
    await pumpCard(tester, connectedTrainer(), harness, reconnect: () async => reconnects++);
    await tester.tap(find.text('Test resistance control'));
    await tester.pumpAndSettle();

    expect(find.text("Trainer isn't responding to BikeControl"), findsOneWidget);
    expect(find.text('Try via Zwift protocol & run again'), findsOneWidget);
    // Support is still offered, but below the protocol CTA.
    expect(find.text('Send result to support'), findsOneWidget);

    await tester.tap(find.text('Try via Zwift protocol & run again'));
    await tester.pump();

    // The tap flips the fake's recorded protocol and cycles the trainer
    // connection before the fresh run starts.
    expect(harness.protocolName, 'zwiftHub');
    expect(reconnects, 1);
    expect(find.text('Stop test'), findsOneWidget);

    await tester.pumpAndSettle();
  });

  testWidgets('noControl offers the support CTA', (tester) async {
    final harness = FakeSelfTestHarness()
      ..obeysErg = false
      ..obeysShift = false;

    await pumpCard(tester, connectedTrainer(), harness);
    await tester.tap(find.text('Test resistance control'));
    await tester.pumpAndSettle();

    expect(find.text("Trainer isn't responding to BikeControl"), findsOneWidget);
    expect(find.text('Send result to support'), findsOneWidget);
    // NO_CONTROL has no mode-switch CTA — the ERG phase failed too.
    expect(find.text('Switch mode & run again'), findsNothing);
    // Single-protocol fake (default supportedProtocolNames) — no other wire
    // to offer.
    expect(find.textContaining('Try via'), findsNothing);
  });

  testWidgets('last-result chip renders when a stored result exists', (tester) async {
    final stored = SelfTestResult(
      at: DateTime(2026, 8, 19),
      verdict: SelfTestVerdict.pass,
      ergStepsPassed: 3,
      ergStepsTotal: 3,
      shiftStepsPassed: 2,
      shiftStepsTotal: 3,
      vsMode: 'targetPower',
      protocol: 'ftms',
    );
    await core.settings.setSelfTestResultJson('KICKR CORE', stored.toJsonString());

    await pumpCard(tester, connectedTrainer(), FakeSelfTestHarness());

    expect(find.textContaining('Last test:'), findsOneWidget);
    expect(find.text('Test resistance control'), findsOneWidget);
  });

  testWidgets('keep-pedaling banner shows when pausedForCadence', (tester) async {
    final harness = FakeSelfTestHarness()..riderCadence = 0;
    final engine = SelfTestEngine(
      harness: harness,
      sleep: (d) async {
        harness.publishTick();
        await Future<void>.delayed(d);
      },
      now: () => DateTime(2026, 8, 20),
    );

    await tester.pumpWidget(
      ShadcnApp(
        localizationsDelegates: const [AppLocalizations.delegate],
        supportedLocales: AppLocalizations.delegate.supportedLocales,
        home: Scaffold(
          child: SelfTestCard(device: connectedTrainer(), engineFactory: () => engine),
        ),
      ),
    );
    await tester.pump();
    await tester.tap(find.text('Test resistance control'));
    await tester.pump();

    // Cadence stuck at 0 rpm throughout: precheck passes immediately (power
    // still flows), then baseline's pause watchdog arms and, after the 4s
    // low-cadence threshold, pauses — well short of the 20s timeout that
    // would abort the run.
    for (var i = 0; i < 15; i++) {
      await tester.pump(SelfTestEngine.tick);
    }

    expect(find.text('Keep pedaling to continue the test'), findsOneWidget);
    expect(find.text('Stop test'), findsOneWidget);

    // Drain the engine's own pending tick before the test ends — cancel()
    // only flags intent; the tick already in flight has to actually fire
    // (pumpAndSettle alone won't advance far enough to reach it on its own)
    // before the abort can cascade through, or the un-awaited Timer left
    // running past teardown fails the test binding's own invariant check.
    engine.cancel();
    await tester.pump(SelfTestEngine.tick);
    await tester.pumpAndSettle();
  });

  testWidgets('cancel produces an aborted verdict that is not persisted', (tester) async {
    final harness = FakeSelfTestHarness();

    await pumpCard(tester, connectedTrainer(), harness);
    await tester.tap(find.text('Test resistance control'));
    await tester.pump();
    expect(find.text('Stop test'), findsOneWidget);

    await tester.tap(find.text('Stop test'));
    await tester.pump();

    // Disabled while the aborted verdict is still in flight — a second tap
    // must not race the engine's own cancel → restore → finish sequence.
    expect(tester.widget<Button>(find.widgetWithText(Button, 'Stop test')).onPressed, isNull);

    await tester.pumpAndSettle();

    expect(find.text('Test stopped'), findsOneWidget);
    // Aborted runs measured nothing worth keeping.
    expect(core.settings.getSelfTestResultJson('KICKR CORE'), isNull);
  });

  // The hand-off itself: a real SupportChatPage gets pushed, so this needs
  // the same scaffolding proxy_device_details_need_help_test.dart uses — the
  // page's default SupportChatService() reads `core.supabase`, which has to
  // exist (pointed at a loopback port nothing listens on, so the intake
  // form's known-issues fetch is refused at once), and _openSupport's
  // debugText() gather ends in a recordError whose crash-persist path would
  // start a second 6 s gather under fake async; swapped for a plain print.
  group('hand-off to support', () {
    setUpAll(() async {
      installLoggerErrorListener();
      Logger.onRecordError = (message, error, _) => debugPrint('recordError($message): $error');
      // Supabase.initialize reads SharedPreferences; the per-test setUp that
      // mocks them runs after this setUpAll.
      SharedPreferences.setMockInitialValues({});
      await Supabase.initialize(
        url: 'http://127.0.0.1:9',
        anonKey: 'self-test-card-test-anon-key',
        debug: false,
        authOptions: const FlutterAuthClientOptions(
          localStorage: EmptyLocalStorage(),
          detectSessionInUri: false,
          autoRefreshToken: false,
        ),
      );
    });

    testWidgets('"Send result to support" pins the result below an empty composer, intake kept', (tester) async {
      final harness = FakeSelfTestHarness()
        ..obeysErg = false
        ..obeysShift = false;
      await pumpCard(tester, connectedTrainer(), harness);
      await tester.tap(find.text('Test resistance control'));
      await tester.pumpAndSettle();
      final l10n = AppLocalizations.of(tester.element(find.byType(SelfTestCard)));

      await tester.tap(find.text('Send result to support'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.byType(SupportChatPage), findsOneWidget);
      final chat = tester.widget<SupportChatPage>(find.byType(SupportChatPage));
      expect(chat.initialText, isNull, reason: 'the bundle must never be the whole message');
      expect(chat.pinnedContext, startsWith('Resistance self-test: NO_CONTROL,'));
      expect(chat.pinnedContextLabel, l10n.supportPinnedResistanceTest);
      expect(
        chat.initialIntake?.toJson(),
        const IntakeAnswers(
          category: IntakeCategory.smartTrainer,
          subcategory: 'issue',
          subcategoryValue: 'no_resistance_change',
        ).toJson(),
        reason: 'the intake still rides along',
      );
      // The intake is pre-answered, so the composer is right there: chip on,
      // input empty, send off until the rider says what they see.
      expect(find.text(l10n.supportPinnedContextChip(l10n.supportPinnedResistanceTest)), findsOneWidget);
      expect(tester.widget<TextArea>(find.byType(TextArea)).controller!.text, isEmpty);
      final send = find.ancestor(of: find.byIcon(LucideIcons.send), matching: find.byType(IconButton));
      expect(tester.widget<IconButton>(send).onPressed, isNull);

      // Drain debugText()'s 6 s diagnostics timeout so nothing is left pending.
      await tester.pump(const Duration(seconds: 7));
    });
  });
}
