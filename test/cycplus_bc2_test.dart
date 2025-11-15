import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:swift_control/bluetooth/devices/cycplus/cycplus_bc2.dart';
import 'package:swift_control/main.dart';
import 'package:swift_control/utils/actions/base_actions.dart';
import 'package:universal_ble/universal_ble.dart';

void main() {
  group('CYCPLUS BC2 Virtual Shifter Tests', () {
    test('Test state machine with full sequence', () {
      actionHandler = StubActions();

      final stubActions = actionHandler as StubActions;

      final device = CycplusBc2(BleDevice(deviceId: 'deviceId', name: 'name'));
      
      // Packet 0: [6]=01 [7]=03 -> No trigger (lock state)
      device.processCharacteristic(
        CycplusBc2Constants.TX_CHARACTERISTIC_UUID,
        _hexToUint8List('FEEFFFEE0206010397565E000155'),
      );
      expect(stubActions.performedActions.isEmpty, true);
      
      // Packet 1: [6]=03 [7]=03 -> Trigger: shiftUp
      device.processCharacteristic(
        CycplusBc2Constants.TX_CHARACTERISTIC_UUID,
        _hexToUint8List('FEEFFFEE0206030398565E000158'),
      );
      expect(stubActions.performedActions.length, 1);
      expect(stubActions.performedActions.first, CycplusBc2Buttons.shiftUp);
      stubActions.performedActions.clear();
      
      // Packet 2: [6]=03 [7]=01 -> Trigger: shiftDown
      device.processCharacteristic(
        CycplusBc2Constants.TX_CHARACTERISTIC_UUID,
        _hexToUint8List('FEEFFFEE0206030198575E000157'),
      );
      expect(stubActions.performedActions.length, 1);
      expect(stubActions.performedActions.first, CycplusBc2Buttons.shiftDown);
      stubActions.performedActions.clear();
      
      // Packet 3: [6]=03 [7]=03 -> No trigger (lock state)
      device.processCharacteristic(
        CycplusBc2Constants.TX_CHARACTERISTIC_UUID,
        _hexToUint8List('FEEFFFEE0206030398585E00015A'),
      );
      expect(stubActions.performedActions.isEmpty, true);
      
      // Packet 4: [6]=01 [7]=03 -> Trigger: shiftUp
      device.processCharacteristic(
        CycplusBc2Constants.TX_CHARACTERISTIC_UUID,
        _hexToUint8List('FEEFFFEE0206010399585E000159'),
      );
      expect(stubActions.performedActions.length, 1);
      expect(stubActions.performedActions.first, CycplusBc2Buttons.shiftUp);
      stubActions.performedActions.clear();
    });

    test('Test release and re-press behavior', () {
      actionHandler = StubActions();
      final stubActions = actionHandler as StubActions;
      final device = CycplusBc2(BleDevice(deviceId: 'deviceId', name: 'name'));
      
      // Press: lock state
      device.processCharacteristic(
        CycplusBc2Constants.TX_CHARACTERISTIC_UUID,
        _hexToUint8List('FEEFFFEE0206010300005E000100'),
      );
      expect(stubActions.performedActions.isEmpty, true);
      
      // Release: reset state
      device.processCharacteristic(
        CycplusBc2Constants.TX_CHARACTERISTIC_UUID,
        _hexToUint8List('FEEFFFEE0206000000005E000100'),
      );
      expect(stubActions.performedActions.isEmpty, true);
      
      // Press again: lock state (no trigger since we reset)
      device.processCharacteristic(
        CycplusBc2Constants.TX_CHARACTERISTIC_UUID,
        _hexToUint8List('FEEFFFEE0206020300005E000100'),
      );
      expect(stubActions.performedActions.isEmpty, true);
      
      // Change to different pressed value: trigger
      device.processCharacteristic(
        CycplusBc2Constants.TX_CHARACTERISTIC_UUID,
        _hexToUint8List('FEEFFFEE0206010300005E000100'),
      );
      expect(stubActions.performedActions.length, 1);
      expect(stubActions.performedActions.first, CycplusBc2Buttons.shiftUp);
    });
    
    test('Test both buttons can trigger simultaneously', () {
      actionHandler = StubActions();
      final stubActions = actionHandler as StubActions;
      final device = CycplusBc2(BleDevice(deviceId: 'deviceId', name: 'name'));
      
      // Lock both states
      device.processCharacteristic(
        CycplusBc2Constants.TX_CHARACTERISTIC_UUID,
        _hexToUint8List('FEEFFFEE0206010100005E000100'),
      );
      expect(stubActions.performedActions.isEmpty, true);
      
      // Change both: trigger both
      device.processCharacteristic(
        CycplusBc2Constants.TX_CHARACTERISTIC_UUID,
        _hexToUint8List('FEEFFFEE0206020200005E000100'),
      );
      expect(stubActions.performedActions.length, 2);
      expect(stubActions.performedActions.contains(CycplusBc2Buttons.shiftUp), true);
      expect(stubActions.performedActions.contains(CycplusBc2Buttons.shiftDown), true);
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
