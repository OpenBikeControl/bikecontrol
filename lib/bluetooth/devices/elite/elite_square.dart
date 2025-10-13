import 'dart:typed_data';

import 'package:dartx/dartx.dart';
import 'package:swift_control/bluetooth/devices/base_device.dart';
import 'package:swift_control/utils/keymap/buttons.dart';
import 'package:universal_ble/universal_ble.dart';

import '../../messages/notification.dart';

class EliteSquare extends BaseDevice {
  EliteSquare(super.scanResult)
    : super(
        availableButtons: SquareConstants.BUTTON_MAPPING.values.toList(),
        isBeta: true,
      );

  String? _lastValue;

  @override
  Future<void> handleServices(List<BleService> services) async {
    final service = services.firstOrNullWhere((e) => e.uuid == SquareConstants.SERVICE_UUID);
    if (service == null) {
      throw Exception('Service not found: ${SquareConstants.SERVICE_UUID}');
    }
    final characteristic = service.characteristics.firstOrNullWhere(
      (e) => e.uuid == SquareConstants.CHARACTERISTIC_UUID,
    );
    if (characteristic == null) {
      throw Exception('Characteristic not found: ${SquareConstants.CHARACTERISTIC_UUID}');
    }

    await UniversalBle.subscribeNotifications(device.deviceId, service.uuid, characteristic.uuid);
  }

  @override
  Future<void> processCharacteristic(String characteristic, Uint8List bytes) async {
    if (characteristic == SquareConstants.CHARACTERISTIC_UUID) {
      final fullValue = _bytesToHex(bytes);
      final currentValue = _extractButtonCode(fullValue);

      if (_lastValue != null) {
        final currentRelevantPart = fullValue.length >= 19
            ? fullValue.substring(6, fullValue.length - 13)
            : fullValue.substring(6);
        final lastRelevantPart = _lastValue!.length >= 19
            ? _lastValue!.substring(6, _lastValue!.length - 13)
            : _lastValue!.substring(6);

        if (currentRelevantPart != lastRelevantPart) {
          final buttonClicked = SquareConstants.BUTTON_MAPPING[currentValue];
          if (buttonClicked != null) {
            actionStreamInternal.add(LogNotification('Button pressed: $buttonClicked'));
          }
          handleButtonsClicked([
            if (buttonClicked != null) buttonClicked,
          ]);
        }
      }

      _lastValue = fullValue;
    }
  }

  String _extractButtonCode(String hexValue) {
    if (hexValue.length >= 14) {
      final buttonCode = hexValue.substring(6, 14);
      if (SquareConstants.BUTTON_MAPPING.containsKey(buttonCode)) {
        return buttonCode;
      }
    }
    return hexValue;
  }

  String _bytesToHex(List<int> bytes) {
    return bytes.map((byte) => byte.toRadixString(16).padLeft(2, '0')).join();
  }
}

class SquareConstants {
  static const String DEVICE_NAME = "SQUARE";
  static const String CHARACTERISTIC_UUID = "347b0043-7635-408b-8918-8ff3949ce592";
  static const String SERVICE_UUID = "347b0001-7635-408b-8918-8ff3949ce592";
  static const int RECONNECT_DELAY = 5; // seconds between reconnection attempts

  // Button mapping https://images.bike24.com/i/mb/c7/36/d9/elite-square-smart-frame-indoor-bike-3-1724305.jpg
  static const Map<String, ControllerButton> BUTTON_MAPPING = {
    "00000200": ControllerButton.navigationUp, //"Up",
    "00000100": ControllerButton.navigationLeft, //"Left",
    "00000800": ControllerButton.navigationDown, // "Down",
    "00000400": ControllerButton.navigationRight, //"Right",
    "00002000": ControllerButton.powerUpLeft, //"X",
    "00001000": ControllerButton.sideButtonLeft, // "Square",
    "00008000": ControllerButton.campagnoloLeft, // "Left Campagnolo",
    "00004000": ControllerButton.onOffLeft, //"Left brake",
    "00000002": ControllerButton.shiftDownLeft, //"Left shift 1",
    "00000001": ControllerButton.paddleLeft, // "Left shift 2",
    "02000000": ControllerButton.y, // "Y",
    "01000000": ControllerButton.a, //"A",
    "08000000": ControllerButton.b, // "B",
    "04000000": ControllerButton.z, // "Z",
    "20000000": ControllerButton.powerUpRight, // "Circle",
    "10000000": ControllerButton.sideButtonRight, //"Triangle",
    "80000000": ControllerButton.campagnoloRight, // "Right Campagnolo",
    "40000000": ControllerButton.onOffRight, //"Right brake",
    "00020000": ControllerButton.sideButtonRight, //"Right shift 1",
    "00010000": ControllerButton.paddleRight, //"Right shift 2",
  };
}
