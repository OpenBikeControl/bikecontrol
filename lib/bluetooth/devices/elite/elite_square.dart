import 'dart:typed_data';

import 'package:dartx/dartx.dart';
import 'package:swift_control/utils/keymap/buttons.dart';
import 'package:universal_ble/universal_ble.dart';

import '../../messages/notification.dart';
import '../bluetooth_device.dart';

class EliteSquare extends BluetoothDevice {
  EliteSquare(super.scanResult)
    : super(
        availableButtons: EliteSquareButtons.values.toList(),
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
      actionStreamInternal.add(LogNotification('Received $fullValue - vs $currentValue (last: $_lastValue)'));

      if (_lastValue != null) {
        final currentRelevantPart = fullValue.length >= 14
            ? fullValue.substring(6, 14)
            : fullValue.substring(6);
        final lastRelevantPart = _lastValue!.length >= 14
            ? _lastValue!.substring(6, 14)
            : _lastValue!.substring(6);

        if (currentRelevantPart != lastRelevantPart) {
          final buttonClicked = SquareConstants.BUTTON_MAPPING[currentValue];
          actionStreamInternal.add(LogNotification('Button pressed: $buttonClicked'));
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
    "00000200": EliteSquareButtons.up, //"Up",
    "00000100": EliteSquareButtons.left, //"Left",
    "00000800": EliteSquareButtons.down, // "Down",
    "00000400": EliteSquareButtons.right, //"Right",
    "00002000": EliteSquareButtons.x, //"X",
    "00001000": EliteSquareButtons.square, // "Square",
    "00008000": EliteSquareButtons.campagnoloLeft, // "Left Campagnolo",
    "00004000": EliteSquareButtons.leftBrake, //"Left brake",
    "00000002": EliteSquareButtons.leftShift1, //"Left shift 1",
    "00000001": EliteSquareButtons.leftShift2, // "Left shift 2",
    "02000000": EliteSquareButtons.y, // "Y",
    "01000000": EliteSquareButtons.a, //"A",
    "08000000": EliteSquareButtons.b, // "B",
    "04000000": EliteSquareButtons.z, // "Z",
    "20000000": EliteSquareButtons.circle, // "Circle",
    "10000000": EliteSquareButtons.triangle, //"Triangle",
    "80000000": EliteSquareButtons.campagnoloRight, // "Right Campagnolo",
    "40000000": EliteSquareButtons.rightBrake, //"Right brake",
    "00020000": EliteSquareButtons.rightShift1, //"Right shift 1",
    "00010000": EliteSquareButtons.rightShift2, //"Right shift 2",
  };
}

class EliteSquareButtons {
  static const ControllerButton up = ControllerButton('eliteSquareUp', action: null);
  static const ControllerButton left = ControllerButton('eliteSquareLeft', action: InGameAction.navigateLeft);
  static const ControllerButton down = ControllerButton('eliteSquareDown', action: null);
  static const ControllerButton right = ControllerButton('eliteSquareRight', action: InGameAction.navigateRight);
  static const ControllerButton x = ControllerButton('eliteSquareX', action: null);
  static const ControllerButton square = ControllerButton('eliteSquareSquare', action: null);
  static const ControllerButton campagnoloLeft = ControllerButton('eliteSquareCampagnoloLeft', action: null);
  static const ControllerButton leftBrake = ControllerButton('eliteSquareLeftBrake', action: null);
  static const ControllerButton leftShift1 = ControllerButton('eliteSquareLeftShift1', action: InGameAction.shiftUp);
  static const ControllerButton leftShift2 = ControllerButton('eliteSquareLeftShift2', action: InGameAction.shiftDown);
  static const ControllerButton y = ControllerButton('y', action: null);
  static const ControllerButton a = ControllerButton('a', action: null);
  static const ControllerButton b = ControllerButton('b', action: null);
  static const ControllerButton z = ControllerButton('z', action: null);
  static const ControllerButton circle = ControllerButton('eliteSquareCircle', action: null);
  static const ControllerButton triangle = ControllerButton('eliteSquareTriangle', action: null);
  static const ControllerButton campagnoloRight = ControllerButton('eliteSquareCampagnoloRight', action: null);
  static const ControllerButton rightBrake = ControllerButton('eliteSquareRightBrake', action: null);
  static const ControllerButton rightShift1 = ControllerButton('eliteSquareRightShift1', action: InGameAction.shiftUp);
  static const ControllerButton rightShift2 = ControllerButton(
    'eliteSquareRightShift2',
    action: InGameAction.shiftDown,
  );

  static const List<ControllerButton> values = [
    up,
    left,
    down,
    right,
    x,
    square,
    campagnoloLeft,
    leftBrake,
    leftShift1,
    leftShift2,
    y,
    a,
    b,
    z,
    circle,
    triangle,
    campagnoloRight,
    rightBrake,
    rightShift1,
    rightShift2,
  ];
}
