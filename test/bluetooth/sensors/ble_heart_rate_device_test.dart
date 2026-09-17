import 'dart:typed_data';

import 'package:bike_control/bluetooth/devices/bluetooth_device.dart';
import 'package:bike_control/bluetooth/devices/sensors/ble_heart_rate_device.dart';
import 'package:bike_control/services/sensors/ble_sensor_source.dart';
import 'package:bike_control/services/sensors/sensor_quantity.dart';
import 'package:bike_control/utils/actions/base_actions.dart';
import 'package:bike_control/utils/core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:universal_ble/universal_ble.dart';

BleHeartRateDevice _device() => BleHeartRateDevice(BleDevice(deviceId: 'hr-1', name: 'TICKR 1234'));

void main() {
  // Constructing a BluetoothDevice with an empty availableButtons list
  // touches core.actionHandler (BaseDevice's ctor probes the current
  // keymap) — same requirement as every other device-detection test.
  core.actionHandler = StubActions();

  // V1b (wave 3): `shouldAutoConnect` now reads a persisted per-device
  // consent flag instead of a hard-coded `false`, so this file touches
  // `core.settings` for the first time.
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    core.settings.prefs = await SharedPreferences.getInstance();
  });

  test('routes a measurement notification into its source', () async {
    final device = _device();

    await device.processCharacteristic(
      BleSensorSource.heartRateMeasurementUuid,
      Uint8List.fromList([0x00, 150]),
    );

    expect(device.source.readingFor(SensorQuantity.heartRate).value!.value, 150);
  });

  test('ignores a notification on an unrelated characteristic', () async {
    final device = _device();

    await device.processCharacteristic(
      '00002a19-0000-1000-8000-00805f9b34fb', // battery level
      Uint8List.fromList([0x00, 99]),
    );

    expect(device.source.readingFor(SensorQuantity.heartRate).value, isNull);
  });

  test('matches the characteristic case-insensitively', () async {
    final device = _device();

    await device.processCharacteristic(
      BleSensorSource.heartRateMeasurementUuid.toUpperCase(),
      Uint8List.fromList([0x00, 141]),
    );

    expect(device.source.readingFor(SensorQuantity.heartRate).value!.value, 141);
  });

  test('the source is identified by the device id, so a selection can be persisted', () {
    final device = _device();

    expect(device.source.id, 'hr-1');
    expect(device.source.provides, {SensorQuantity.heartRate});
  });

  test('handleServices throws a named error when the strap has no heart rate service', () async {
    final device = _device();

    expect(
      () => device.handleServices(const <BleService>[]),
      throwsA(isA<Exception>()),
    );
  });

  // Fix-wave-1 (F1, urgent): a strap must never be auto-connected. Before this
  // fix, `shouldAutoConnect` defaulted to true and `Connection.addDevices`
  // pushed every discovered strap into the connect queue — silently taking it
  // away from Zwift, a bike computer or a watch, most of which only allow one
  // BLE connection at a time. Wave 3 (V1b) replaced the hard `false` with a
  // persisted per-device consent flag (see `Settings.getSensorAutoConnect`),
  // but a never-asked strap must still default to false.
  test('shouldAutoConnect is false until the rider explicitly connects it', () {
    final device = _device();

    expect(device.shouldAutoConnect, isFalse);
  });

  test('connect() honours shouldAutoConnect by opening no transport', () async {
    final device = _device();

    // No BLE platform is installed in this plain unit test. If connect()
    // reached BluetoothDevice's upstream path (UniversalBle.connect), it
    // would throw trying to invoke a platform channel with nothing bound to
    // it. Completing cleanly, with isConnected still false, proves the early
    // return in BleHeartRateDevice.connect() fired instead.
    await device.connect();

    expect(device.isConnected, isFalse);
  });

  // V1b (wave 3): the missing rider-facing "connect this strap" action the
  // fix-wave-1 doc comment above called out. Persisting explicit consent —
  // exactly what the "Connect" button on the discovered-sensors list does —
  // must flip the gate, so it also survives a strap being rediscovered as a
  // fresh instance (see `SensorHub.register`'s doc comment for why that
  // happens on every reconnect).
  test('shouldAutoConnect flips true once the rider has explicitly connected this device id', () async {
    final device = _device();
    expect(device.shouldAutoConnect, isFalse);

    await core.settings.setSensorAutoConnect(device.device.deviceId, true);

    expect(device.shouldAutoConnect, isTrue);
  });

  test('connect() proceeds past the gate once consent is granted', () async {
    final device = _device();
    await core.settings.setSensorAutoConnect(device.device.deviceId, true);

    // Same reasoning as the sibling test above, in reverse: no BLE platform
    // is installed here, so reaching BluetoothDevice's upstream path now
    // throws instead of returning cleanly — proving the early return no
    // longer fires once the rider has explicitly connected this strap.
    await expectLater(device.connect(), throwsA(anything));
  });

  // Fix-wave-1 (F6): without `Accessory`, `Connection` remembers a strap as
  // `RememberedDeviceKind.controller` and its settings page renders an empty
  // Button Mapping table — a strap has no buttons to map.
  test('is an Accessory, not a controller', () {
    final device = _device();

    expect(device, isA<Accessory>());
  });
}
