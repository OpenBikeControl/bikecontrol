import 'dart:typed_data';

import 'package:swift_control/utils/actions/base_actions.dart';
import 'package:swift_control/utils/keymap/buttons.dart';
import 'package:swift_control/utils/keymap/keymap.dart';
import 'package:universal_ble/universal_ble.dart';

import '../bluetooth_device.dart';

class WahooKickrHeadwind extends BluetoothDevice {
  WahooKickrHeadwind(super.scanResult)
    : super(
        availableButtons: const [],
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
    // Validate against the allowed speed values
    const allowedSpeeds = [0, 25, 50, 75, 100];
    if (!allowedSpeeds.contains(speedPercent)) {
      throw ArgumentError('Speed must be one of: ${allowedSpeeds.join(", ")}');
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
  static const String SERVICE_UUID = "A026E005-0A7D-4AB3-97FA-F1500F9FEB8B";
  static const String CHARACTERISTIC_UUID = "A026E038-0A7D-4AB3-97FA-F1500F9FEB8B";
}
