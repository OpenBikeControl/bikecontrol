import 'package:flutter/material.dart';
import 'package:gamepads/gamepads.dart';
import 'package:swift_control/bluetooth/devices/base_device.dart';
import 'package:swift_control/utils/keymap/buttons.dart';

class GamepadDevice extends BaseDevice {
  final String id;

  GamepadDevice(super.name, {required this.id})
    : super(availableButtons: ControllerButton.values.toList(), isBeta: true);

  void processGamepadEvent(GamepadEvent event) {
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

  @override
  Future<void> connect() async {}

  @override
  Widget showInformation(BuildContext context) {
    return Row(
      children: [],
    );
  }
}
