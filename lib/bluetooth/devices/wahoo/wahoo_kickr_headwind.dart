import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:swift_control/utils/keymap/buttons.dart';
import 'package:universal_ble/universal_ble.dart';

import '../bluetooth_device.dart';

class WahooKickrHeadwind extends BluetoothDevice {
  WahooKickrHeadwind(super.scanResult)
    : super(
        availableButtons: WahooKickrHeadwindButtons.values,
      );

  @override
  Future<void> handleServices(List<BleService> services) async {
    final service = services.firstWhere(
      (e) => e.uuid == WahooKickrHeadwindConstants.SERVICE_UUID.toLowerCase(),
      orElse: () => throw Exception('Service not found: ${WahooKickrHeadwindConstants.SERVICE_UUID}'),
    );
    final characteristic = service.characteristics.firstWhere(
      (e) => e.uuid == WahooKickrHeadwindConstants.CHARACTERISTIC_UUID.toLowerCase(),
      orElse: () => throw Exception('Characteristic not found: ${WahooKickrHeadwindConstants.CHARACTERISTIC_UUID}'),
    );

    // Subscribe to notifications for status updates
    await UniversalBle.subscribeNotifications(device.deviceId, service.uuid, characteristic.uuid);
  }

  @override
  Future<void> processCharacteristic(String characteristic, Uint8List bytes) {
    // Handle status updates if needed
    return Future.value();
  }

  Future<void> setSpeed(int speedPercent) async {
    if (speedPercent < 0 || speedPercent > 100) {
      throw ArgumentError('Speed must be between 0 and 100');
    }

    final service = WahooKickrHeadwindConstants.SERVICE_UUID.toLowerCase();
    final characteristic = WahooKickrHeadwindConstants.CHARACTERISTIC_UUID.toLowerCase();

    // Command format: [0x01, speed_value]
    // Speed value: 0-100 (percentage)
    final data = Uint8List.fromList([0x01, speedPercent]);

    await UniversalBle.write(
      device.deviceId,
      service,
      characteristic,
      data,
    );
  }

  Future<void> setHeartRateMode() async {
    final service = WahooKickrHeadwindConstants.SERVICE_UUID.toLowerCase();
    final characteristic = WahooKickrHeadwindConstants.CHARACTERISTIC_UUID.toLowerCase();

    // Command format: [0x02] for HR mode
    final data = Uint8List.fromList([0x02]);

    await UniversalBle.write(
      device.deviceId,
      service,
      characteristic,
      data,
    );
  }
}

class WahooKickrHeadwindConstants {
  // Wahoo KICKR Headwind service and characteristic UUIDs
  // These are standard Wahoo fitness equipment UUIDs
  static const String SERVICE_UUID = "A026E005-0A7D-4AB3-97FA-F1500F9FEB8B";
  static const String CHARACTERISTIC_UUID = "A026E038-0A7D-4AB3-97FA-F1500F9FEB8B";
}

class WahooKickrHeadwindButtons {
  static const ControllerButton speed0 = ControllerButton(
    'speed0',
    icon: Icons.air,
    color: Colors.grey,
  );
  static const ControllerButton speed25 = ControllerButton(
    'speed25',
    icon: Icons.air,
    color: Colors.blue,
  );
  static const ControllerButton speed50 = ControllerButton(
    'speed50',
    icon: Icons.air,
    color: Colors.blue,
  );
  static const ControllerButton speed75 = ControllerButton(
    'speed75',
    icon: Icons.air,
    color: Colors.blue,
  );
  static const ControllerButton speed100 = ControllerButton(
    'speed100',
    icon: Icons.air,
    color: Colors.blue,
  );
  static const ControllerButton heartRateMode = ControllerButton(
    'heartRateMode',
    icon: Icons.favorite,
    color: Colors.red,
  );

  static const List<ControllerButton> values = [
    speed0,
    speed25,
    speed50,
    speed75,
    speed100,
    heartRateMode,
  ];
}
