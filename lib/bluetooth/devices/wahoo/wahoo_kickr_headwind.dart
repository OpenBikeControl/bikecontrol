import 'dart:typed_data';

import 'package:bike_control/utils/actions/base_actions.dart';
import 'package:bike_control/utils/keymap/buttons.dart';
import 'package:bike_control/utils/keymap/keymap.dart';
import 'package:universal_ble/universal_ble.dart';

import '../bluetooth_device.dart';

class WahooKickrHeadwind extends BluetoothDevice {
  // Current mode state
  HeadwindMode _currentMode = HeadwindMode.unknown;
  int _currentSpeed = 0;

  WahooKickrHeadwind(super.scanResult)
    : super(
        availableButtons: const [],
        isBeta: true,
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
    // Analyze the received bytes to determine current state
    if (bytes.length >= 4 && bytes[0] == 0xFD && bytes[1] == 0x01) {
      final mode = bytes[3];
      final speed = bytes[2];

      switch (mode) {
        case 0x02:
          _currentMode = HeadwindMode.heartRate;
          break;
        case 0x03:
          _currentMode = HeadwindMode.speed;
          break;
        case 0x01:
          _currentMode = HeadwindMode.off;
          break;
        case 0x04:
          _currentMode = HeadwindMode.manual;
          _currentSpeed = speed;
          break;
      }
    }
    return Future.value();
  }

  Future<void> setSpeed(int speedPercent) async {
    // Validate against the allowed speed values
    const allowedSpeeds = [0, 25, 50, 75, 100];
    if (!allowedSpeeds.contains(speedPercent)) {
      throw ArgumentError('Speed must be one of: ${allowedSpeeds.join(", ")}');
    }

    final service = WahooKickrHeadwindConstants.SERVICE_UUID.toLowerCase();
    final characteristic = WahooKickrHeadwindConstants.CHARACTERISTIC_UUID.toLowerCase();

    // Check if manual mode is enabled, if not enable it first
    if (_currentMode != HeadwindMode.manual) {
      final manualModeData = Uint8List.fromList([0x04, 0x04]);
      await UniversalBle.write(
        device.deviceId,
        service,
        characteristic,
        manualModeData,
        withoutResponse: true,
      );
      _currentMode = HeadwindMode.manual;

      // Small delay to ensure mode change is processed before speed command
      await Future.delayed(const Duration(milliseconds: 100));
    }

    // Command format: [0x02, speed_value]
    // Speed value: 0x00 to 0x64 (0-100 in hex)
    final data = Uint8List.fromList([0x02, speedPercent]);

    await UniversalBle.write(
      device.deviceId,
      service,
      characteristic,
      data,
      withoutResponse: true,
    );
    _currentSpeed = speedPercent;
  }

  Future<void> setHeartRateMode() async {
    final service = WahooKickrHeadwindConstants.SERVICE_UUID.toLowerCase();
    final characteristic = WahooKickrHeadwindConstants.CHARACTERISTIC_UUID.toLowerCase();

    // Command format: [0x04, 0x02] for HR mode
    final data = Uint8List.fromList([0x04, 0x02]);

    await UniversalBle.write(
      device.deviceId,
      service,
      characteristic,
      data,
      withoutResponse: true,
    );
    _currentMode = HeadwindMode.heartRate;
  }

  Future<ActionResult> handleKeypair(KeyPair keyPair, {required bool isKeyDown}) async {
    if (!isKeyDown) {
      return NotHandled('');
    }

    try {
      if (keyPair.inGameAction == InGameAction.headwindSpeed) {
        final speed = keyPair.inGameActionValue ?? 0;
        await setSpeed(speed);
        return Success('Headwind speed set to $speed%');
      } else if (keyPair.inGameAction == InGameAction.headwindHeartRateMode) {
        await setHeartRateMode();
        return Success('Headwind set to Heart Rate mode');
      }
    } catch (e) {
      return Error('Failed to control Headwind: $e');
    }

    return NotHandled('');
  }
}

class WahooKickrHeadwindConstants {
  // Wahoo KICKR Headwind service and characteristic UUIDs
  // These are standard Wahoo fitness equipment UUIDs
  static const String SERVICE_UUID = "A026EE0C-0A7D-4AB3-97FA-F1500F9FEB8B";
  static const String CHARACTERISTIC_UUID = "A026E038-0A7D-4AB3-97FA-F1500F9FEB8B";
}

enum HeadwindMode {
  unknown,
  heartRate, // HR mode (0x02)
  speed, // Speed mode (0x03)
  off, // OFF mode (0x01)
  manual, // Manual speed mode (0x04)
}
