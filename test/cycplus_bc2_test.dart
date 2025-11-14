import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:swift_control/bluetooth/devices/cycplus/cycplus_bc2.dart';
import 'package:swift_control/main.dart';
import 'package:swift_control/utils/actions/base_actions.dart';
import 'package:universal_ble/universal_ble.dart';

void main() {
  group('CYCPLUS BC2 Virtual Shifter Tests', () {
    test('Test some sequences', () {
      actionHandler = StubActions();

      final stubActions = actionHandler as StubActions;

      // convert from hex to uint8list

      final device = CycplusBc2(BleDevice(deviceId: 'deviceId', name: 'name'));
      device.processCharacteristic(
        CycplusBc2Constants.TX_CHARACTERISTIC_UUID,
        _hexToUint8List('FEEFFFEE0206010397565E000155'),
      );
      expect(stubActions.performedActions.single, CycplusBc2Buttons.shiftUp);
      stubActions.performedActions.clear();

      device.processCharacteristic(
        CycplusBc2Constants.TX_CHARACTERISTIC_UUID,
        _hexToUint8List('FEEFFFEE0206030398565E000158'),
      );
      device.processCharacteristic(
        CycplusBc2Constants.TX_CHARACTERISTIC_UUID,
        _hexToUint8List('FEEFFFEE0206030198575E000157'),
      );
      device.processCharacteristic(
        CycplusBc2Constants.TX_CHARACTERISTIC_UUID,
        _hexToUint8List('FEEFFFEE0206030398585E00015A'),
      );
      device.processCharacteristic(
        CycplusBc2Constants.TX_CHARACTERISTIC_UUID,
        _hexToUint8List('FEEFFFEE0206010399585E000159'),
      );
      device.processCharacteristic(
        CycplusBc2Constants.TX_CHARACTERISTIC_UUID,
        _hexToUint8List('FEEFFFEE020603039A585E00015C'),
      );
      device.processCharacteristic(
        CycplusBc2Constants.TX_CHARACTERISTIC_UUID,
        _hexToUint8List('FEEFFFEE020603019A595E00015B'),
      );
      device.processCharacteristic(
        CycplusBc2Constants.TX_CHARACTERISTIC_UUID,
        _hexToUint8List('FEEFFFEE020603039A5A5E00015E'),
      );
      device.processCharacteristic(
        CycplusBc2Constants.TX_CHARACTERISTIC_UUID,
        _hexToUint8List('FEEFFFEE020601039B5A5E00015D'),
      );
      device.processCharacteristic(
        CycplusBc2Constants.TX_CHARACTERISTIC_UUID,
        _hexToUint8List('FEEFFFEE020603039C5A5E000160'),
      );
      device.processCharacteristic(
        CycplusBc2Constants.TX_CHARACTERISTIC_UUID,
        _hexToUint8List('FEEFFFEE020603019C5B5E00015F'),
      );
      device.processCharacteristic(
        CycplusBc2Constants.TX_CHARACTERISTIC_UUID,
        _hexToUint8List('FEEFFFEE020603039C5C5E000162'),
      );
      device.processCharacteristic(
        CycplusBc2Constants.TX_CHARACTERISTIC_UUID,
        _hexToUint8List('FEEFFFEE020601039D5C5E000161'),
      );
      device.processCharacteristic(
        CycplusBc2Constants.TX_CHARACTERISTIC_UUID,
        _hexToUint8List('FEEFFFEE020603039E5C5D000163'),
      );
      device.processCharacteristic(
        CycplusBc2Constants.TX_CHARACTERISTIC_UUID,
        _hexToUint8List('FEEFFFEE020603019E5D5D000162'),
      );
      device.processCharacteristic(
        CycplusBc2Constants.TX_CHARACTERISTIC_UUID,
        _hexToUint8List('FEEFFFEE020603039E5E5D000165'),
      );
      device.processCharacteristic(
        CycplusBc2Constants.TX_CHARACTERISTIC_UUID,
        _hexToUint8List('FEEFFFEE020601039F5E5D000164'),
      );
      device.processCharacteristic(
        CycplusBc2Constants.TX_CHARACTERISTIC_UUID,
        _hexToUint8List('FEEFFFEE02060303A05E5D000167'),
      );
      device.processCharacteristic(
        CycplusBc2Constants.TX_CHARACTERISTIC_UUID,
        _hexToUint8List('FEEFFFEE02060301A05F5D000166'),
      );
      device.processCharacteristic(
        CycplusBc2Constants.TX_CHARACTERISTIC_UUID,
        _hexToUint8List('FEEFFFEE02060302A0605D000168'),
      );
      device.processCharacteristic(
        CycplusBc2Constants.TX_CHARACTERISTIC_UUID,
        _hexToUint8List('FEEFFFEE02060102A1605D000167'),
      );
      device.processCharacteristic(
        CycplusBc2Constants.TX_CHARACTERISTIC_UUID,
        _hexToUint8List('FEEFFFEE02060302A2605D00016A'),
      );
      device.processCharacteristic(
        CycplusBc2Constants.TX_CHARACTERISTIC_UUID,
        _hexToUint8List('FEEFFFEE02060301A2615D00016A'),
      );
      device.processCharacteristic(
        CycplusBc2Constants.TX_CHARACTERISTIC_UUID,
        _hexToUint8List('FEEFFFEE02060303A2625D00016D'),
      );
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
