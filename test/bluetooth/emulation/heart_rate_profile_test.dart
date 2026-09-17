import 'dart:typed_data';

import 'package:bike_control/bluetooth/devices/bluetooth_device.dart';
import 'package:bike_control/bluetooth/devices/sensors/ble_heart_rate_device.dart';
import 'package:bike_control/bluetooth/emulation/emulated_peripherals.dart';
import 'package:bike_control/services/sensors/ble_sensor_source.dart';
import 'package:bike_control/services/sensors/sensor_quantity.dart';
import 'package:bike_control/utils/actions/base_actions.dart';
import 'package:bike_control/utils/core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:universal_ble/universal_ble.dart';

void main() {
  core.actionHandler = StubActions();

  test('the emulated strap advertises the heart rate service', () {
    final peripheral = heartRateStrapPeripheral();

    // Both halves matter: `services` is what a connected client discovers,
    // `advertisedServices` is what a filtered scan matches.
    expect(
      peripheral.services.map((s) => s.uuid.toLowerCase()),
      contains(BleSensorSource.heartRateServiceUuid),
    );
    expect(
      peripheral.advertisedServices,
      contains(BleSensorSource.heartRateServiceUuid),
    );
  });

  test('the emulated strap exposes the measurement characteristic', () {
    final peripheral = heartRateStrapPeripheral();

    final service = peripheral.services.firstWhere(
      (s) => s.uuid.toLowerCase() == BleSensorSource.heartRateServiceUuid,
    );

    expect(
      service.characteristics.map((c) => c.uuid.toLowerCase()),
      contains(BleSensorSource.heartRateMeasurementUuid),
    );
  });

  test('the emulated strap is detected as BleHeartRateDevice', () {
    final scanResult = BleDevice(
      deviceId: 'emulated:hrm',
      name: 'Emulated HRM',
      services: [BleSensorSource.heartRateServiceUuid.toLowerCase()],
    );

    final device = BluetoothDevice.fromScanResult(scanResult);
    expect(device, isInstanceOf<BleHeartRateDevice>());
  });

  test('emulated strap processes heart rate measurement payload', () async {
    // Create the device from a scan result
    final scanResult = BleDevice(
      deviceId: 'emulated:hrm',
      name: 'Emulated HRM',
      services: [BleSensorSource.heartRateServiceUuid.toLowerCase()],
    );

    final device = BluetoothDevice.fromScanResult(scanResult) as BleHeartRateDevice;

    // Process a heart rate measurement: flags byte 0x00 (uint8), value 140 bpm.
    // The device's processCharacteristic method calls ingestHeartRateMeasurement
    // on its source, updating the sensor reading.
    await device.processCharacteristic(
      BleSensorSource.heartRateMeasurementUuid,
      Uint8List.fromList([0x00, 140]),
    );

    // Verify the source reports the correct heart rate
    expect(device.source.readingFor(SensorQuantity.heartRate).value?.value, 140);
  });
}
