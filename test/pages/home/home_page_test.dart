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
import 'package:bike_control/bluetooth/devices/proxy/proxy_device.dart';
import 'package:bike_control/gen/l10n.dart';
import 'package:bike_control/main.dart' show screenshotMode;
import 'package:bike_control/models/remembered_device.dart';
import 'package:bike_control/pages/home/chain_state.dart';
import 'package:bike_control/pages/home/home_page.dart';
import 'package:bike_control/pages/proxy_device_details/metric_card.dart';
import 'package:bike_control/pages/sensors/sensors_page.dart';
import 'package:bike_control/services/sensors/broadcast_controller.dart';
import 'package:bike_control/services/sensors/fake_sensor_source.dart';
import 'package:bike_control/services/sensors/sensor_quantity.dart';
import 'package:bike_control/utils/core.dart';
import 'package:bike_control/utils/keymap/apps/my_whoosh.dart';
import 'package:bike_control/widgets/home/chain_card.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prop/emulators/dircon_emulator.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:universal_ble/universal_ble.dart';

import '../../widget_snapshot.dart';

ChainLink _appLink({required bool appConnected}) => ChainLink(
  key: ChainLinkKey.app,
  id: 'app',
  status: LinkStatus.attention,
  title: 'MyWhoosh',
  steps: [
    SetupStep(id: SetupStepId.appSelected, done: true),
    SetupStep(id: SetupStepId.appConnectionMethod, done: true),
    SetupStep(id: SetupStepId.appConnected, done: appConnected),
  ],
);

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
}

// ── Sensors-only mode (Task 7) ─────────────────────────────────────────────

Finder _chainCard(ChainLinkKey key) =>
    find.byWidgetPredicate((w) => w is ChainCard && w.link.key == key, description: 'ChainCard(${key.name})');

Future<void> _pumpHome(WidgetTester tester) async {
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

    testWidgets('no trainer: the trainer card offers "Use sensors only", and tapping it swaps in the Sensors card', (
      tester,
    ) async {
      await _pumpHome(tester);

      expect(_chainCard(ChainLinkKey.trainer), findsOneWidget);
      expect(_chainCard(ChainLinkKey.sensors), findsNothing);
      final footer = find.byKey(const Key('chain-card-footer'));
      expect(footer, findsOneWidget);
      expect(find.text(l.sensorsUseSensorsOnlyQuestion), findsOneWidget);
      expect(find.text(l.sensorsUseSensorsOnly), findsOneWidget);

      await tester.tap(find.text(l.sensorsUseSensorsOnly));
      await tester.pump();

      expect(core.settings.getSensorsOnlyMode(), isTrue);
      expect(_chainCard(ChainLinkKey.sensors), findsOneWidget);
      expect(_chainCard(ChainLinkKey.trainer), findsNothing);
      expect(find.byKey(const Key('chain-card-footer')), findsNothing);
      // The strip's tap is its own — it must not fall through to the card
      // and open the trainer connect sheet underneath.
      await tester.pumpAndSettle();
      expect(find.text(l.close), findsNothing);
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
