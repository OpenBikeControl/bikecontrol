import 'dart:typed_data';

import 'package:bike_control/bluetooth/messages/notification.dart';
import 'package:bike_control/utils/keymap/buttons.dart';
import 'package:bike_control/widgets/controller/controller_layout.dart';
import 'package:flutter/material.dart';
import 'package:universal_ble/universal_ble.dart';

import '../bluetooth_device.dart';

class CycplusBc2 extends BluetoothDevice {
  CycplusBc2(super.scanResult)
    : super(
        availableButtons: CycplusBc2Buttons.values,
        allowMultiple: true,
      );

  @override
  ControllerLayout get controllerLayout => ControllerLayout(
    aspectRatio: 1.0,
    shape: ContourShape.pill,
    svgAsset: 'assets/contours/cycpluc_bc2.svg',
    positions: {
      CycplusBc2Buttons.shiftUp: const Offset(0.3, 0.5),
      CycplusBc2Buttons.shiftDown: const Offset(0.7, 0.5),
    },
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

  // Track last state for index 6 and 7
  static const _pressedState = 0x01;

  @override
  Future<void> processCharacteristic(String characteristic, Uint8List bytes) {
    if (characteristic.toLowerCase() == CycplusBc2Constants.TX_CHARACTERISTIC_UUID.toLowerCase()) {
      if (bytes.length > 7) {
        final buttonsToPress = <ControllerButton>[];

        // Process index 6 (shift up)
        final currentByte6 = bytes[6];
        if (currentByte6 == _pressedState) {
          buttonsToPress.add(availableButtons[0]);
        }

        // Process index 7 (shift down)
        final currentByte7 = bytes[7];
        if (currentByte7 == _pressedState) {
          buttonsToPress.add(availableButtons[1]);
        }

        handleButtonsClicked(buttonsToPress);
      } else {
        actionStreamInternal.add(
          LogNotification(
            'CYCPLUS BC2 received unexpected packet: ${bytes.map((e) => e.toRadixString(16).padLeft(2, '0')).join()}',
          ),
        );
        handleButtonsClicked([]);
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
