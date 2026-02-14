import 'dart:typed_data';

import 'package:bike_control/bluetooth/devices/thinkrider/thinkrider_vs200.dart';
import 'package:bike_control/utils/actions/base_actions.dart';
import 'package:bike_control/utils/core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:universal_ble/universal_ble.dart';

void main() {
  group('ThinkRider VS200 Virtual Shifter Tests', () {
    test('Test shift up button press with correct pattern', () {
      core.actionHandler = StubActions();

      final stubActions = core.actionHandler as StubActions;

      final device = ThinkRiderVs200(BleDevice(deviceId: 'deviceId', name: 'THINK VS01-0000285'));

      // Send shift up pattern: F3-05-03-01-FC
      device.processCharacteristic(
        ThinkRiderVs200Constants.CHARACTERISTIC_UUID,
        _hexToUint8List('F3050301FC'),
      );
      expect(stubActions.performedActions.length, 1);
      expect(
        stubActions.performedActions.first,
        PerformedAction(ThinkRiderVs200Buttons.shiftUp, isDown: true, isUp: true),
      );
    });

    test('Test shift down button press with correct pattern', () {
      core.actionHandler = StubActions();
      final stubActions = core.actionHandler as StubActions;
      final device = ThinkRiderVs200(BleDevice(deviceId: 'deviceId', name: 'THINK VS01-0000285'));

      // Send shift down pattern: F3-05-03-00-FB
      device.processCharacteristic(
        ThinkRiderVs200Constants.CHARACTERISTIC_UUID,
        _hexToUint8List('F3050300FB'),
      );
      expect(stubActions.performedActions.length, 1);
      expect(
        stubActions.performedActions.first,
        PerformedAction(ThinkRiderVs200Buttons.shiftDown, isDown: true, isUp: true),
      );
    });

    test('Test multiple button presses', () {
      core.actionHandler = StubActions();
      final stubActions = core.actionHandler as StubActions;
      final device = ThinkRiderVs200(BleDevice(deviceId: 'deviceId', name: 'THINK VS01-0000285'));

      // Shift up
      device.processCharacteristic(
        ThinkRiderVs200Constants.CHARACTERISTIC_UUID,
        _hexToUint8List('F3050301FC'),
      );
      expect(stubActions.performedActions.length, 1);
      expect(
        stubActions.performedActions.first,
        PerformedAction(ThinkRiderVs200Buttons.shiftUp, isDown: true, isUp: true),
      );
      stubActions.performedActions.clear();

      // Shift down
      device.processCharacteristic(
        ThinkRiderVs200Constants.CHARACTERISTIC_UUID,
        _hexToUint8List('F3050300FB'),
      );
      expect(stubActions.performedActions.length, 1);
      expect(
        stubActions.performedActions.first,
        PerformedAction(ThinkRiderVs200Buttons.shiftDown, isDown: true, isUp: true),
      );
    });

    test('Test incorrect pattern does not trigger action', () {
      core.actionHandler = StubActions();
      final stubActions = core.actionHandler as StubActions;
      final device = ThinkRiderVs200(BleDevice(deviceId: 'deviceId', name: 'THINK VS01-0000285'));

      // Send random pattern
      device.processCharacteristic(
        ThinkRiderVs200Constants.CHARACTERISTIC_UUID,
        _hexToUint8List('0000000000'),
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
