import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:bike_control/bluetooth/messages/notification.dart';
import 'package:bike_control/utils/keymap/buttons.dart';
import 'package:universal_ble/universal_ble.dart';

import '../bluetooth_device.dart';

class ThinkRiderVs200 extends BluetoothDevice {
  ThinkRiderVs200(super.scanResult)
    : super(
        availableButtons: ThinkRiderVs200Buttons.values,
        isBeta: true,
      );

  @override
  Future<void> handleServices(List<BleService> services) async {
    // Subscribe to both characteristics
    final service1 = services.firstWhere(
      (e) => e.uuid.toLowerCase() == ThinkRiderVs200Constants.SERVICE_UUID_1.toLowerCase(),
      orElse: () => throw Exception('Service not found: ${ThinkRiderVs200Constants.SERVICE_UUID_1}'),
    );
    final characteristic1 = service1.characteristics.firstWhere(
      (e) => e.uuid.toLowerCase() == ThinkRiderVs200Constants.CHARACTERISTIC_UUID_1.toLowerCase(),
      orElse: () => throw Exception('Characteristic not found: ${ThinkRiderVs200Constants.CHARACTERISTIC_UUID_1}'),
    );

    final service2 = services.firstWhere(
      (e) => e.uuid.toLowerCase() == ThinkRiderVs200Constants.SERVICE_UUID_2.toLowerCase(),
      orElse: () => throw Exception('Service not found: ${ThinkRiderVs200Constants.SERVICE_UUID_2}'),
    );
    final characteristic2 = service2.characteristics.firstWhere(
      (e) => e.uuid.toLowerCase() == ThinkRiderVs200Constants.CHARACTERISTIC_UUID_2.toLowerCase(),
      orElse: () => throw Exception('Characteristic not found: ${ThinkRiderVs200Constants.CHARACTERISTIC_UUID_2}'),
    );

    await UniversalBle.subscribeNotifications(device.deviceId, service1.uuid, characteristic1.uuid);
    await UniversalBle.subscribeNotifications(device.deviceId, service2.uuid, characteristic2.uuid);
  }

  // Track last values to detect changes
  String? _lastValue1;
  String? _lastValue2;

  @override
  Future<void> processCharacteristic(String characteristic, Uint8List bytes) {
    final currentValue = _bytesToHex(bytes);

    if (characteristic.toLowerCase() == ThinkRiderVs200Constants.CHARACTERISTIC_UUID_1.toLowerCase()) {
      if (_lastValue1 != null && _lastValue1 != currentValue) {
        // Shift up button was pressed
        actionStreamInternal.add(LogNotification('Shift Up detected: $_lastValue1 -> $currentValue'));
        handleButtonsClickedWithoutLongPressSupport([ThinkRiderVs200Buttons.shiftUp]);
      }
      _lastValue1 = currentValue;
    } else if (characteristic.toLowerCase() == ThinkRiderVs200Constants.CHARACTERISTIC_UUID_2.toLowerCase()) {
      if (_lastValue2 != null && _lastValue2 != currentValue) {
        // Shift down button was pressed
        actionStreamInternal.add(LogNotification('Shift Down detected: $_lastValue2 -> $currentValue'));
        handleButtonsClickedWithoutLongPressSupport([ThinkRiderVs200Buttons.shiftDown]);
      }
      _lastValue2 = currentValue;
    }

    return Future.value();
  }

  String _bytesToHex(List<int> bytes) {
    return bytes.map((byte) => byte.toRadixString(16).padLeft(2, '0')).join();
  }
}

class ThinkRiderVs200Constants {
  // Service and characteristic UUIDs based on the nRF Connect screenshot
  static const String SERVICE_UUID_1 = "0000fea0-0000-1000-8000-00805f9b34fb";
  static const String CHARACTERISTIC_UUID_1 = "0000fea1-0000-1000-8000-00805f9b34fb";

  static const String SERVICE_UUID_2 = "0000fd00-0000-1000-8000-00805f9b34fb";
  static const String CHARACTERISTIC_UUID_2 = "0000fd09-0000-1000-8000-00805f9b34fb";
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
