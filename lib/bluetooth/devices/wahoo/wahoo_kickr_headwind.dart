import 'package:bike_control/utils/actions/base_actions.dart';
import 'package:flutter/foundation.dart';
import 'package:bike_control/utils/keymap/buttons.dart';
import 'package:bike_control/utils/keymap/keymap.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart' show LucideIcons;
import 'package:universal_ble/universal_ble.dart';

import '../bluetooth_device.dart';

class WahooKickrHeadwind extends BluetoothDevice with Accessory {
  /// The speeds the fan accepts in manual mode, in percent.
  static const allowedSpeeds = [0, 25, 50, 75, 100];

  /// What the fan reports (or was last told) it is doing — the page's direct
  /// controls render from these.
  final ValueNotifier<HeadwindMode> mode = ValueNotifier(HeadwindMode.unknown);
  final ValueNotifier<int> speed = ValueNotifier(0);

  HeadwindMode get _currentMode => mode.value;
  set _currentMode(HeadwindMode value) => mode.value = value;
  int get _currentSpeed => speed.value;
  set _currentSpeed(int value) => speed.value = value;

  /// Captures writes in tests instead of sending them over BLE.
  @visibleForTesting
  Future<void> Function(Uint8List bytes)? debugWriteSink;

  Future<void> _write(Uint8List data) {
    final sink = debugWriteSink;
    if (sink != null) return sink(data);
    return UniversalBle.write(
      device.deviceId,
      WahooKickrHeadwindConstants.SERVICE_UUID.toLowerCase(),
      WahooKickrHeadwindConstants.CHARACTERISTIC_UUID.toLowerCase(),
      data,
      withoutResponse: true,
    );
  }

  WahooKickrHeadwind(super.scanResult)
    : super(
        availableButtons: const [],
        icon: LucideIcons.fan,
        isBeta: true,
      );

  @override
  List<InGameAction> get assignableActions => const [
    InGameAction.headwindSpeed,
    InGameAction.headwindSpeedInc,
    InGameAction.headwindSpeedDec,
    InGameAction.headwindSpeedCyclicInc,
    InGameAction.headwindSpeedCyclicDec,
    InGameAction.headwindHeartRateMode,
  ];

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
    if (!allowedSpeeds.contains(speedPercent)) {
      throw ArgumentError('Speed must be one of: ${allowedSpeeds.join(", ")}');
    }

    // Check if manual mode is enabled, if not enable it first
    if (_currentMode != HeadwindMode.manual) {
      await _write(Uint8List.fromList([0x04, 0x04]));
      _currentMode = HeadwindMode.manual;

      // Small delay to ensure mode change is processed before speed command
      if (debugWriteSink == null) await Future.delayed(const Duration(milliseconds: 100));
    }

    // Command format: [0x02, speed_value]
    // Speed value: 0x00 to 0x64 (0-100 in hex)
    await _write(Uint8List.fromList([0x02, speedPercent]));
    _currentSpeed = speedPercent;
  }

  Future<void> setHeartRateMode() async {
    // Command format: [0x04, 0x02] for HR mode
    await _write(Uint8List.fromList([0x04, 0x02]));
    _currentMode = HeadwindMode.heartRate;
  }

  Future<ActionResult> handleKeypair(KeyPair keyPair, {required bool isKeyDown}) async {
    if (!isKeyDown) {
      return NotHandled(
        '',
        button: keyPair.buttons.firstOrNull,
      );
    }

    try {
      if (keyPair.inGameAction == InGameAction.headwindSpeed) {
        final speed = keyPair.inGameActionValue ?? 0;
        await setSpeed(speed);
        return Success(
          'Headwind speed set to $speed%',
          button: keyPair.buttons.firstOrNull,
        );
      } else if (keyPair.inGameAction == InGameAction.headwindSpeedInc ||
          keyPair.inGameAction == InGameAction.headwindSpeedDec ||
          keyPair.inGameAction == InGameAction.headwindSpeedCyclicInc ||
          keyPair.inGameAction == InGameAction.headwindSpeedCyclicDec) {
        final step = 25;
        int speed = 0;
        switch (keyPair.inGameAction) {
          case InGameAction.headwindSpeedInc:
            speed = _currentSpeed + step > 100 ? 100 : _currentSpeed + step;
          case InGameAction.headwindSpeedDec:
            speed = _currentSpeed - step < 0 ? 0 : _currentSpeed - step;
          case InGameAction.headwindSpeedCyclicInc:
            speed = _currentSpeed + step > 100 ? (_currentSpeed < 100 ? 100 : 0) : _currentSpeed + step;
          case InGameAction.headwindSpeedCyclicDec:
            speed = _currentSpeed - step < 0 ? (_currentSpeed > 0 ? 0 : 100) : _currentSpeed - step;
          default:
            return Error(
              'Failed to control Headwind: Unknown action',
              button: keyPair.buttons.firstOrNull,
            );
        }
        await setSpeed(speed);
        _currentSpeed = speed;
        return Success(
          'Headwind speed set to $speed%',
          button: keyPair.buttons.firstOrNull,
        );
      } else if (keyPair.inGameAction == InGameAction.headwindHeartRateMode) {
        await setHeartRateMode();
        return Success(
          'Headwind set to Heart Rate mode',
          button: keyPair.buttons.firstOrNull,
        );
      }
    } catch (e) {
      return Error(
        'Failed to control Headwind: $e',
        button: keyPair.buttons.firstOrNull,
      );
    }

    return NotHandled(
      '',
      button: keyPair.buttons.firstOrNull,
    );
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
