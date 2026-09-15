import 'dart:async';

import 'package:bike_control/bluetooth/devices/sensors/ble_heart_rate_device.dart';
import 'package:bike_control/bluetooth/emulation/emulated_ble_platform.dart';
import 'package:bike_control/gen/l10n.dart';
import 'package:bike_control/main.dart' show installLoggerErrorListener, navigatorKey;
import 'package:bike_control/pages/sensors/sensors_page.dart';
import 'package:bike_control/services/sensors/ble_sensor_source.dart';
import 'package:bike_control/services/sensors/broadcast_controller.dart';
import 'package:bike_control/services/sensors/fake_sensor_source.dart';
import 'package:bike_control/services/sensors/sensor_quantity.dart';
import 'package:bike_control/utils/actions/base_actions.dart';
import 'package:bike_control/utils/core.dart';
import 'package:bike_control/utils/iap/iap_manager.dart';
import 'package:bike_control/utils/keymap/apps/my_whoosh.dart';
import 'package:flutter_test/flutter_test.dart';
// ignore: depend_on_referenced_packages
import 'package:flutter_local_notifications_platform_interface/flutter_local_notifications_platform_interface.dart';
import 'package:prop/emulators/dircon_emulator.dart';
import 'package:prop/utils/shared.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:universal_ble/universal_ble.dart';

/// No-op local-notifications backend — mirrors
/// `live_metrics_section_test.dart`'s fake: `Connection._connect` posts a
/// notification on success and the plugin's static platform instance is only
/// set by real plugin registration.
class _FakeLocalNotificationsPlatform extends FlutterLocalNotificationsPlatform {
  @override
  Future<void> show({required int id, String? title, String? body, String? payload}) async {}

  @override
  Future<void> cancel({required int id}) async {}

  @override
  Future<void> cancelAll() async {}
}

/// The no-trainer path's page: the Broadcast switch above the signals grid.
/// Mounts the REAL `core.sensors` and a `BroadcastController` with recording
/// closures, so what the switch does is asserted through the controller's
/// own contract (`connectSource` / `disconnectSource`), not a widget double.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final connected = <String>[];
  final disconnected = <String>[];
  Object? connectError;

  /// When set, every `connectSource` parks on it — a stand-in for the seconds
  /// a real BLE / HealthKit connect takes, so a test can tap again mid-flight.
  Completer<void>? connectGate;

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await Supabase.initialize(
      url: 'http://127.0.0.1:9',
      anonKey: 'sensors-page-test-anon-key',
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
    core.connection.devices.clear();
    FlutterLocalNotificationsPlatform.instance = _FakeLocalNotificationsPlatform();
    IAPManager.instance.setProForTesting(enabled: true);
    connected.clear();
    disconnected.clear();
    connectError = null;
    connectGate = null;
    // recordError() -> installLoggerErrorListener() only assigns
    // Logger.onRecordError the first time it runs in this isolate; trip
    // that guard here so the no-op below isn't clobbered by the production
    // listener on the first recordError() call.
    installLoggerErrorListener();
    Logger.onRecordError = (_, _, _) {};
    core.connection.broadcast = BroadcastController(
      hub: core.sensors,
      settings: core.settings,
      isBridgeRunning: ValueNotifier(false),
      connectSource: (id) async {
        connected.add(id);
        if (connectGate case final gate?) await gate.future;
        if (connectError case final error?) throw error;
      },
      disconnectSource: (id) async => disconnected.add(id),
    )..start();
  });

  tearDown(() {
    core.connection.broadcast?.dispose();
    core.connection.broadcast = null;
    core.connection.standaloneClientConnected = ValueNotifier(false);
    core.connection.devices.clear();
    for (final q in SensorQuantity.values) {
      core.sensors.select(q, null);
    }
    for (final source in core.sensors.sources.toList()) {
      core.sensors.unregister(source.id);
    }
    IAPManager.instance.setProForTesting(enabled: false);
    Logger.onRecordError = null;
  });

  Future<void> pump(WidgetTester tester) async {
    await tester.pumpWidget(
      ShadcnApp(
        // `buildToast` reads navigatorKey.currentContext — the connect-failed
        // toast below needs it to render.
        navigatorKey: navigatorKey,
        localizationsDelegates: [
          ...ShadcnLocalizations.localizationsDelegates,
          AppLocalizations.delegate,
        ],
        supportedLocales: const [Locale('en')],
        home: const SensorsPage(),
      ),
    );
    await tester.pump();
  }

  /// A registered strap, selected for heart rate — the "something to
  /// broadcast" precondition the switch is gated on.
  FakeSensorSource selectStrap() {
    final strap = FakeSensorSource(id: 'strap', displayName: 'Strap', provides: {SensorQuantity.heartRate});
    core.sensors.register(strap);
    core.sensors.select(SensorQuantity.heartRate, 'strap');
    return strap;
  }

  FakePeripheral strapPeripheral({required String deviceId, String name = 'TICKR 1234'}) => FakePeripheral(
    deviceId: deviceId,
    name: name,
    advertisedServices: [BleSensorSource.heartRateServiceUuid],
    services: [
      BleService(BleSensorSource.heartRateServiceUuid, [
        BleCharacteristic(BleSensorSource.heartRateMeasurementUuid, [CharacteristicProperty.notify], const []),
      ]),
    ],
  );

  final switchFinder = find.byKey(const Key('sensors-broadcast-switch'));
  Switch switchWidget(WidgetTester tester) => tester.widget<Switch>(switchFinder);

  group('Broadcast switch', () {
    testWidgets('nothing selected: switch disabled, status asks for a source, no off hint', (tester) async {
      await pump(tester);

      expect(switchWidget(tester).enabled, isFalse);
      expect(switchWidget(tester).value, isFalse);
      expect(find.text(AppLocalizations.current.sensorsBroadcastPickSource), findsOneWidget);
      expect(find.text(AppLocalizations.current.sensorsStatusOff), findsNothing);
      expect(find.byKey(const Key('sensors-off-hint')), findsNothing);
    });

    testWidgets('a selection made while the page is open enables the switch', (tester) async {
      await pump(tester);
      expect(switchWidget(tester).enabled, isFalse);

      selectStrap();
      await tester.pump();

      expect(switchWidget(tester).enabled, isTrue);
      expect(find.text(AppLocalizations.current.sensorsStatusOff), findsOneWidget);
      expect(find.byKey(const Key('sensors-off-hint')), findsOneWidget);
    });

    testWidgets('switching on connects the selected source through the controller and reads Live', (
      tester,
    ) async {
      selectStrap();
      await pump(tester);
      expect(find.text(AppLocalizations.current.sensorsStatusOff), findsOneWidget);

      await tester.tap(switchFinder);
      await tester.pumpAndSettle();

      expect(connected, ['strap']);
      expect(core.connection.broadcast!.isOn.value, isTrue);
      expect(switchWidget(tester).value, isTrue);
      expect(find.text(AppLocalizations.current.sensorsBroadcastLive), findsOneWidget);
      expect(find.byKey(const Key('sensors-off-hint')), findsNothing);
    });

    testWidgets('switching off disconnects through the controller and reads Off again', (tester) async {
      selectStrap();
      await core.connection.broadcast!.turnOn();
      await pump(tester);
      expect(switchWidget(tester).value, isTrue);

      await tester.tap(switchFinder);
      await tester.pumpAndSettle();

      expect(disconnected, ['strap']);
      expect(core.connection.broadcast!.isOn.value, isFalse);
      expect(switchWidget(tester).value, isFalse);
      expect(find.text(AppLocalizations.current.sensorsStatusOff), findsOneWidget);
      expect(find.byKey(const Key('sensors-off-hint')), findsOneWidget);
    });

    testWidgets('a second tap while the first turn-on is still connecting is ignored', (tester) async {
      selectStrap();
      final gate = connectGate = Completer<void>();
      await pump(tester);

      await tester.tap(switchFinder);
      await tester.pump();
      // In flight: the switch is held, the status says so, nothing is on yet.
      expect(switchWidget(tester).enabled, isFalse);
      expect(find.text(AppLocalizations.current.sensorConnecting), findsOneWidget);
      expect(core.connection.broadcast!.isOn.value, isFalse);

      await tester.tap(switchFinder, warnIfMissed: false);
      await tester.pump();
      expect(connected, ['strap']);

      gate.complete();
      await tester.pumpAndSettle();

      expect(connected, ['strap']);
      expect(core.connection.broadcast!.isOn.value, isTrue);
      expect(switchWidget(tester).enabled, isTrue);
      expect(switchWidget(tester).value, isTrue);
      expect(find.text(AppLocalizations.current.sensorConnecting), findsNothing);
      expect(find.text(AppLocalizations.current.sensorsBroadcastLive), findsOneWidget);
    });

    testWidgets('a connect failure keeps the switch off and shows the connect-failed toast', (tester) async {
      selectStrap();
      connectError = StateError('strap refused');
      await pump(tester);

      await tester.tap(switchFinder);
      await tester.pump();
      await tester.pump();

      expect(core.connection.broadcast!.isOn.value, isFalse);
      expect(switchWidget(tester).value, isFalse);
      expect(find.text(AppLocalizations.current.sensorConnectFailed), findsOneWidget);
      // Drain the toast's own auto-dismiss timer (5 s for a warning) so it is
      // not left pending when the tree is torn down.
      await tester.pump(const Duration(seconds: 6));
    });

    testWidgets('the client name rides on the status line while a trainer app is subscribed', (tester) async {
      selectStrap();
      core.settings.setTrainerApp(MyWhoosh());
      final client = ValueNotifier(false);
      core.connection.standaloneClientConnected = client;
      await core.connection.broadcast!.turnOn();
      await pump(tester);
      expect(find.text(AppLocalizations.current.sensorsClientConnected('MyWhoosh')), findsNothing);

      client.value = true;
      await tester.pump();

      expect(find.text(AppLocalizations.current.sensorsClientConnected('MyWhoosh')), findsOneWidget);
    });

    testWidgets('without Pro the switch opens the Pro dialog and never reaches turnOn', (tester) async {
      IAPManager.instance.setProForTesting(enabled: false);
      selectStrap();
      await pump(tester);

      await tester.tap(switchFinder);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text(AppLocalizations.current.thisFeatureIsOnlyAvailableWithPro), findsOneWidget);
      await tester.tap(find.text(AppLocalizations.current.cancel));
      await tester.pumpAndSettle();

      expect(connected, isEmpty);
      expect(core.connection.broadcast!.isOn.value, isFalse);
      expect(switchWidget(tester).value, isFalse);
    });
  });

  group('transport', () {
    testWidgets('defaults to Bluetooth with its hint; Network persists and swaps the hint', (tester) async {
      await pump(tester);

      expect(tester.widget<SelectedButton>(find.byKey(const Key('sensors-transport-bluetooth'))).value, isTrue);
      expect(tester.widget<SelectedButton>(find.byKey(const Key('sensors-transport-network'))).value, isFalse);
      expect(find.text(AppLocalizations.current.sensorsTransportBluetoothHint), findsOneWidget);
      expect(find.text(AppLocalizations.current.sensorsTransportNetworkHint), findsNothing);

      await tester.tap(find.byKey(const Key('sensors-transport-network')));
      await tester.pumpAndSettle();

      expect(core.settings.getSensorsTransport(), RetrofitMode.wifi);
      expect(core.connection.broadcast!.transport.value, RetrofitMode.wifi);
      expect(tester.widget<SelectedButton>(find.byKey(const Key('sensors-transport-network'))).value, isTrue);
      expect(find.text(AppLocalizations.current.sensorsTransportNetworkHint), findsOneWidget);
      expect(find.text(AppLocalizations.current.sensorsTransportBluetoothHint), findsNothing);
    });
  });

  group('empty panel', () {
    testWidgets('shown when nothing is registered, nearby, or HealthKit-capable', (tester) async {
      expect(core.connection.healthKitSource, isNull);
      await pump(tester);

      expect(find.byKey(const Key('sensors-empty')), findsOneWidget);
      expect(find.text(AppLocalizations.current.sensorsEmptyTitle), findsOneWidget);
      // The grid is still there underneath, "--" and all.
      expect(find.byKey(const Key('metric-card-heartRate')), findsOneWidget);
    });

    testWidgets('hidden once a source is registered', (tester) async {
      core.sensors.register(FakeSensorSource(id: 'strap', displayName: 'Strap', provides: {SensorQuantity.heartRate}));
      await pump(tester);

      expect(find.byKey(const Key('sensors-empty')), findsNothing);
    });

    testWidgets('hidden once a strap is merely nearby', (tester) async {
      final ble = FakeUniversalBlePlatform();
      UniversalBle.setInstance(ble);
      // The fork exposes no getter for the previous platform, so "restore"
      // means a fresh, empty fake — the peripheral below must not leak.
      addTearDown(() => UniversalBle.setInstance(FakeUniversalBlePlatform()));
      final peripheral = strapPeripheral(deviceId: 'hr-nearby-1');
      ble.addPeripheral(peripheral);
      core.connection.devices.add(BleHeartRateDevice(peripheral.scanResult));
      await pump(tester);

      expect(find.byKey(const Key('sensors-empty')), findsNothing);
    });
  });
}
