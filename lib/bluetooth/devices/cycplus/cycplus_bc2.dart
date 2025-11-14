import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:swift_control/bluetooth/messages/notification.dart';
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
      // The BC2 sends button press data via Nordic UART Service
      // Based on observed behavior, the device sends:
      // - 0xfe for button presses (first byte)
      // - Additional bytes may contain button-specific data
      // - Pattern shows pairs of messages for press/release

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
          case 0xfe:
            // BC2 device sends 0xfe for button events
            // Check if there are additional bytes to distinguish buttons
            if (bytes.length > 1) {
              final secondByte = bytes[1];
              switch (secondByte) {
                case 0x01:
                  // Shift up button
                  handleButtonsClicked([CycplusBc2Buttons.shiftUp]);
                  break;
                case 0x02:
                  // Shift down button
                  handleButtonsClicked([CycplusBc2Buttons.shiftDown]);
                  break;
                case 0x00:
                  // Button release
                  handleButtonsClicked([]);
                  break;
                default:
                  // Log all bytes for further debugging
                  final bytesHex = bytes.map((b) => '0x${b.toRadixString(16).padLeft(2, '0')}').join(', ');
                  actionStreamInternal.add(
                    LogNotification('CYCPLUS BC2: Unknown multi-byte pattern: [$bytesHex]'),
                  );
                  break;
              }
            } else {
              // Single byte 0xfe without additional context
              actionStreamInternal.add(
                LogNotification('CYCPLUS BC2: Received single 0xfe byte (press or release?)'),
              );
            }
            break;
          default:
            // Unknown button code - log all bytes for debugging
            final bytesHex = bytes.map((b) => '0x${b.toRadixString(16).padLeft(2, '0')}').join(', ');
            actionStreamInternal.add(
              LogNotification('CYCPLUS BC2: Unknown pattern: [$bytesHex]'),
            );
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
  );

  static const ControllerButton shiftDown = ControllerButton(
    'shiftDown',
    action: InGameAction.shiftDown,
    icon: Icons.remove,
  );

  static const List<ControllerButton> values = [
    shiftUp,
    shiftDown,
  ];
}
