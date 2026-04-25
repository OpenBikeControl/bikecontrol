import 'dart:typed_data';

import 'package:bike_control/bluetooth/messages/notification.dart';
import 'package:bike_control/utils/keymap/buttons.dart';
import 'package:bike_control/widgets/controller/controller_layout.dart';
import 'package:flutter/material.dart';
import 'package:universal_ble/universal_ble.dart';

import '../bluetooth_device.dart';

class ThinkRiderVs200 extends BluetoothDevice {
  ThinkRiderVs200(super.scanResult)
    : super(
        availableButtons: ThinkRiderVs200Buttons.values,
        isBeta: false,
        allowMultiple: true,
        supportsLongPress: false,
      );

  @override
  ControllerLayout get controllerLayout => ControllerLayout(
    aspectRatio: 1124.01 / 766.94,
    shape: ContourShape.pill,
    svgAsset: 'assets/contours/thinkrider_vs200.svg',
    rotation: 90,
    positions: {
      ThinkRiderVs200Buttons.shiftDown: const Offset(0.26, 0.5),
      ThinkRiderVs200Buttons.shiftUp: const Offset(0.74, 0.5),
    },
  );

  @override
  Future<void> handleServices(List<BleService> services) async {
    // Only subscribe to service 0xFEA0
    final service = services.firstWhere(
      (e) => e.uuid.toLowerCase() == ThinkRiderVs200Constants.SERVICE_UUID.toLowerCase(),
      orElse: () => throw Exception('Service not found: ${ThinkRiderVs200Constants.SERVICE_UUID}'),
    );
    final characteristic = service.characteristics.firstWhere(
      (e) => e.uuid.toLowerCase() == ThinkRiderVs200Constants.CHARACTERISTIC_UUID.toLowerCase(),
      orElse: () => throw Exception('Characteristic not found: ${ThinkRiderVs200Constants.CHARACTERISTIC_UUID}'),
    );

    await UniversalBle.subscribeNotifications(device.deviceId, service.uuid, characteristic.uuid);
  }

  @override
  Future<void> processCharacteristic(String characteristic, Uint8List bytes) async {
    if (characteristic.toLowerCase() == ThinkRiderVs200Constants.CHARACTERISTIC_UUID.toLowerCase()) {
      final hexValue = _bytesToHex(bytes).toLowerCase();

      // Log all received values while in beta
      if (isBeta) {
        actionStreamInternal.add(LogNotification('VS200 received: $hexValue'));
      }

      // Check for specific byte patterns
      if (hexValue == ThinkRiderVs200Constants.SHIFT_UP_PATTERN) {
        // Plus button pressed
        actionStreamInternal.add(LogNotification('Shift Up detected: $hexValue'));
        await handleButtonsClicked([availableButtons[0]]);
        await handleButtonsClicked([]);
      } else if (hexValue == ThinkRiderVs200Constants.SHIFT_DOWN_PATTERN) {
        // Minus button pressed
        actionStreamInternal.add(LogNotification('Shift Down detected: $hexValue'));
        await handleButtonsClicked([availableButtons[1]]);
        await handleButtonsClicked([]);
      }
    }

    return Future.value();
  }

  String _bytesToHex(List<int> bytes) {
    return bytes.map((byte) => byte.toRadixString(16).padLeft(2, '0')).join();
  }
}

class ThinkRiderVs200Constants {
  // Service and characteristic UUIDs based on the nRF Connect screenshot
  static const String SERVICE_UUID = "0000fea0-0000-1000-8000-00805f9b34fb";
  static const String CHARACTERISTIC_UUID = "0000fea1-0000-1000-8000-00805f9b34fb";

  // Byte patterns for button detection
  static const String SHIFT_UP_PATTERN = "f3050301fc";
  static const String SHIFT_DOWN_PATTERN = "f3050300fb";
}

class ThinkRiderVs200Buttons {
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
