import 'dart:typed_data';

import 'package:bike_control/bluetooth/devices/bluetooth_device.dart';
import 'package:bike_control/bluetooth/devices/sensors/ble_cadence_device.dart';
import 'package:bike_control/bluetooth/devices/sensors/ble_power_device.dart';
import 'package:bike_control/bluetooth/emulation/emulated_ble_platform.dart';
import 'package:bike_control/bluetooth/emulation/emulated_peripherals.dart';
import 'package:bike_control/bluetooth/emulation/emulation_manager.dart';
import 'package:bike_control/bluetooth/emulation/emulation_profile.dart';
import 'package:bike_control/bluetooth/emulation/profiles/misc_profiles.dart';
import 'package:bike_control/services/sensors/ble_sensor_source.dart';
import 'package:bike_control/services/sensors/sensor_quantity.dart';
import 'package:bike_control/utils/actions/base_actions.dart';
import 'package:bike_control/utils/core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prop/utils/csc_measurement.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  // Constructing a BluetoothDevice with an empty availableButtons list
  // touches core.actionHandler (BaseDevice's ctor probes the current
  // keymap) — same requirement as every other device-detection test.
  core.actionHandler = StubActions();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    core.settings.prefs = await SharedPreferences.getInstance();
  });

  group('cadence sensor peripheral', () {
    test('advertises the CSC service', () {
      final peripheral = cadenceSensorPeripheral();

      // Both halves matter: `services` is what a connected client discovers,
      // `advertisedServices` is what a filtered scan matches.
      expect(peripheral.services.map((s) => s.uuid.toLowerCase()), contains(BleSensorSource.cscServiceUuid));
      expect(peripheral.advertisedServices, contains(BleSensorSource.cscServiceUuid));
    });

    test('uses the emulated: colon prefix so post-teardown calls route to the fake stack', () {
      final peripheral = cadenceSensorPeripheral();

      expect(peripheral.deviceId, startsWith('emulated:'));
    });

    test('exposes the CSC measurement characteristic', () {
      final peripheral = cadenceSensorPeripheral();

      final service = peripheral.services.firstWhere((s) => s.uuid.toLowerCase() == BleSensorSource.cscServiceUuid);

      expect(service.characteristics.map((c) => c.uuid.toLowerCase()), contains(BleSensorSource.cscMeasurementUuid));
    });

    test('the fixture scan result is detected as BleCadenceDevice', () {
      final scanResult = cadenceSensorPeripheral().scanResult;

      expect(BluetoothDevice.fromScanResult(scanResult), isInstanceOf<BleCadenceDevice>());
    });

    test('a constant frame notified twice yields no cadence — proves a fixture must advance, not repeat', () async {
      final scanResult = cadenceSensorPeripheral().scanResult;
      final device = BluetoothDevice.fromScanResult(scanResult) as BleCadenceDevice;
      final counter = CrankCounter();
      counter.advance(90);
      final frame = Uint8List.fromList(buildCscMeasurement(counter.revs, counter.eventTime1024));

      await device.processCharacteristic(BleSensorSource.cscMeasurementUuid, frame);
      await device.processCharacteristic(BleSensorSource.cscMeasurementUuid, frame);

      expect(device.source.readingFor(SensorQuantity.cadence).value, isNull);
    });

    test('two successive frames from the profile action yield the intended rpm through the real device', () async {
      final ble = FakeUniversalBlePlatform();
      final manager = EmulationManager()..attach(ble);
      final session = manager.start(cadenceSensorProfile);
      final device = BluetoothDevice.fromScanResult(session.peripheral.scanResult) as BleCadenceDevice;

      Uint8List? lastFrame;
      ble.onValueChange = (deviceId, characteristicId, value, timestamp) => lastFrame = value;

      final notify90 = session.inputs.whereType<EmulatedAction>().firstWhere((a) => a.label == 'Notify 90 rpm');

      notify90.run();
      await device.processCharacteristic(BleSensorSource.cscMeasurementUuid, lastFrame!);
      // The first sample only establishes the baseline — correct, not a
      // dropped reading (CSC/CPS report a cumulative counter, not an rpm).
      expect(device.source.readingFor(SensorQuantity.cadence).value, isNull);

      notify90.run();
      await device.processCharacteristic(BleSensorSource.cscMeasurementUuid, lastFrame!);

      expect(device.source.readingFor(SensorQuantity.cadence).value?.value, 90);
    });
  });

  group('power meter peripheral', () {
    test('advertises the Cycling Power service', () {
      final peripheral = powerMeterPeripheral();

      expect(peripheral.services.map((s) => s.uuid.toLowerCase()), contains(BleSensorSource.cyclingPowerServiceUuid));
      expect(peripheral.advertisedServices, contains(BleSensorSource.cyclingPowerServiceUuid));
    });

    test('uses the emulated: colon prefix so post-teardown calls route to the fake stack', () {
      final peripheral = powerMeterPeripheral();

      expect(peripheral.deviceId, startsWith('emulated:'));
    });

    test('exposes the Cycling Power measurement characteristic', () {
      final peripheral = powerMeterPeripheral();

      final service = peripheral.services.firstWhere(
        (s) => s.uuid.toLowerCase() == BleSensorSource.cyclingPowerServiceUuid,
      );

      expect(
        service.characteristics.map((c) => c.uuid.toLowerCase()),
        contains(BleSensorSource.cyclingPowerMeasurementUuid),
      );
    });

    // `BluetoothDevice.fromScanResult`'s narrow power-meter rule requires a
    // name on the known-power-meter list — see
    // `BluetoothDevice._isKnownPowerMeterName`. If the fixture's default
    // name didn't match that list, this would fail for the wrong reason
    // (resolves to ProxyDevice) rather than the interesting one.
    test('the fixture scan result is detected as BlePowerDevice with no opt-in step', () {
      final scanResult = powerMeterPeripheral().scanResult;

      expect(BluetoothDevice.fromScanResult(scanResult), isInstanceOf<BlePowerDevice>());
    });

    test('two successive frames from the profile action yield the intended watts and rpm', () async {
      final ble = FakeUniversalBlePlatform();
      final manager = EmulationManager()..attach(ble);
      final session = manager.start(powerMeterProfile);
      final device = BluetoothDevice.fromScanResult(session.peripheral.scanResult) as BlePowerDevice;

      Uint8List? lastFrame;
      ble.onValueChange = (deviceId, characteristicId, value, timestamp) => lastFrame = value;

      final notify = session.inputs.whereType<EmulatedAction>().firstWhere(
        (a) => a.label == 'Notify 250 W @ 90 rpm',
      );

      notify.run();
      await device.processCharacteristic(BleSensorSource.cyclingPowerMeasurementUuid, lastFrame!);
      // Power publishes from a single frame — unlike cadence, it does not
      // wait for a second sample.
      expect(device.source.readingFor(SensorQuantity.power).value?.value, 250);
      expect(device.source.readingFor(SensorQuantity.cadence).value, isNull);

      notify.run();
      await device.processCharacteristic(BleSensorSource.cyclingPowerMeasurementUuid, lastFrame!);

      expect(device.source.readingFor(SensorQuantity.power).value?.value, 250);
      expect(device.source.readingFor(SensorQuantity.cadence).value?.value, 90);
    });
  });
}
