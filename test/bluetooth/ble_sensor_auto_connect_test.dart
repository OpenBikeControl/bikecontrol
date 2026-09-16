import 'package:bike_control/bluetooth/devices/sensors/ble_cadence_device.dart';
import 'package:bike_control/bluetooth/devices/sensors/ble_heart_rate_device.dart';
import 'package:bike_control/bluetooth/devices/sensors/ble_power_device.dart';
import 'package:bike_control/bluetooth/devices/sensors/ble_sensor_device.dart';
import 'package:bike_control/bluetooth/emulation/emulated_ble_platform.dart';
import 'package:bike_control/services/sensors/ble_sensor_source.dart';
import 'package:bike_control/services/sensors/broadcast_controller.dart';
import 'package:bike_control/services/sensors/fake_sensor_source.dart';
import 'package:bike_control/services/sensors/sensor_quantity.dart';
import 'package:bike_control/utils/actions/base_actions.dart';
import 'package:bike_control/utils/core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:universal_ble/universal_ble.dart';

/// Spec, Global Constraint: "Nothing connects a source unless it would be
/// served." A strap's persisted consent survives a kill → relaunch, and in
/// sensors-only mode there is no bridge to serve it — so with Broadcast off
/// the auto-connect queue must leave it alone, or every relaunch grabs the
/// strap (single-connection hardware) away from the rider's watch for
/// nothing. Trainer mode is unchanged: the bridge relies on the launch-time
/// reconnect.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late List<BleSensorDevice> devices;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    core.settings.prefs = await SharedPreferences.getInstance();
    core.actionHandler = StubActions();
    core.connection.broadcast = BroadcastController(
      hub: core.sensors,
      settings: core.settings,
      isBridgeRunning: ValueNotifier(false),
      isStandaloneRunning: () => true,
      connectSource: (_) async {},
      disconnectSource: (_) async {},
    );
    FakePeripheral peripheral(String id, String service, String characteristic) => FakePeripheral(
      deviceId: id,
      name: id,
      advertisedServices: [service],
      services: [
        BleService(service, [BleCharacteristic(characteristic, [CharacteristicProperty.notify], const [])]),
      ],
    );
    devices = [
      BleHeartRateDevice(
        peripheral('strap', BleSensorSource.heartRateServiceUuid, BleSensorSource.heartRateMeasurementUuid).scanResult,
      ),
      BleCadenceDevice(
        peripheral('cadence', BleSensorSource.cscServiceUuid, BleSensorSource.cscMeasurementUuid).scanResult,
      ),
      BlePowerDevice(
        peripheral(
          'power',
          BleSensorSource.cyclingPowerServiceUuid,
          BleSensorSource.cyclingPowerMeasurementUuid,
        ).scanResult,
      ),
    ];
    for (final d in devices) {
      await core.settings.setSensorAutoConnect(d.device.deviceId, true);
    }
  });

  tearDown(() {
    core.connection.broadcast?.dispose();
    core.connection.broadcast = null;
  });

  test('without consent nothing auto-connects, whatever the mode', () async {
    for (final d in devices) {
      await core.settings.setSensorAutoConnect(d.device.deviceId, false);
      expect(d.shouldAutoConnect, isFalse, reason: d.device.deviceId);
    }
  });

  test('trainer mode: consent alone auto-connects (the bridge serves it)', () {
    expect(core.settings.getSensorsOnlyMode(), isFalse);
    for (final d in devices) {
      expect(d.shouldAutoConnect, isTrue, reason: d.device.deviceId);
    }
  });

  test('sensors-only mode with Broadcast off: consent is not enough', () async {
    await core.settings.setSensorsOnlyMode(true);
    for (final d in devices) {
      expect(d.shouldAutoConnect, isFalse, reason: d.device.deviceId);
    }
  });

  test('sensors-only mode with Broadcast on: auto-connects', () async {
    await core.settings.setSensorsOnlyMode(true);
    core.sensors.register(FakeSensorSource(id: 'src', displayName: 'Src', provides: {SensorQuantity.heartRate}));
    core.sensors.select(SensorQuantity.heartRate, 'src');
    addTearDown(() {
      core.sensors.select(SensorQuantity.heartRate, null);
      core.sensors.unregister('src');
    });
    await core.connection.broadcast!.turnOn();
    expect(core.connection.broadcast!.isOn.value, isTrue);

    for (final d in devices) {
      expect(d.shouldAutoConnect, isTrue, reason: d.device.deviceId);
    }

    await core.connection.broadcast!.turnOff();
    for (final d in devices) {
      expect(d.shouldAutoConnect, isFalse, reason: d.device.deviceId);
    }
  });
}
