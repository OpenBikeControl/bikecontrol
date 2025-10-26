import 'dart:typed_data';

import 'package:gamepads/gamepads.dart';
import 'package:swift_control/bluetooth/devices/base_device.dart';
import 'package:swift_control/utils/keymap/buttons.dart';
import 'package:universal_ble/src/models/ble_service.dart';

class Gamepad extends BaseDevice {
  Gamepad(super.scanResult) : super(availableButtons: ControllerButton.values.toList(), isBeta: true);

  @override
  Future<void> handleServices(List<BleService> services) {
    // TODO: implement handleServices
    throw UnimplementedError();
  }

  @override
  Future<void> processCharacteristic(String characteristic, Uint8List bytes) {
    // TODO: implement processCharacteristic
    throw UnimplementedError();
  }

  void processGamepadEvent(GamepadEvent event) {
    print('KEy: ${event.key}');
    switch (event.key) {
      case 'AXIS_HAT_X':
        handleButtonsClicked([ControllerButton.shiftUpLeft]);
      case 'KEYCODE_BUTTON_R1':
        handleButtonsClicked([ControllerButton.shiftUpRight]);
      case 'KEYCODE_BUTTON_L1':
        handleButtonsClicked([ControllerButton.shiftDownLeft]);
    }
    handleButtonsClicked([]);
  }
}
