// Task 14: the app card's chain-card and onboarding entry points into the
// network troubleshooter both gate on the same pure predicate. These tests
// pin down appCardOffersTroubleshooting itself, independent of the widgets
// that read it.
//
// The signals grid used to have its own mount + gating predicate here
// (`signalsGridHasContent`) — removed per direct author feedback ("the
// sensor tiles suddenly landed on the front page - don't put them there").
// `LiveMetricsSection` now only ever mounts on a trainer's own
// `ProxyDeviceDetailsPage` — see that page's own test file — so the one test
// below proves Home renders none of it even in a scenario the deleted
// predicate used to treat as "show the grid".
import 'dart:io';
import 'dart:typed_data';

import 'package:bike_control/bluetooth/devices/hid/hid_device.dart';
import 'package:bike_control/bluetooth/devices/proxy/proxy_device.dart';
import 'package:bike_control/gen/l10n.dart';
import 'package:bike_control/main.dart' show screenshotMode;
import 'package:bike_control/models/remembered_device.dart';
import 'package:bike_control/pages/home/chain_state.dart';
import 'package:bike_control/pages/home/home_page.dart';
import 'package:bike_control/pages/network_troubleshooting_page.dart';
import 'package:bike_control/pages/proxy_device_details/metric_card.dart';
import 'package:bike_control/pages/sensors/sensors_page.dart';
import 'package:bike_control/services/overlay/trainer_overlay_service.dart';
import 'package:bike_control/services/sensors/broadcast_controller.dart';
import 'package:bike_control/services/sensors/fake_sensor_source.dart';
import 'package:bike_control/services/sensors/sensor_quantity.dart';
import 'package:bike_control/utils/core.dart';
import 'package:bike_control/utils/keymap/apps/my_whoosh.dart';
import 'package:bike_control/utils/keymap/apps/training_peaks.dart';
import 'package:bike_control/utils/requirements/multi.dart' show Target;
import 'package:bike_control/widgets/home/ampel.dart';
import 'package:bike_control/widgets/home/chain_card.dart';
import 'package:bike_control/widgets/home/ready_banner.dart';
import 'package:flutter/services.dart' show SystemChannels;
import 'package:flutter_test/flutter_test.dart';
import 'package:prop/emulators/definitions/fitness_bike_definition.dart';
import 'package:prop/emulators/dircon_emulator.dart';
import 'package:prop/utils/network_address.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:universal_ble/universal_ble.dart';

import '../../widget_snapshot.dart';

ChainLink _appLink({required bool appConnected, bool wasConnectedThisSession = false, bool dropped = false}) {
  return ChainLink(
    key: ChainLinkKey.app,
    id: 'app',
    status: LinkStatus.attention,
    title: 'MyWhoosh',
    wasConnectedThisSession: wasConnectedThisSession,
    dropped: dropped,
    steps: [
      SetupStep(id: SetupStepId.appSelected, done: true),
      SetupStep(id: SetupStepId.appConnectionMethod, done: true),
      SetupStep(id: SetupStepId.appConnected, done: appConnected),
    ],
  );
}

Future<void> main() async {
  await ensureSnapshotHarness();

  setUp(() {
    core.settings.setTrainerApp(MyWhoosh());
    core.settings.setObpMdnsEnabled(true);
    core.obpMdnsEmulator.isStarted.value = true;
  });

  tearDown(() {
    core.obpMdnsEmulator.isStarted.value = false;
    core.settings.setObpMdnsEnabled(false);
    core.connection.devices.clear();
  });

  group('appCardOffersTroubleshooting', () {
    testWidgets('true once the app link is waiting to connect, mDNS is enabled and the emulator is up', (tester) async {
      expect(appCardOffersTroubleshooting(_appLink(appConnected: false)), isTrue);
    });

    testWidgets('false once the app has actually connected', (tester) async {
      expect(appCardOffersTroubleshooting(_appLink(appConnected: true)), isFalse);
    });

    // Once the connection has worked in this session, a drop is almost never
    // something the network self-test can fix — usually the app was closed.
    testWidgets('false for an app that connected earlier in this session and dropped', (tester) async {
      expect(
        appCardOffersTroubleshooting(_appLink(appConnected: false, wasConnectedThisSession: true, dropped: true)),
        isFalse,
      );
    });

    // Not "dropped" — it still holds the trainer, so only its controller tile
    // is missing — but it did connect, and that is what the rule is about.
    testWidgets('false for an app that connected earlier and still holds the trainer', (tester) async {
      expect(appCardOffersTroubleshooting(_appLink(appConnected: false, wasConnectedThisSession: true)), isFalse);
    });

    testWidgets('false for a link that is not the app link', (tester) async {
      final link = ChainLink(
        key: ChainLinkKey.trainer,
        id: 'trainer',
        status: LinkStatus.attention,
        title: 'Trainer',
        steps: [SetupStep(id: SetupStepId.appConnected, done: false)],
      );
      expect(appCardOffersTroubleshooting(link), isFalse);
    });

    testWidgets('false when Network mDNS is disabled', (tester) async {
      core.settings.setObpMdnsEnabled(false);
      expect(appCardOffersTroubleshooting(_appLink(appConnected: false)), isFalse);
    });

    testWidgets('false when the mDNS emulator has not started', (tester) async {
      core.obpMdnsEmulator.isStarted.value = false;
      expect(appCardOffersTroubleshooting(_appLink(appConnected: false)), isFalse);
    });
  });

  testWidgets('a bridged trainer no longer makes Home render the signals grid', (tester) async {
    // Deliberately off: `ensureSnapshotHarness` leaves this on, and the grid
    // used to be suppressed under it regardless of the (now-deleted) gate —
    // proving absence there would not prove the mount itself is gone.
    final wasScreenshotMode = screenshotMode;
    screenshotMode = false;
    addTearDown(() => screenshotMode = wasScreenshotMode);

    // A bridged trainer used to be one of `signalsGridHasContent`'s two
    // independent "show the grid" triggers — the strongest case to prove it
    // no longer has any effect at all.
    final trainer = ProxyDevice(BleDevice(deviceId: 'kickr-bridged-home', name: 'Wahoo KICKR'))
      ..debugSetTrainerAppConnected(true);
    core.connection.devices.add(trainer);

    await tester.pumpWidget(
      ShadcnApp(
        localizationsDelegates: [
          ...ShadcnLocalizations.localizationsDelegates,
          AppLocalizations.delegate,
        ],
        supportedLocales: const [Locale('en')],
        home: Scaffold(child: HomePage(isMobile: true, onUpdate: () {})),
      ),
    );
    await tester.pump();

    expect(find.byKey(const ValueKey('live-metrics')), findsNothing);
    expect(find.byType(MetricCard), findsNothing);

    // Unmount before the test ends: with `screenshotMode` off, HomePage's own
    // periodic metrics timer is running, and `flutter_test` fails a test that
    // leaves a pending timer behind — `State.dispose()` cancels it.
    await tester.pumpWidget(const SizedBox());
  });

  _sensorsOnlyTests();
  _overlayStepTests();
  _twoPairingsTests();
  _networkAddressStepTests();
  _bannerShowTests();
  _droppedAppTests();
}

// ── The banner's "Show" with several cards outstanding (Task 11) ───────────
//
// "2 steps left" across two cards used to open whichever card came first —
// the controller search, say — which reads as arbitrary. With several cards
// outstanding the button now takes the rider to them and makes them jump out.

void _bannerShowTests() {
  group('the banner with several cards outstanding', () {
    late AppLocalizations l;

    setUp(() {
      l = AppLocalizations.current;
    });

    tearDown(() {
      core.obpMdnsEmulator.isConnected.value = false;
      // The controller setup sheet's scan widget starts a (screenshot-mode)
      // scan, and `core` outlives the test.
      core.connection.isScanning.value = false;
    });

    Finder showButton() => find.descendant(of: find.byType(ReadyBanner), matching: find.text(l.chainBannerShow));
    Finder highlighted(String linkId) => find.byKey(chainCardHighlightKey(linkId));

    // The shell's mobile layout: the chain in its own scroll view, inset 12 a
    // side, on the first page of the tab pager. [accessibility] is the
    // platform's own setting, the way a phone reports it.
    Future<({PageController pager, ScrollController chain})> pumpPagedHome(
      WidgetTester tester, {
      FakeAccessibilityFeatures? accessibility,
    }) async {
      tester.view.physicalSize = const Size(400, 520);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      if (accessibility != null) {
        tester.platformDispatcher.accessibilityFeaturesTestValue = accessibility;
        addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
      }
      final pager = PageController();
      final chain = ScrollController();
      addTearDown(pager.dispose);
      addTearDown(chain.dispose);

      await tester.pumpWidget(
        ShadcnApp(
          localizationsDelegates: [
            ...ShadcnLocalizations.localizationsDelegates,
            AppLocalizations.delegate,
          ],
          supportedLocales: const [Locale('en')],
          home: Scaffold(
            child: PageView(
              controller: pager,
              children: [
                SingleChildScrollView(
                  controller: chain,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: HomePage(isMobile: true, onUpdate: () {}),
                ),
                const SizedBox(),
              ],
            ),
          ),
        ),
      );
      await tester.pump();
      return (pager: pager, chain: chain);
    }

    testWidgets('"Show" highlights every outstanding card instead of opening the first one', (tester) async {
      // A fresh install: no controller yet, and MyWhoosh waiting for its
      // connection — two outstanding cards.
      await _pumpHome(tester);
      expect(showButton(), findsOneWidget);

      await tester.tap(showButton());
      await tester.pump();

      // Both outstanding cards jump out, and only those: the empty trainer
      // slot is optional and blocks nothing.
      expect(highlighted('controller'), findsOneWidget);
      expect(highlighted('app'), findsOneWidget);
      expect(highlighted('trainer'), findsNothing);

      // The controller search the first card would have opened never does.
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text(l.connectControllers), findsNothing);

      // A highlight is a moment, not a state.
      await tester.pump(const Duration(milliseconds: 1500));
      expect(highlighted('controller'), findsNothing);
      expect(highlighted('app'), findsNothing);
    });

    testWidgets('with one card outstanding, "Show" still opens that card', (tester) async {
      // MyWhoosh is receiving, so the empty controller slot is all that is left.
      core.obpMdnsEmulator.isConnected.value = true;
      await _pumpHome(tester);
      expect(tester.widget<ChainCard>(_chainCard(ChainLinkKey.app)).link.status, LinkStatus.ready);

      await tester.tap(showButton());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text(l.connectControllers), findsOneWidget);
      expect(highlighted('controller'), findsNothing);
    });

    testWidgets('"Show" scrolls the chain to the first outstanding card, and only the chain', (tester) async {
      final (:pager, :chain) = await pumpPagedHome(tester);
      expect(chain.offset, 0);

      await tester.tap(showButton());
      // What the highlights did is noted inside the loop, so a slow machine
      // cannot pump past one that has already come and gone.
      double? offsetWhenHighlighted;
      var sawApp = false;
      for (var i = 0; i < 20; i++) {
        await tester.pump(const Duration(milliseconds: 40));
        // Revealing the card goes through every scrollable above it, the tab
        // pager included — and the rider must stay on the page they are on.
        expect(pager.position.pixels, 0, reason: 'the tab pager must not move');
        if (offsetWhenHighlighted == null && tester.any(highlighted('controller'))) {
          offsetWhenHighlighted = chain.offset;
        }
        sawApp |= tester.any(highlighted('app'));
      }

      expect(chain.offset, greaterThan(0));
      final viewportTop = tester.getTopLeft(find.byType(PageView)).dy;
      final cardTop = tester.getTopLeft(_chainCard(ChainLinkKey.controller)).dy;
      expect(cardTop - viewportTop, inInclusiveRange(0, 40), reason: 'the first outstanding card sits near the top');
      // Both cards jumped out — the first one only once it had arrived.
      expect(offsetWhenHighlighted, isNotNull, reason: 'the controller card was never highlighted');
      expect(offsetWhenHighlighted, moreOrLessEquals(chain.offset, epsilon: 0.5));
      expect(sawApp, isTrue, reason: 'the app card was never highlighted');
    });

    // Android's "Remove animations" reaches MediaQuery and every animation
    // controller alike.
    testWidgets('with animations turned off, the chain jumps and the border still flashes', (tester) async {
      final (:pager, :chain) = await pumpPagedHome(
        tester,
        accessibility: const FakeAccessibilityFeatures(disableAnimations: true),
      );

      await tester.tap(showButton());
      // A jump has landed before the next frame; a glide would not have
      // started yet.
      expect(chain.offset, greaterThan(0));

      await tester.pump();
      expect(pager.position.pixels, 0);
      expect(highlighted('controller'), findsOneWidget);
      expect(highlighted('app'), findsOneWidget);

      // Still there a few frames later: the setting must not squeeze the
      // flash into a single frame.
      await tester.pump(const Duration(milliseconds: 125));
      expect(highlighted('controller'), findsOneWidget);
      expect(highlighted('app'), findsOneWidget);
    });

    // iOS's Reduce Motion arrives on its own flag, which MediaQuery does not
    // carry.
    testWidgets('with Reduce Motion on, the chain jumps too', (tester) async {
      final (:pager, :chain) = await pumpPagedHome(
        tester,
        accessibility: const FakeAccessibilityFeatures(reduceMotion: true),
      );

      await tester.tap(showButton());
      expect(chain.offset, greaterThan(0), reason: 'a jump lands before the next frame, a glide has not started');

      await tester.pump();
      expect(pager.position.pixels, 0);
      expect(highlighted('controller'), findsOneWidget);
      expect(highlighted('app'), findsOneWidget);
    });

    // The highlight plays once the chain has arrived, and by then the rider
    // may have finished one of the cards.
    testWidgets('a card that is done by the time the chain arrives is not highlighted', (tester) async {
      await pumpPagedHome(tester);

      await tester.tap(showButton());
      // MyWhoosh connects while the chain is still gliding, and the page
      // redraws with it.
      core.obpMdnsEmulator.isConnected.value = true;
      tester.element(find.byType(HomePage)).markNeedsBuild();

      var sawController = false;
      var sawApp = false;
      for (var i = 0; i < 20; i++) {
        await tester.pump(const Duration(milliseconds: 40));
        sawController |= tester.any(highlighted('controller'));
        sawApp |= tester.any(highlighted('app'));
      }

      expect(tester.widget<ChainCard>(_chainCard(ChainLinkKey.app)).link.status, LinkStatus.ready);
      expect(sawController, isTrue, reason: 'the controller card is still outstanding');
      expect(sawApp, isFalse, reason: 'the app card was done before the highlight played');
    });
  });
}

// ── Two pairings in the trainer app (Task 3) ───────────────────────────────
//
// The trainer app's pairing screen has two BikeControl tiles — the trainer
// and the controller — and riders regularly pair one without the other, or
// pair the trainer under its own name and bypass BikeControl entirely. Each
// state has to say which of the two is missing and which entry to pick.

void _twoPairingsTests() {
  group('two pairings in the trainer app', () {
    late AppLocalizations l;

    setUp(() {
      l = AppLocalizations.current;
    });

    tearDown(() {
      core.obpMdnsEmulator.isConnected.value = false;
    });

    /// A trainer whose bridge is running. [heldByApp] is whether the trainer
    /// app has already picked the virtual trainer up.
    ProxyDevice bridgedTrainer({required bool heldByApp}) {
      final trainer = ProxyDevice(BleDevice(deviceId: 'kickr-two-pairings', name: 'KICKR CORE 1234'));
      if (heldByApp) {
        trainer.debugSetTrainerAppConnected(true);
      } else {
        trainer.emulator.isStarted.value = true;
      }
      core.connection.devices.add(trainer);
      return trainer;
    }

    testWidgets('app card: once the app holds the trainer, the hint names the controller tile', (tester) async {
      bridgedTrainer(heldByApp: true);

      await _pumpHome(tester);

      expect(find.text(l.chainStepAppControllerPending('MyWhoosh')), findsOneWidget);
      expect(find.textContaining('separate tile from the trainer'), findsOneWidget);
      expect(find.text(l.chainStepAppConnectedPending('MyWhoosh')), findsNothing);
    });

    testWidgets('app card: while the bridge is not picked up yet, the ordinary wording stays', (tester) async {
      bridgedTrainer(heldByApp: false);

      await _pumpHome(tester);

      expect(find.text(l.chainStepAppConnectedPending('MyWhoosh')), findsOneWidget);
      expect(find.textContaining('separate tile from the trainer'), findsNothing);
    });

    testWidgets('trainer card: the pick-up hint names the bridge entry and the one to avoid', (tester) async {
      final trainer = bridgedTrainer(heldByApp: false);

      await _pumpHome(tester);

      expect(
        find.text(l.chainStepTrainerBridgedHint2('MyWhoosh', trainer.advertisementName, 'KICKR CORE 1234')),
        findsOneWidget,
      );
      expect(find.text(l.chainStepTrainerBridgedHint(trainer.advertisementName, 'MyWhoosh')), findsNothing);
    });

    // The status line only: the pick-up step's own label reads the same as
    // the new status, so a bare text finder would match the checklist too.
    Finder statusText(String text) => find.descendant(of: find.byType(StatusLine), matching: find.text(text));

    testWidgets('trainer card: with the app already connected, the status says it has not picked the trainer up', (
      tester,
    ) async {
      bridgedTrainer(heldByApp: false);
      core.obpMdnsEmulator.isConnected.value = true;

      await _pumpHome(tester);

      expect(statusText(l.chainStatusWaitingForPickup('MyWhoosh')), findsOneWidget);
      expect(statusText(l.onboardingSummaryWaitingFor('MyWhoosh')), findsNothing);
    });

    testWidgets('trainer card: with the app not connected at all, the status keeps waiting for it', (tester) async {
      bridgedTrainer(heldByApp: false);

      await _pumpHome(tester);

      expect(statusText(l.onboardingSummaryWaitingFor('MyWhoosh')), findsOneWidget);
      expect(statusText(l.chainStatusWaitingForPickup('MyWhoosh')), findsNothing);
    });

    testWidgets('trainer card: once the app holds the trainer, the status is simply bridged', (tester) async {
      bridgedTrainer(heldByApp: true);

      await _pumpHome(tester);

      expect(statusText(l.chainStatusBridged), findsOneWidget);
      expect(statusText(l.chainStatusWaitingForPickup('MyWhoosh')), findsNothing);
    });
  });
}

// ── Sensors-only mode (Task 7) ─────────────────────────────────────────────

Finder _chainCard(ChainLinkKey key) =>
    find.byWidgetPredicate((w) => w is ChainCard && w.link.key == key, description: 'ChainCard(${key.name})');

Future<void> _pumpHome(WidgetTester tester, {List<NavigatorObserver> navigatorObservers = const []}) async {
  await tester.pumpWidget(
    ShadcnApp(
      localizationsDelegates: [
        ...ShadcnLocalizations.localizationsDelegates,
        AppLocalizations.delegate,
      ],
      supportedLocales: const [Locale('en')],
      navigatorObservers: navigatorObservers,
      home: Scaffold(child: HomePage(isMobile: true, onUpdate: () {})),
    ),
  );
  await tester.pump();
}

void _sensorsOnlyTests() {
  group('sensors-only mode', () {
    late AppLocalizations l;

    setUp(() async {
      l = AppLocalizations.current;
      await core.settings.setSensorsOnlyMode(false);
    });

    tearDown(() async {
      final broadcast = core.connection.broadcast;
      if (broadcast != null) {
        await broadcast.turnOff();
        core.connection.broadcast = null;
      }
      for (final q in SensorQuantity.values) {
        core.sensors.select(q, null);
      }
      for (final source in core.sensors.sources.toList()) {
        core.sensors.unregister(source.id);
      }
      await core.settings.setSensorsOnlyMode(false);
      core.connection.rememberedTrainer = null;
      core.connection.standaloneClientConnected = ValueNotifier(false);
    });

    testWidgets('no trainer: the trainer card offers "Share sensors instead", and tapping it swaps in the Sensors card', (
      tester,
    ) async {
      // setUp above selects MyWhoosh as the trainer app, so the footer's
      // question names it rather than asking the app-agnostic question —
      // covered separately below for the no-app-selected case.
      await _pumpHome(tester);

      expect(_chainCard(ChainLinkKey.trainer), findsOneWidget);
      expect(_chainCard(ChainLinkKey.sensors), findsNothing);
      final footer = find.byKey(const Key('chain-card-footer'));
      expect(footer, findsOneWidget);
      expect(find.text(l.sensorsUseSensorsOnlyQuestionApp('MyWhoosh')), findsOneWidget);
      expect(find.text(l.sensorsUseSensorsOnly), findsOneWidget);

      await tester.tap(find.text(l.sensorsUseSensorsOnly));
      await tester.pump();

      expect(core.settings.getSensorsOnlyMode(), isTrue);
      expect(_chainCard(ChainLinkKey.sensors), findsOneWidget);
      expect(_chainCard(ChainLinkKey.trainer), findsNothing);
      // The trainer card's own footer is gone with it — but the Sensors card
      // that replaced it carries the reverse offer ("Connect a trainer"),
      // covered by its own tests below.
      expect(find.text(l.sensorsUseSensorsOnlyQuestionApp('MyWhoosh')), findsNothing);
      expect(find.text(l.sensorsConnectTrainerQuestion), findsOneWidget);
      // The strip's tap is its own — it must not fall through to the card
      // and open the trainer connect sheet underneath.
      await tester.pumpAndSettle();
      expect(find.text(l.close), findsNothing);
    });

    testWidgets('no trainer, no app selected: the trainer card asks the app-agnostic question', (tester) async {
      // Unlike the test above, no trainer app is selected here — the footer
      // falls back to the app-agnostic phrasing instead of naming one.
      await core.settings.prefs.remove('trainer_app');
      await _pumpHome(tester);

      final footer = find.byKey(const Key('chain-card-footer'));
      expect(footer, findsOneWidget);
      expect(find.text(l.sensorsUseSensorsOnlyQuestion), findsOneWidget);
      expect(find.text(l.sensorsUseSensorsOnly), findsOneWidget);
    });

    // Task: the reverse affordance — once sensors-only mode has hidden the
    // trainer card, the only way back was a trainer auto-connecting. The
    // Sensors card now offers the same footer strip, mirroring the trainer
    // card's entry into the mode.
    testWidgets('sensors-only mode: the Sensors card offers "Connect a trainer"', (tester) async {
      await core.settings.setSensorsOnlyMode(true);
      await _pumpHome(tester);

      expect(_chainCard(ChainLinkKey.sensors), findsOneWidget);
      final footer = find.byKey(const Key('chain-card-footer'));
      expect(footer, findsOneWidget);
      expect(find.text(l.sensorsConnectTrainerQuestion), findsOneWidget);
      expect(find.text(l.sensorsConnectTrainer), findsOneWidget);
    });

    testWidgets('tapping "Connect a trainer" leaves sensors-only mode and opens the trainer connect sheet', (
      tester,
    ) async {
      await core.settings.setSensorsOnlyMode(true);
      await _pumpHome(tester);

      await tester.tap(find.text(l.sensorsConnectTrainer));
      await tester.pumpAndSettle();

      expect(core.settings.getSensorsOnlyMode(), isFalse);
      expect(_chainCard(ChainLinkKey.trainer), findsOneWidget);
      expect(_chainCard(ChainLinkKey.sensors), findsNothing);
      // The same sheet the trainer card's own Connect opens — its "Close"
      // button is the marker the sibling test inverts (see the "no trainer"
      // test above, which asserts this same text is ABSENT).
      expect(find.text(l.close), findsOneWidget);
    });

    testWidgets('tapping "Connect a trainer" while Broadcast is on does not tear down the broadcast', (tester) async {
      await core.settings.setSensorsOnlyMode(true);
      final strap = FakeSensorSource(id: 'strap-1', displayName: 'Polar H10', provides: {SensorQuantity.heartRate});
      core.sensors.register(strap);
      core.sensors.select(SensorQuantity.heartRate, strap.id);
      var disconnectCalls = 0;
      final broadcast = BroadcastController(
        hub: core.sensors,
        settings: core.settings,
        connectSource: (_) async {},
        disconnectSource: (_) async {
          disconnectCalls++;
        },
        isBridgeRunning: ValueNotifier(false),
        isStandaloneRunning: () => true,
      );
      core.connection.broadcast = broadcast;
      await broadcast.turnOn();
      expect(broadcast.isOn.value, isTrue);

      await _pumpHome(tester);

      await tester.tap(find.text(l.sensorsConnectTrainer));
      await tester.pumpAndSettle();

      // Leaving sensors-only mode is not "stop broadcasting" — Decision 6:
      // the sink keeps standalone until a trainer actually bridges.
      expect(broadcast.isOn.value, isTrue);
      expect(disconnectCalls, 0);
    });

    testWidgets('nothing selected: titled "No sensors yet", status "Off — tap to set up"', (tester) async {
      await core.settings.setSensorsOnlyMode(true);
      await _pumpHome(tester);

      expect(_chainCard(ChainLinkKey.sensors), findsOneWidget);
      expect(find.text(l.sensorsNoSensorsYet), findsOneWidget);
      expect(find.text(l.sensorsStatusOffSetup), findsOneWidget);
      expect(find.text(l.sensorsOpen), findsOneWidget);
    });

    testWidgets('a selection with Broadcast off: titled after the source, status "Off", no chips', (tester) async {
      await core.settings.setSensorsOnlyMode(true);
      final strap = FakeSensorSource(id: 'strap-1', displayName: 'Polar H10', provides: {SensorQuantity.heartRate});
      core.sensors.register(strap);
      core.sensors.select(SensorQuantity.heartRate, strap.id);
      core.connection.broadcast = BroadcastController(
        hub: core.sensors,
        settings: core.settings,
        connectSource: (_) async {},
        disconnectSource: (_) async {},
        isBridgeRunning: ValueNotifier(false),
        isStandaloneRunning: () => true,
      );
      await _pumpHome(tester);

      expect(find.text('Polar H10'), findsOneWidget);
      expect(find.text(l.sensorsStatusOff), findsOneWidget);
      expect(find.byKey(const Key('sensors-chip-heartRate')), findsNothing);
    });

    testWidgets('broadcasting: status says so, meta names the transport, and live chips appear', (tester) async {
      await core.settings.setSensorsOnlyMode(true);
      await core.settings.setSensorsTransport(RetrofitMode.bluetooth);
      final strap = FakeSensorSource(id: 'strap-1', displayName: 'Polar H10', provides: {SensorQuantity.heartRate});
      final pedals = FakeSensorSource(
        id: 'pedals-1',
        displayName: 'Assioma DUO',
        provides: {SensorQuantity.power, SensorQuantity.cadence},
      );
      core.sensors.register(strap);
      core.sensors.register(pedals);
      core.sensors.select(SensorQuantity.heartRate, strap.id);
      core.sensors.select(SensorQuantity.power, pedals.id);
      core.sensors.select(SensorQuantity.cadence, pedals.id);
      strap.emit(SensorQuantity.heartRate, 133);
      pedals.emit(SensorQuantity.power, 250);
      pedals.emit(SensorQuantity.cadence, 90);
      final broadcast = BroadcastController(
        hub: core.sensors,
        settings: core.settings,
        connectSource: (_) async {},
        disconnectSource: (_) async {},
        isBridgeRunning: ValueNotifier(false),
        isStandaloneRunning: () => true,
      );
      core.connection.broadcast = broadcast;
      await broadcast.turnOn();
      expect(broadcast.isOn.value, isTrue);

      await _pumpHome(tester);

      expect(_chainCard(ChainLinkKey.sensors), findsOneWidget);
      expect(find.text('Polar H10'), findsOneWidget);
      expect(find.text(l.sensorsStatusBroadcasting), findsOneWidget);
      // The other sources ride a sub line; the meta names the transport.
      expect(find.byKey(chainCardSubtitleKey), findsOneWidget);
      expect(find.text(l.sensorsWith('Assioma DUO')), findsOneWidget);
      expect(find.text(l.sensorsTransportBluetooth), findsOneWidget);
      expect(find.byKey(const Key('sensors-chip-heartRate')), findsOneWidget);
      expect(find.byKey(const Key('sensors-chip-power')), findsOneWidget);
      expect(find.byKey(const Key('sensors-chip-cadence')), findsOneWidget);
      expect(find.text('133'), findsOneWidget);
      expect(find.text('250'), findsOneWidget);
      expect(find.text('90'), findsOneWidget);
    });

    testWidgets('while broadcasting, the meta names the app holding the peripheral', (tester) async {
      await core.settings.setSensorsOnlyMode(true);
      await core.settings.setSensorsTransport(RetrofitMode.wifi);
      final strap = FakeSensorSource(id: 'strap-1', displayName: 'Polar H10', provides: {SensorQuantity.heartRate});
      core.sensors.register(strap);
      core.sensors.select(SensorQuantity.heartRate, strap.id);
      final broadcast = BroadcastController(
        hub: core.sensors,
        settings: core.settings,
        connectSource: (_) async {},
        disconnectSource: (_) async {},
        isBridgeRunning: ValueNotifier(false),
        isStandaloneRunning: () => true,
      );
      core.connection.broadcast = broadcast;
      await broadcast.turnOn();
      core.connection.standaloneClientConnected = ValueNotifier(true);

      await _pumpHome(tester);

      expect(
        find.text('${l.sensorsTransportNetwork} · ${l.sensorsClientConnected(MyWhoosh().name)}'),
        findsOneWidget,
      );
    });

    testWidgets('a connected trainer ends sensors-only mode and puts the trainer card back', (tester) async {
      await core.settings.setSensorsOnlyMode(true);
      final trainer = ProxyDevice(BleDevice(deviceId: 'kickr-sensors-exit', name: 'Wahoo KICKR'))
        ..debugSetTrainerAppConnected(true);
      core.connection.devices.add(trainer);

      await _pumpHome(tester);

      expect(_chainCard(ChainLinkKey.trainer), findsOneWidget);
      expect(_chainCard(ChainLinkKey.sensors), findsNothing);
      expect(core.settings.getSensorsOnlyMode(), isFalse);
    });

    // A trainer the scanner merely sees may be the neighbour's; one
    // remembered from before is exactly what a rider on sensors alone has put
    // away. Neither is a trainer the rider is on, so neither ends the mode.
    testWidgets('a trainer that is only discovered keeps sensors-only mode', (tester) async {
      await core.settings.setSensorsOnlyMode(true);
      core.connection.devices.add(ProxyDevice(BleDevice(deviceId: 'kickr-nearby', name: 'Wahoo KICKR')));

      await _pumpHome(tester);

      expect(core.settings.getSensorsOnlyMode(), isTrue);
      expect(_chainCard(ChainLinkKey.sensors), findsOneWidget);
      expect(_chainCard(ChainLinkKey.trainer), findsNothing);
    });

    testWidgets('a remembered but absent trainer keeps sensors-only mode', (tester) async {
      await core.settings.setSensorsOnlyMode(true);
      core.connection.rememberedTrainer = RememberedDevice(
        deviceId: 'kickr-remembered',
        name: 'Wahoo KICKR',
        kind: RememberedDeviceKind.trainer,
        lastConnected: DateTime(2026, 9, 1),
      );

      await _pumpHome(tester);

      expect(core.settings.getSensorsOnlyMode(), isTrue);
      expect(_chainCard(ChainLinkKey.sensors), findsOneWidget);
      expect(_chainCard(ChainLinkKey.trainer), findsNothing);
    });

    testWidgets('a trainer that is only discovered still offers "Use sensors only"', (tester) async {
      core.connection.devices.add(ProxyDevice(BleDevice(deviceId: 'kickr-nearby', name: 'Wahoo KICKR')));

      await _pumpHome(tester);

      expect(_chainCard(ChainLinkKey.trainer), findsOneWidget);
      expect(find.byKey(const Key('chain-card-footer')), findsOneWidget);
    });

    testWidgets('Open on the Sensors card pushes the Sensors page', (tester) async {
      await core.settings.setSensorsOnlyMode(true);
      await _pumpHome(tester);

      await tester.tap(find.text(l.sensorsOpen));
      await tester.pumpAndSettle();

      expect(find.byType(SensorsPage), findsOneWidget);
      expect(find.text(l.sensorsPageTitle), findsOneWidget);
    });
  });
}

// ── The gear overlay step ──────────────────────────────────────────────────

/// The step that answers "why does MyWhoosh show the wrong gear?" — required
/// now, with an explicit "Not now" as the way off the card. The builder's
/// rules (when it is offered, that it blocks, that a decline hides it) live
/// in chain_builder_test.dart; this pins the two things only the page can
/// prove: that the second button persists the decline and takes the step
/// away, and that the trainer card shows the live gear beside its numbers.
void _overlayStepTests() {
  group('the gear overlay step', () {
    late AppLocalizations l;
    late ProxyDevice trainer;
    late FitnessBikeDefinition definition;

    setUp(() async {
      l = AppLocalizations.current;
      // Off for real behaviour: under the harness's screenshot mode the
      // overlay is never offered and the metrics line is a fixture.
      screenshotMode = false;
      // The overlay is only offered when the trainer app runs on this device.
      await core.settings.setLastTarget(Target.thisDevice);
      await core.settings.setOverlayEnabled(false);
      await core.settings.setOverlayDeclined(false);

      trainer = ProxyDevice(
        BleDevice(
          deviceId: 'kickr-vs-home',
          name: 'Wahoo KICKR CORE',
          services: const [FitnessBikeDefinition.FITNESS_MACHINE_SERVICE_UUID],
        ),
      )..services = [BleService(FitnessBikeDefinition.FITNESS_MACHINE_SERVICE_UUID, [])];
      definition = FitnessBikeDefinition(
        connectedDevice: trainer.scanResult,
        connectedDeviceServices: trainer.services!,
        data: ValueNotifier(''),
      );
      // What a Virtual Shifting session leaves behind: the Bluetooth link up,
      // the definition on the device (the card's body and the overlay offer
      // key on it) and on its emulator (the live readout reads it there), and
      // the trainer app holding the bridge.
      trainer.isConnected = true;
      trainer.emulator.debugSetActiveDefinition(definition);
      trainer.debugAttachFitnessBike(definition);
      trainer.debugSetTrainerAppConnected(true);
      core.connection.devices.add(trainer);
    });

    tearDown(() async {
      screenshotMode = true;
      await core.settings.setOverlayDeclined(false);
      await core.settings.setOverlayEnabled(false);
    });

    // Not a platform that can draw an overlay (a Linux test host, say): the
    // step is never offered, so there is nothing here to prove.
    final unsupported = !TrainerOverlayService.isSupportedPlatform;

    // A phone-shaped surface tall enough for the whole chain: the trainer
    // card's buttons sit below the default 600px viewport, where a tap lands
    // on nothing.
    Future<void> pumpTallHome(WidgetTester tester) async {
      tester.view.physicalSize = const Size(430, 2000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await _pumpHome(tester);
    }

    testWidgets('"Not now" persists the decline and takes the step off the card', (tester) async {
      await pumpTallHome(tester);

      final card = _chainCard(ChainLinkKey.trainer);
      expect(find.descendant(of: card, matching: find.text(l.chainStepOverlayPending('MyWhoosh'))), findsOneWidget);
      expect(find.descendant(of: card, matching: find.text(l.chainStepOverlayAction)), findsOneWidget);
      expect(find.descendant(of: card, matching: find.text(l.chainStepOverlayDecline)), findsOneWidget);

      await tester.tap(find.text(l.chainStepOverlayDecline));
      await tester.pump();
      // Let the checklist's collapse run out before looking for what is left.
      await tester.pump(const Duration(milliseconds: 400));

      expect(core.settings.getOverlayDeclined(), isTrue);
      expect(find.text(l.chainStepOverlayPending('MyWhoosh')), findsNothing);
      expect(find.text(l.chainStepOverlayDecline), findsNothing);
      // The rider said no, and the overlay itself stayed off.
      expect(core.settings.getOverlayEnabled(), isFalse);

      // Unmount before the test ends: with screenshotMode off, the page's
      // periodic metrics timer is running, and flutter_test fails a test that
      // leaves a pending timer behind — State.dispose() cancels it.
      await tester.pumpWidget(const SizedBox());
    }, skip: unsupported);

    // The review's regression: the Live Activity's "stop ride" switches the
    // overlay off on every ride end, and the trainer page's switch does the
    // same on purpose. Neither may put the amber card and "1 step left" back
    // on a rider who has already answered — the line goes back to being the
    // offer it was, with nothing to decline.
    testWidgets('an overlay switched off after being answered is an optional offer without "Not now"', (
      tester,
    ) async {
      await core.settings.setOverlayEnabled(true);
      await core.settings.setOverlayEnabled(false);
      await pumpTallHome(tester);

      final card = _chainCard(ChainLinkKey.trainer);
      expect(find.descendant(of: card, matching: find.text(l.chainStepOverlayPending('MyWhoosh'))), findsOneWidget);
      expect(find.descendant(of: card, matching: find.text(l.chainStepOverlayAction)), findsOneWidget);
      expect(find.descendant(of: card, matching: find.text(l.chainOptional.toUpperCase())), findsOneWidget);
      expect(find.text(l.chainStepOverlayDecline), findsNothing);
      final link = tester.widget<ChainCard>(card).link;
      expect(link.status, LinkStatus.ready);
      expect(link.isBlocking, isFalse);

      await tester.pumpWidget(const SizedBox());
    }, skip: unsupported);

    testWidgets('the trainer card shows the live gear in its metrics line', (tester) async {
      definition.setTargetGear(12);
      await pumpTallHome(tester);

      // Gear 12 of 24 on the trainer card's status line — the number the
      // rider's shifter is on, beside the trainer's own watts and cadence
      // (the drivetrain in the card's body draws the gear too, so this asks
      // the status line itself rather than any text on the card).
      final status = tester.widget<StatusLine>(
        find.descendant(of: _chainCard(ChainLinkKey.trainer), matching: find.byType(StatusLine)),
      );
      expect(status.meta, contains('12/24'));
      expect(find.text(status.meta!), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
    }, skip: unsupported);
  });
}

// ── The advertised-address step ────────────────────────────────────────────

/// One entry of `NetworkInterface.list()`: a named interface carrying the
/// given IPv4s. `addresses` is typed `List<InterfaceAddress>`, so the wrapped
/// address has to be that subtype rather than a plain [InternetAddress].
class _FakeNetworkInterface implements NetworkInterface {
  _FakeNetworkInterface(this.name, List<String> ips) : addresses = ips.map(_FakeInterfaceAddress.new).toList();

  @override
  final String name;

  @override
  final List<InterfaceAddress> addresses;

  @override
  int get index => 0;
}

class _FakeInterfaceAddress implements InterfaceAddress {
  _FakeInterfaceAddress(String ip) : _inner = InternetAddress(ip);

  final InternetAddress _inner;

  @override
  int get prefixLength => 24;

  @override
  InternetAddress? get broadcast => null;

  @override
  InternetAddressType get type => _inner.type;

  @override
  String get address => _inner.address;

  @override
  String get host => _inner.host;

  @override
  Uint8List get rawAddress => _inner.rawAddress;

  @override
  bool get isLoopback => _inner.isLoopback;

  @override
  bool get isLinkLocal => _inner.isLinkLocal;

  @override
  bool get isMulticast => _inner.isMulticast;

  @override
  Future<InternetAddress> reverse() => _inner.reverse();
}

void _networkAddressStepTests() {
  group('network address step', () {
    late AppLocalizations l;

    setUp(() {
      l = AppLocalizations.current;
      // The harness leaves screenshot mode on, and the step stays off the
      // store board — a VPN on the screenshot machine must not end up in a
      // listing. Off here so the page reads the interfaces for real.
      screenshotMode = false;
    });

    tearDown(() {
      screenshotMode = true;
      AdvertisedAddressPicker.listInterfaces = NetworkInterface.list;
    });

    testWidgets('a VPN-looking advertised address puts the step on the app card, naming the address', (tester) async {
      // The only routable IPv4 sits on a tunnel: the picker has no better
      // choice, and the self-test would flag exactly this pick.
      AdvertisedAddressPicker.listInterfaces = () async => [
        _FakeNetworkInterface('utun3', ['10.5.0.2']),
      ];

      await _pumpHome(tester);
      // The address is read asynchronously in initState; a frame or two lands
      // it. Not pumpAndSettle: off screenshot mode the amber dot pulses for
      // eight seconds, and settling would wait out the whole burst.
      await tester.pump();
      await tester.pump();

      expect(find.text(l.chainStepNetworkAddressPending), findsWidgets);
      expect(find.text(l.chainStepNetworkAddressHint('10.5.0.2', 'MyWhoosh')), findsOneWidget);
      expect(find.text(l.chainStepNetworkAddressAction), findsOneWidget);

      // Unmount before the test ends: with screenshot mode off, HomePage's
      // periodic metrics timer is running, and a pending timer fails the test.
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('its action opens the network troubleshooting page', (tester) async {
      AdvertisedAddressPicker.listInterfaces = () async => [
        _FakeNetworkInterface('utun3', ['10.5.0.2']),
      ];
      // The app card is the last in the chain and its button sits below the
      // default 600px test surface; the real host scrolls, _pumpHome does not.
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await _pumpHome(tester);
      await tester.pump();
      await tester.pump();

      // Not pumpAndSettle: NetworkTroubleshootingPage kicks off a self-test
      // engine with its own timers/polling, which never settles.
      await tester.tap(find.text(l.chainStepNetworkAddressAction));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(tester.takeException(), isNull);
      expect(find.byType(NetworkTroubleshootingPage), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('a plain LAN address puts no such step on the card', (tester) async {
      AdvertisedAddressPicker.listInterfaces = () async => [
        _FakeNetworkInterface('en0', ['192.168.1.50']),
      ];

      await _pumpHome(tester);
      await tester.pump();
      await tester.pump();

      expect(find.text(l.chainStepNetworkAddressPending), findsNothing);
      expect(find.text(l.chainStepNetworkAddressAction), findsNothing);

      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('a trainer the app already holds over the network silences the step', (tester) async {
      AdvertisedAddressPicker.listInterfaces = () async => [
        _FakeNetworkInterface('utun3', ['10.5.0.2']),
      ];
      // A fresh proxy rests in proxy mode — DirCon over the network, served
      // from the very address the picker just chose — and the app holds it.
      // That is proof the address is reachable, whatever it looks like.
      final trainer = ProxyDevice(BleDevice(deviceId: 'kickr-held-over-network', name: 'KICKR CORE 1234'))
        ..debugSetTrainerAppConnected(true);
      expect(trainer.retrofitMode.value, isNot(RetrofitMode.bluetooth));
      core.connection.devices.add(trainer);

      await _pumpHome(tester);
      await tester.pump();
      await tester.pump();

      expect(find.text(l.chainStepNetworkAddressPending), findsNothing);
      expect(find.text(l.chainStepNetworkAddressAction), findsNothing);

      await tester.pumpWidget(const SizedBox());
    });
  });
}

// ── A trainer app that drops after connecting (Task 12) ────────────────────
//
// Quitting MyWhoosh turned the banner red — "MyWhoosh lost connection" with
// "Fix" — and "Fix" opened the network self-test. Once the connection has
// worked in this session, a drop is almost always the app being closed, which
// no network test can fix. The latch lives on the page, so this is where the
// card, the banner and their buttons are proven together.

/// Every route pushed onto the navigator, whatever its type — so "nothing was
/// pushed" cannot pass just because a route was of a kind this observer does
/// not know how to read.
class _PushedRoutes extends NavigatorObserver {
  final List<Route<dynamic>> routes = [];

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) => routes.add(route);

  /// The pages behind the routes `context.push` creates.
  List<Widget> get pages => [
    for (final route in routes)
      if (route is MaterialPageRoute) route.builder(navigator!.context),
  ];
}

/// The rider leaves BikeControl and comes back — what they do after switching
/// a VPN on in the system settings.
Future<void> _leaveAndReturn(WidgetTester tester) async {
  for (final state in [AppLifecycleState.inactive, AppLifecycleState.resumed]) {
    await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
      SystemChannels.lifecycle.name,
      SystemChannels.lifecycle.codec.encodeMessage(state.toString()),
      (_) {},
    );
  }
}

void _droppedAppTests() {
  group('a trainer app that drops after connecting', () {
    late AppLocalizations l;

    setUp(() {
      l = AppLocalizations.current;
      // A controller that is here and needs nothing, so the app card is the
      // only card left outstanding once the app goes away.
      core.connection.devices.add(HidDevice('Keyboard')..isConnected = true);
    });

    tearDown(() {
      core.obpMdnsEmulator.isConnected.value = false;
    });

    // The app card is the last in the chain and its button sits below the
    // default 600px test surface; the real host scrolls, _pumpHome does not.
    void useTallSurface(WidgetTester tester) {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
    }

    /// Off for real behaviour: the advertised address is only read outside
    /// screenshot mode. The page's metrics timer runs then, so a test that
    /// calls this unmounts the page before it ends.
    void readAddressesFrom(List<NetworkInterface> interfaces) {
      final wasScreenshotMode = screenshotMode;
      screenshotMode = false;
      addTearDown(() => screenshotMode = wasScreenshotMode);
      _setInterfaces(interfaces);
      addTearDown(() => AdvertisedAddressPicker.listInterfaces = NetworkInterface.list);
    }

    // In the app the host rebuilds the page on every connection alert; here
    // that is done by hand.
    Future<void> rebuild(WidgetTester tester) async {
      tester.element(find.byType(HomePage)).markNeedsBuild();
      await tester.pump();
    }

    /// The trainer app connects over the Network method.
    Future<void> connectApp(WidgetTester tester) async {
      core.obpMdnsEmulator.isConnected.value = true;
      await rebuild(tester);
      expect(find.text(l.chainReadyTitle), findsOneWidget);
    }

    /// ... and goes away again: the rider quit it. A frame more, because a
    /// drop re-reads the advertised address.
    Future<void> dropApp(WidgetTester tester) async {
      core.obpMdnsEmulator.isConnected.value = false;
      await rebuild(tester);
      await tester.pump();
    }

    Future<void> pumpDroppedApp(WidgetTester tester, {List<NavigatorObserver> navigatorObservers = const []}) async {
      useTallSurface(tester);
      await _pumpHome(tester, navigatorObservers: navigatorObservers);
      await connectApp(tester);
      await dropApp(tester);
    }

    Finder inAppCard(Finder finder) => find.descendant(of: _chainCard(ChainLinkKey.app), matching: finder);

    Finder appStatusLine(String text) => find.descendant(
      of: find.descendant(of: _chainCard(ChainLinkKey.app), matching: find.byType(StatusLine)),
      matching: find.text(text),
    );

    Finder bannerButton() => find.descendant(of: find.byType(ReadyBanner), matching: find.byType(PrimaryButton));

    Future<void> tapAndSettleSheet(WidgetTester tester, Finder finder) async {
      await tester.tap(finder);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
    }

    testWidgets('the app card is amber and says the app disconnected', (tester) async {
      await pumpDroppedApp(tester);

      expect(tester.widget<ChainCard>(_chainCard(ChainLinkKey.app)).link.status, LinkStatus.attention);
      expect(appStatusLine(l.chainStatusAppDisconnected('MyWhoosh')), findsOneWidget);
      expect(inAppCard(find.text(l.notConnected)), findsNothing);
      // Nor does the card itself offer the network check any more.
      expect(inAppCard(find.text(l.networkTroubleshootTroubleshoot)), findsNothing);
    });

    testWidgets('the banner is a step left, not a lost connection', (tester) async {
      await pumpDroppedApp(tester);

      expect(find.text(l.chainPendingSubtitleAppDropped('MyWhoosh')), findsOneWidget);
      expect(find.text(l.chainBrokenTitle('MyWhoosh')), findsNothing);
      expect(find.text(l.chainBannerFix), findsNothing);
    });

    testWidgets('the banner button opens the app guide, and nothing is pushed', (tester) async {
      final pushed = _PushedRoutes();
      await pumpDroppedApp(tester, navigatorObservers: [pushed]);
      // The observer is attached: it saw the home route go in.
      expect(pushed.routes, isNotEmpty);
      pushed.routes.clear();

      // Not pumpAndSettle: were the self-test page pushed, its engine keeps
      // polling and never settles.
      await tapAndSettleSheet(tester, bannerButton());

      // The guide is a sheet, not a page: no route of any kind goes in.
      expect(find.text(l.onboardingThenInApp('MyWhoosh')), findsOneWidget);
      expect(pushed.routes, isEmpty);
      expect(find.byType(NetworkTroubleshootingPage), findsNothing);

      await tester.pumpWidget(const SizedBox());
    });

    // Two adapters on different subnets flag many a desktop for good, and the
    // app connects there all the same. An address the app has already
    // reached is no reason to send the rider to the network test once the app
    // goes away — not from the card, and not from the banner.
    testWidgets('an address flag the app connected through stays off the card after the drop', (tester) async {
      readAddressesFrom(_twoAdapters);
      final pushed = _PushedRoutes();
      useTallSurface(tester);
      await _pumpHome(tester, navigatorObservers: [pushed]);
      // The address is read asynchronously in initState; a frame or two lands
      // it. Not pumpAndSettle: off screenshot mode the amber dot pulses.
      await tester.pump();
      await tester.pump();
      // The flag is real: before the app has connected, the card raises it.
      expect(inAppCard(find.text(l.chainStepNetworkAddressAction)), findsOneWidget);

      await connectApp(tester);
      await dropApp(tester);

      expect(find.text(l.chainStepNetworkAddressPending), findsNothing);
      expect(find.text(l.chainStepNetworkAddressAction), findsNothing);
      expect(appStatusLine(l.chainStatusAppDisconnected('MyWhoosh')), findsOneWidget);
      expect(find.text(l.chainPendingSubtitleAppDropped('MyWhoosh')), findsOneWidget);

      expect(pushed.routes, isNotEmpty);
      pushed.routes.clear();

      // The card's button opens the app's pairing guide — a sheet, so no
      // route of any kind goes in...
      await tapAndSettleSheet(tester, inAppCard(find.text(l.chainShowMeHow)));
      expect(find.text(l.onboardingThenInApp('MyWhoosh')), findsOneWidget);
      expect(pushed.routes, isEmpty);

      await tapAndSettleSheet(tester, find.widgetWithText(PrimaryButton, l.close));
      expect(find.text(l.onboardingThenInApp('MyWhoosh')), findsNothing);

      // ... and so does the banner's.
      await tapAndSettleSheet(tester, bannerButton());
      expect(find.text(l.onboardingThenInApp('MyWhoosh')), findsOneWidget);
      expect(pushed.routes, isEmpty);
      expect(find.byType(NetworkTroubleshootingPage), findsNothing);

      await tester.pumpWidget(const SizedBox());
    });

    // The page is rebuilt from scratch when the rider swipes back to it, and
    // then the app may already be connected before the address has been read.
    // The first reading stands in for the moment it connected.
    testWidgets('an app already connected when the page comes up keeps its address flag quiet too', (tester) async {
      readAddressesFrom(_twoAdapters);
      core.obpMdnsEmulator.isConnected.value = true;
      useTallSurface(tester);
      await _pumpHome(tester);
      await tester.pump();
      await tester.pump();
      expect(find.text(l.chainReadyTitle), findsOneWidget);

      await dropApp(tester);

      expect(find.text(l.chainStepNetworkAddressPending), findsNothing);
      expect(appStatusLine(l.chainStatusAppDisconnected('MyWhoosh')), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
    });

    // What is new since the app connected is news, though: a VPN that comes
    // up is a classic reason for an app to drop, and the card says so.
    testWidgets('an address flag that was not there when the app connected brings the step back', (tester) async {
      readAddressesFrom(_plainLan);
      useTallSurface(tester);
      await _pumpHome(tester);
      await tester.pump();
      await tester.pump();

      await connectApp(tester);
      await dropApp(tester);
      expect(appStatusLine(l.chainStatusAppDisconnected('MyWhoosh')), findsOneWidget);
      expect(find.text(l.chainStepNetworkAddressPending), findsNothing);

      // A VPN comes up in the system settings, and the rider comes back.
      _setInterfaces(_vpnOnly);
      await _leaveAndReturn(tester);
      await tester.pump();
      await tester.pump();

      expect(appStatusLine(l.chainStepNetworkAddressPending), findsOneWidget);
      expect(find.text(l.chainStepNetworkAddressHint('10.5.0.2', 'MyWhoosh')), findsOneWidget);
      expect(inAppCard(find.text(l.chainStepNetworkAddressAction)), findsOneWidget);
      expect(find.text(l.chainStatusAppDisconnected('MyWhoosh')), findsNothing);
      expect(find.text(l.chainPendingSubtitleAppDropped('MyWhoosh')), findsNothing);

      await tester.pumpWidget(const SizedBox());
    });

    // The usual order, in fact: the VPN comes up while the app is still
    // connected over the old path, and the app drops a little later. What the
    // app connected through is latched when it connected, not whatever the
    // address turned into while it stayed connected.
    testWidgets('an address flag that appears while the app is still connected brings the step back', (tester) async {
      readAddressesFrom(_plainLan);
      useTallSurface(tester);
      await _pumpHome(tester);
      await tester.pump();
      await tester.pump();
      await connectApp(tester);

      _setInterfaces(_vpnOnly);
      await _leaveAndReturn(tester);
      await tester.pump();
      await tester.pump();
      // Still connected, so still nothing to say.
      expect(find.text(l.chainReadyTitle), findsOneWidget);

      await dropApp(tester);

      expect(appStatusLine(l.chainStepNetworkAddressPending), findsOneWidget);
      expect(find.text(l.chainStepNetworkAddressHint('10.5.0.2', 'MyWhoosh')), findsOneWidget);
      expect(find.text(l.chainStatusAppDisconnected('MyWhoosh')), findsNothing);

      await tester.pumpWidget(const SizedBox());
    });

    // The latch is per app: an app picked after the drop has connected to
    // nothing yet, and gets the same start as any app that never connected.
    testWidgets('an app picked after the drop is waited for, not "disconnected"', (tester) async {
      await pumpDroppedApp(tester);
      expect(appStatusLine(l.chainStatusAppDisconnected('MyWhoosh')), findsOneWidget);

      final other = TrainingPeaks();
      core.settings.setTrainerApp(other);
      await rebuild(tester);

      expect(appStatusLine(l.chainStatusWaitingForApp(other.name)), findsOneWidget);
      expect(inAppCard(find.text(l.networkTroubleshootTroubleshoot)), findsOneWidget);
      expect(find.text(l.chainStatusAppDisconnected(other.name)), findsNothing);
      expect(find.text(l.chainPendingSubtitleAppDropped(other.name)), findsNothing);
    });

    // Local reports connected the moment it is switched on, and says nothing
    // about whether the app is there — so a session on Local alone is no
    // connection, and a network method switched on later is simply waited on.
    testWidgets('a session on Local alone latches nothing', (tester) async {
      final previousTarget = core.settings.getLastTarget();
      addTearDown(() async {
        if (previousTarget == null) {
          await core.settings.prefs.remove('last_target');
        } else {
          await core.settings.setLastTarget(previousTarget);
        }
      });
      await core.settings.setLastTarget(Target.thisDevice);
      core.settings.setObpMdnsEnabled(false);
      core.obpMdnsEmulator.isStarted.value = false;
      core.settings.setLocalEnabled(true);
      addTearDown(() => core.settings.setLocalEnabled(false));
      core.local.isConnected.value = true;
      addTearDown(() => core.local.isConnected.value = false);
      useTallSurface(tester);

      await _pumpHome(tester);
      // On Local alone the app counts as connected.
      final connectedStep = tester
          .widget<ChainCard>(_chainCard(ChainLinkKey.app))
          .link
          .steps
          .firstWhere((s) => s.id == SetupStepId.appConnected);
      expect(connectedStep.done, isTrue);

      // The rider switches the Network method on as well.
      core.settings.setObpMdnsEnabled(true);
      core.obpMdnsEmulator.isStarted.value = true;
      await rebuild(tester);

      expect(appStatusLine(l.chainStatusWaitingForApp('MyWhoosh')), findsOneWidget);
      expect(inAppCard(find.text(l.networkTroubleshootTroubleshoot)), findsOneWidget);
      expect(find.text(l.chainStatusAppDisconnected('MyWhoosh')), findsNothing);
      expect(find.text(l.chainPendingSubtitleAppDropped('MyWhoosh')), findsNothing);
    });

    // With the trainer still held the app is plainly open: only its
    // controller tile is missing, and the card and the banner both say that.
    testWidgets('an app that still holds the trainer is missing its controller tile, not "disconnected"', (
      tester,
    ) async {
      core.connection.devices.add(
        ProxyDevice(BleDevice(deviceId: 'kickr-held-after-drop', name: 'KICKR CORE 1234'))
          ..debugSetTrainerAppConnected(true),
      );
      await pumpDroppedApp(tester);

      expect(inAppCard(find.text(l.chainStepAppControllerPending('MyWhoosh'))), findsOneWidget);
      expect(find.text(l.chainPendingSubtitleController('MyWhoosh')), findsOneWidget);
      expect(find.text(l.chainStatusAppDisconnected('MyWhoosh')), findsNothing);
      expect(find.text(l.chainPendingSubtitleAppDropped('MyWhoosh')), findsNothing);
      // It did connect in this session, so the network check stays away too.
      expect(inAppCard(find.text(l.networkTroubleshootTroubleshoot)), findsNothing);
    });

    // The other half of the rule: an app that has not connected in this
    // session keeps the network check, exactly as before. Opening it also
    // proves the observer above catches that push when it happens.
    testWidgets('an app that never connected still offers the network check', (tester) async {
      final pushed = _PushedRoutes();
      useTallSurface(tester);
      await _pumpHome(tester, navigatorObservers: [pushed]);

      expect(inAppCard(find.text(l.networkTroubleshootTroubleshoot)), findsOneWidget);
      expect(appStatusLine(l.chainStatusWaitingForApp('MyWhoosh')), findsOneWidget);
      expect(find.text(l.chainStatusAppDisconnected('MyWhoosh')), findsNothing);

      pushed.routes.clear();
      // Not pumpAndSettle: the self-test engine keeps polling.
      await tapAndSettleSheet(tester, inAppCard(find.text(l.networkTroubleshootTroubleshoot)));

      expect(tester.takeException(), isNull);
      expect(pushed.pages.whereType<NetworkTroubleshootingPage>(), hasLength(1));

      await tester.pumpWidget(const SizedBox());
    });
  });
}

void _setInterfaces(List<NetworkInterface> interfaces) {
  AdvertisedAddressPicker.listInterfaces = () async => interfaces;
}

/// A desktop on two physical networks: flagged for good, and the app connects
/// all the same.
final _twoAdapters = <NetworkInterface>[
  _FakeNetworkInterface('en0', ['192.168.1.50']),
  _FakeNetworkInterface('en1', ['10.0.0.20']),
];

final _plainLan = <NetworkInterface>[
  _FakeNetworkInterface('en0', ['192.168.1.50']),
];

/// The only routable IPv4 sits on a tunnel.
final _vpnOnly = <NetworkInterface>[
  _FakeNetworkInterface('utun3', ['10.5.0.2']),
];
