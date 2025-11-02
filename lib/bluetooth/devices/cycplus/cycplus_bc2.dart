import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:swift_control/utils/keymap/buttons.dart';
import 'package:universal_ble/universal_ble.dart';

import '../bluetooth_device.dart';

class CycplusBc2 extends BluetoothDevice {
  CycplusBc2(super.scanResult)
    : super(
        availableButtons: CycplusBc2Buttons.values,
      );

  @override
  Future<void> handleServices(List<BleService> services) async {
    final service = services.firstWhere(
      (e) => e.uuid.toLowerCase() == CycplusBc2Constants.SERVICE_UUID.toLowerCase(),
      orElse: () => throw Exception('Service not found: ${CycplusBc2Constants.SERVICE_UUID}'),
    );
    final characteristic = service.characteristics.firstWhere(
      (e) => e.uuid.toLowerCase() == CycplusBc2Constants.TX_CHARACTERISTIC_UUID.toLowerCase(),
      orElse: () => throw Exception('Characteristic not found: ${CycplusBc2Constants.TX_CHARACTERISTIC_UUID}'),
    );

    await UniversalBle.subscribeNotifications(device.deviceId, service.uuid, characteristic.uuid);
  }

  @override
  Future<void> processCharacteristic(String characteristic, Uint8List bytes) {
    if (characteristic.toLowerCase() == CycplusBc2Constants.TX_CHARACTERISTIC_UUID.toLowerCase()) {
      // Process CYCPLUS BC2 data
      // The BC2 typically sends button press data as simple byte values
      // Common patterns for virtual shifters:
      // - 0x01 or similar for shift up
      // - 0x02 or similar for shift down
      // - 0x00 for button release
      
      if (bytes.isNotEmpty) {
        final buttonCode = bytes[0];
        
        switch (buttonCode) {
          case 0x01:
            // Shift up button pressed
            handleButtonsClicked([CycplusBc2Buttons.shiftUp]);
            break;
          case 0x02:
            // Shift down button pressed
            handleButtonsClicked([CycplusBc2Buttons.shiftDown]);
            break;
          case 0x00:
            // Button released
            handleButtonsClicked([]);
            break;
          default:
            // Unknown button code - log for debugging
            print('CYCPLUS BC2: Unknown button code: 0x${buttonCode.toRadixString(16)}');
            break;
        }
      }
    }
    return Future.value();
  }
}

class CycplusBc2Constants {
  // Nordic UART Service (NUS) - commonly used by CYCPLUS BC2
  static const String SERVICE_UUID = "6e400001-b5a3-f393-e0a9-e50e24dcca9e";
  
  // TX Characteristic - device sends data to app
  static const String TX_CHARACTERISTIC_UUID = "6e400003-b5a3-f393-e0a9-e50e24dcca9e";
  
  // RX Characteristic - app sends data to device (not used for button reading)
  static const String RX_CHARACTERISTIC_UUID = "6e400002-b5a3-f393-e0a9-e50e24dcca9e";
}

class CycplusBc2Buttons {
  static const ControllerButton shiftUp = ControllerButton(
    'shiftUp',
    action: InGameAction.shiftUp,
    icon: Icons.add,
    color: Colors.green,
  );
  
  static const ControllerButton shiftDown = ControllerButton(
    'shiftDown',
    action: InGameAction.shiftDown,
    icon: Icons.remove,
    color: Colors.red,
  );

  static const List<ControllerButton> values = [
    shiftUp,
    shiftDown,
  ];
}
