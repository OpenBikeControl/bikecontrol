import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:bike_control/bluetooth/devices/thinkrider/thinkrider_vs200.dart';
import 'package:bike_control/utils/actions/base_actions.dart';
import 'package:bike_control/utils/core.dart';
import 'package:universal_ble/universal_ble.dart';

void main() {
  group('ThinkRider VS200 Virtual Shifter Tests', () {
    test('Test shift up button press', () {
      core.actionHandler = StubActions();

      final stubActions = core.actionHandler as StubActions;

      final device = ThinkRiderVs200(BleDevice(deviceId: 'deviceId', name: 'THINK VS01-0000285'));

      // First value to initialize state
      device.processCharacteristic(
        ThinkRiderVs200Constants.CHARACTERISTIC_UUID_1,
        _hexToUint8List('00'),
      );
      expect(stubActions.performedActions.isEmpty, true);

      // Changed value triggers shift up
      device.processCharacteristic(
        ThinkRiderVs200Constants.CHARACTERISTIC_UUID_1,
        _hexToUint8List('01'),
      );
      expect(stubActions.performedActions.length, 1);
      expect(stubActions.performedActions.first, ThinkRiderVs200Buttons.shiftUp);
    });

    test('Test shift down button press', () {
      core.actionHandler = StubActions();
      final stubActions = core.actionHandler as StubActions;
      final device = ThinkRiderVs200(BleDevice(deviceId: 'deviceId', name: 'THINK VS01-0000285'));

      // First value to initialize state
      device.processCharacteristic(
        ThinkRiderVs200Constants.CHARACTERISTIC_UUID_2,
        _hexToUint8List('00'),
      );
      expect(stubActions.performedActions.isEmpty, true);

      // Changed value triggers shift down
      device.processCharacteristic(
        ThinkRiderVs200Constants.CHARACTERISTIC_UUID_2,
        _hexToUint8List('01'),
      );
      expect(stubActions.performedActions.length, 1);
      expect(stubActions.performedActions.first, ThinkRiderVs200Buttons.shiftDown);
    });

    test('Test multiple value changes', () {
      core.actionHandler = StubActions();
      final stubActions = core.actionHandler as StubActions;
      final device = ThinkRiderVs200(BleDevice(deviceId: 'deviceId', name: 'THINK VS01-0000285'));

      // Initialize
      device.processCharacteristic(
        ThinkRiderVs200Constants.CHARACTERISTIC_UUID_1,
        _hexToUint8List('00'),
      );
      expect(stubActions.performedActions.isEmpty, true);

      // First change
      device.processCharacteristic(
        ThinkRiderVs200Constants.CHARACTERISTIC_UUID_1,
        _hexToUint8List('01'),
      );
      expect(stubActions.performedActions.length, 1);
      stubActions.performedActions.clear();

      // Second change
      device.processCharacteristic(
        ThinkRiderVs200Constants.CHARACTERISTIC_UUID_1,
        _hexToUint8List('02'),
      );
      expect(stubActions.performedActions.length, 1);
      expect(stubActions.performedActions.first, ThinkRiderVs200Buttons.shiftUp);
    });

    test('Test same value does not trigger action', () {
      core.actionHandler = StubActions();
      final stubActions = core.actionHandler as StubActions;
      final device = ThinkRiderVs200(BleDevice(deviceId: 'deviceId', name: 'THINK VS01-0000285'));

      // Initialize
      device.processCharacteristic(
        ThinkRiderVs200Constants.CHARACTERISTIC_UUID_1,
        _hexToUint8List('00'),
      );
      expect(stubActions.performedActions.isEmpty, true);

      // Same value
      device.processCharacteristic(
        ThinkRiderVs200Constants.CHARACTERISTIC_UUID_1,
        _hexToUint8List('00'),
      );
      expect(stubActions.performedActions.isEmpty, true);
    });
  });
}

Uint8List _hexToUint8List(String seq) {
  return Uint8List.fromList(
    List.generate(
      seq.length ~/ 2,
      (i) => int.parse(seq.substring(i * 2, i * 2 + 2), radix: 16),
    ),
  );
}
