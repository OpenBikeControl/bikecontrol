import 'package:flutter/foundation.dart';
import 'package:swift_control/bluetooth/devices/zwift/protocol/zwift.pb.dart';
import 'package:swift_control/bluetooth/devices/zwift/zwift_device.dart';
import 'package:swift_control/utils/keymap/buttons.dart';

class ZwiftClick extends ZwiftDevice {
  ZwiftClick(super.scanResult)
    : super(availableButtons: [ControllerButton.shiftUpRight, ControllerButton.shiftDownLeft]);

  @override
  List<ControllerButton> processClickNotification(Uint8List message) {
    final status = ClickKeyPadStatus.fromBuffer(message);
    final buttonsClicked = [
      if (status.buttonPlus == PlayButtonStatus.ON) ControllerButton.shiftUpRight,
      if (status.buttonMinus == PlayButtonStatus.ON) ControllerButton.shiftDownLeft,
    ];
    return buttonsClicked;
  }
}
