import 'package:bike_control/bluetooth/devices/proxy/proxy_device.dart';
import 'package:bike_control/utils/actions/base_actions.dart';
import 'package:bike_control/utils/core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:universal_ble/universal_ble.dart';

void main() {
  setUpAll(() {
    core.actionHandler = StubActions();
  });

  group('ProxyDevice._isSmartTrainer', () {
    test('FTMS-only scan result is treated as a smart trainer', () {
      final dev = ProxyDevice(BleDevice(
        deviceId: 'ftms',
        name: 'KICKR',
        services: const ['00001826-0000-1000-8000-00805f9b34fb'],
      ));
      expect(dev.debugIsSmartTrainerForTesting, isTrue);
    });

    test('FE-C-only scan result is also treated as a smart trainer', () {
      final dev = ProxyDevice(BleDevice(
        deviceId: 'fec',
        name: 'X2Max',
        services: const ['6e40fec1-b5a3-f393-e0a9-e50e24dcca9e'],
      ));
      expect(dev.debugIsSmartTrainerForTesting, isTrue);
    });

    test('Power-meter-only scan result (CPS) is NOT a smart trainer', () {
      final dev = ProxyDevice(BleDevice(
        deviceId: 'pm',
        name: 'Stages',
        services: const ['00001818-0000-1000-8000-00805f9b34fb'],
      ));
      expect(dev.debugIsSmartTrainerForTesting, isFalse);
    });

    test('HR-only scan result is NOT a smart trainer', () {
      final dev = ProxyDevice(BleDevice(
        deviceId: 'hr',
        name: 'TICKR',
        services: const ['0000180d-0000-1000-8000-00805f9b34fb'],
      ));
      expect(dev.debugIsSmartTrainerForTesting, isFalse);
    });

    test('UUID matching is case-insensitive', () {
      final dev = ProxyDevice(BleDevice(
        deviceId: 'fec-upper',
        name: 'X2Max',
        services: const ['6E40FEC1-B5A3-F393-E0A9-E50E24DCCA9E'],
      ));
      expect(dev.debugIsSmartTrainerForTesting, isTrue);
    });
  });
}
