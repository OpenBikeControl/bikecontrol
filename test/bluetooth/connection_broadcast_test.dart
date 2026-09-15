import 'package:bike_control/bluetooth/devices/sensors/ble_heart_rate_device.dart';
import 'package:bike_control/bluetooth/emulation/emulated_ble_platform.dart';
import 'package:bike_control/gen/l10n.dart';
import 'package:bike_control/main.dart' show installLoggerErrorListener;
import 'package:bike_control/services/sensors/ble_sensor_source.dart';
import 'package:bike_control/services/sensors/fake_health_kit_channel.dart';
import 'package:bike_control/services/sensors/health_kit_channel.dart';
import 'package:bike_control/services/sensors/health_kit_sensor_source.dart';
import 'package:bike_control/services/sensors/sensor_quantity.dart';
import 'package:bike_control/utils/actions/base_actions.dart';
import 'package:bike_control/utils/core.dart';
import 'package:bike_control/utils/iap/iap_manager.dart';
import 'package:flutter/widgets.dart' show Locale;
import 'package:flutter_test/flutter_test.dart';
// ignore: depend_on_referenced_packages
import 'package:flutter_local_notifications_platform_interface/flutter_local_notifications_platform_interface.dart';
import 'package:prop/utils/shared.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:universal_ble/universal_ble.dart';

/// No-op local-notifications backend — `Connection._connect` posts a
/// "connected" notification on success, and the plugin's static platform
/// instance is only set by real plugin registration. Mirrors
/// `connection_health_kit_test.dart`'s own scaffolding source.
class _FakeLocalNotificationsPlatform extends FlutterLocalNotificationsPlatform {
  @override
  Future<void> show({required int id, String? title, String? body, String? payload}) async {}

  @override
  Future<void> cancel({required int id}) async {}

  @override
  Future<void> cancelAll() async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    // `Connection._connect`'s BLE connection-state listener reads
    // `AppLocalizations.current` for its connected/disconnected notification
    // text — normally loaded as a side effect of building a localized widget
    // tree (see live_metrics_section_test.dart's `pump`), but this file
    // drives a real connect through `Connection` with no widget tree at all.
    // Load it directly instead of asserting on its (untested) strings — see
    // this project's "no l10n string tests" rule.
    await AppLocalizations.load(const Locale('en'));
    SharedPreferences.setMockInitialValues({});
    await Supabase.initialize(
      url: 'http://127.0.0.1:9',
      anonKey: 'connection-broadcast-test-anon-key',
      debug: false,
      authOptions: const FlutterAuthClientOptions(
        localStorage: EmptyLocalStorage(),
        detectSessionInUri: false,
        autoRefreshToken: false,
      ),
    );
  });

  late FakeHealthKitChannel channel;
  late List<String> recordedContexts;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    core.settings.prefs = await SharedPreferences.getInstance();
    core.actionHandler = StubActions();
    core.connection.devices.clear();
    FlutterLocalNotificationsPlatform.instance = _FakeLocalNotificationsPlatform();
    IAPManager.instance.setProForTesting(enabled: false);

    // recordError() -> installLoggerErrorListener() only assigns
    // Logger.onRecordError the first time it runs in this isolate; trip that
    // guard here (before overriding the listener below) so this file's own
    // recording listener isn't clobbered on the first recordError() call,
    // mirroring connection_health_kit_test.dart's own setup.
    installLoggerErrorListener();
    recordedContexts = [];
    Logger.onRecordError = (message, error, stack) => recordedContexts.add(message);

    channel = FakeHealthKitChannel();
    core.connection.healthKitSource = HealthKitSensorSource(channel: channel);
  });

  tearDown(() async {
    await core.connection.disconnectHealthKit(forget: true);
    core.connection.healthKitSource = null;
    core.sensors.select(SensorQuantity.heartRate, null);
    core.connection.devices.clear();
    IAPManager.instance.setProForTesting(enabled: false);
    Logger.onRecordError = null;
  });

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

  group('connectSourceById', () {
    test('routes healthkit to authorize + connect', () async {
      await core.connection.connectSourceById(HealthKitSensorSource.sourceId);

      expect(channel.authorizeCalls, 1);
      expect(channel.startCalls, 1);
      expect(core.connection.isHealthKitConnected, isTrue);
    });

    test('a denied healthkit authorization throws and never touches the hub', () async {
      channel.authorization = HealthKitAuthorization.denied;

      await expectLater(
        core.connection.connectSourceById(HealthKitSensorSource.sourceId),
        throwsA(isA<HealthKitDeniedException>()),
      );
      expect(core.connection.isHealthKitConnected, isFalse);
    });

    test('routes a strap id to consent-then-connectDevice, mirroring the signals grid', () async {
      final ble = FakeUniversalBlePlatform();
      UniversalBle.setInstance(ble);
      final peripheral = strapPeripheral(deviceId: 'broadcast-strap-1');
      ble.addPeripheral(peripheral);
      final device = BleHeartRateDevice(peripheral.scanResult);
      core.connection.devices.add(device);
      expect(device.shouldAutoConnect, isFalse);

      await core.connection.connectSourceById(device.source.id);

      expect(device.isConnected, isTrue);
      // Persisted BEFORE connect — the load-bearing ordering `_connectDevice`
      // relies on (`shouldAutoConnect` reads it; `connect()` early-returns
      // otherwise).
      expect(core.settings.getSensorAutoConnect(device.device.deviceId), isTrue);

      // `Connection`'s BLE connection-state listener leaves a periodic
      // gamepad-search timer pending past this test's end otherwise (see
      // live_metrics_section_test.dart's identical `stop()` call and its own
      // comment on why it has to happen here, not in tearDown).
      await core.connection.stop();
    });

    // A strap the rider just selected may not be in `devices` yet at all
    // (not yet discovered by the scanner) — this must still leave consent
    // set so the auto-connect queue picks it up on discovery, and must NOT
    // record an error: an undiscovered strap is expected, not exceptional.
    test('a not-yet-discovered strap sets consent and logs, without erroring', () async {
      await core.connection.connectSourceById('not-discovered-yet');

      expect(core.settings.getSensorAutoConnect('not-discovered-yet'), isTrue);
      expect(recordedContexts, isEmpty);
      expect(core.connection.lastLogEntries.map((e) => e.entry), contains(contains('not-discovered-yet')));
    });

    // Finding 1 (mirror image): the controller's rollback only ever learns
    // about ids `connectSource` returned successfully for — a failed id has
    // to clear its own consent, or a strap that just failed to connect would
    // still auto-connect on the next scan with the switch off.
    test('a BLE connect failure clears the consent it just set, then rethrows', () async {
      final ble = FakeUniversalBlePlatform();
      UniversalBle.setInstance(ble);
      final peripheral = strapPeripheral(deviceId: 'broadcast-strap-fails');
      peripheral.connectError = Exception('GATT 133');
      ble.addPeripheral(peripheral);
      final device = BleHeartRateDevice(peripheral.scanResult);
      core.connection.devices.add(device);

      await expectLater(core.connection.connectSourceById(device.source.id), throwsA(isA<Exception>()));

      expect(core.settings.getSensorAutoConnect(device.device.deviceId), isFalse);
      expect(recordedContexts, contains('Connection.connectSourceById ${device.source.id}'));

      await core.connection.stop();
    });
  });

  group('disconnectSourceById', () {
    test('healthkit: clears the connection but leaves the selection alone (forget: false)', () async {
      await core.connection.connectHealthKit();
      core.sensors.select(SensorQuantity.heartRate, HealthKitSensorSource.sourceId);

      await core.connection.disconnectSourceById(HealthKitSensorSource.sourceId);

      expect(channel.stopCalls, 1);
      expect(core.connection.isHealthKitConnected, isFalse);
      expect(core.sensors.selectionFor(SensorQuantity.heartRate), HealthKitSensorSource.sourceId);
    });

    test('a strap: clears auto-connect consent and keeps the device in the list', () async {
      final ble = FakeUniversalBlePlatform();
      UniversalBle.setInstance(ble);
      final peripheral = strapPeripheral(deviceId: 'broadcast-strap-2');
      ble.addPeripheral(peripheral);
      final device = BleHeartRateDevice(peripheral.scanResult);
      core.connection.devices.add(device);
      await core.connection.connectSourceById(device.source.id);
      expect(device.isConnected, isTrue);

      await core.connection.disconnectSourceById(device.source.id);

      expect(device.isConnected, isFalse);
      expect(core.settings.getSensorAutoConnect(device.device.deviceId), isFalse);
      // keepInList: true — still in `devices`, immediately reselectable.
      expect(core.connection.devices.contains(device), isTrue);

      await core.connection.stop();
    });

    // Finding 1: a strap that dropped mid-broadcast is already removed from
    // `devices` by the drop listener (`disconnect(..., dropped: true)` uses
    // `keepInList: false`) before the rider ever turns Broadcast off. Consent
    // must still clear — leaving it `true` would auto-connect the strap back
    // in on rediscovery with the switch off (Decision 4) — and a device
    // that's already gone is expected, not an error.
    test('a strap already gone from `devices` (dropped mid-broadcast) still clears consent, no error', () async {
      await core.settings.setSensorAutoConnect('dropped-strap', true);

      await core.connection.disconnectSourceById('dropped-strap');

      expect(core.settings.getSensorAutoConnect('dropped-strap'), isFalse);
      expect(recordedContexts, isEmpty);
    });
  });
}
