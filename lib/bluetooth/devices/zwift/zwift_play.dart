import 'package:flutter/foundation.dart';
import 'package:swift_control/bluetooth/devices/zwift/protocol/zwift.pb.dart';
import 'package:swift_control/bluetooth/devices/zwift/zwift_device.dart';
import 'package:swift_control/utils/keymap/buttons.dart';

import '../../ble.dart';

class ZwiftPlay extends ZwiftDevice {
  ZwiftPlay(super.scanResult)
    : super(
        availableButtons: [
          ControllerButton.y,
          ControllerButton.z,
          ControllerButton.a,
          ControllerButton.b,
          ControllerButton.onOffRight,
          ControllerButton.sideButtonRight,
          ControllerButton.paddleRight,
          ControllerButton.navigationUp,
          ControllerButton.navigationLeft,
          ControllerButton.navigationRight,
          ControllerButton.navigationDown,
          ControllerButton.onOffLeft,
          ControllerButton.sideButtonLeft,
          ControllerButton.paddleLeft,
        ],
      );

  @override
  List<int> get startCommand => Constants.RIDE_ON + Constants.RESPONSE_START_PLAY;

  @override
  List<ControllerButton> processClickNotification(Uint8List message) {
    final status = PlayKeyPadStatus.fromBuffer(message);

    return [
      if (status.rightPad == PlayButtonStatus.ON) ...[
        if (status.buttonYUp == PlayButtonStatus.ON) ControllerButton.y,
        if (status.buttonZLeft == PlayButtonStatus.ON) ControllerButton.z,
        if (status.buttonARight == PlayButtonStatus.ON) ControllerButton.a,
        if (status.buttonBDown == PlayButtonStatus.ON) ControllerButton.b,
        if (status.buttonOn == PlayButtonStatus.ON) ControllerButton.onOffRight,
        if (status.buttonShift == PlayButtonStatus.ON) ControllerButton.sideButtonRight,
        if (status.analogLR.abs() == 100) ControllerButton.paddleRight,
      ],
      if (status.rightPad == PlayButtonStatus.OFF) ...[
        if (status.buttonYUp == PlayButtonStatus.ON) ControllerButton.navigationUp,
        if (status.buttonZLeft == PlayButtonStatus.ON) ControllerButton.navigationLeft,
        if (status.buttonARight == PlayButtonStatus.ON) ControllerButton.navigationRight,
        if (status.buttonBDown == PlayButtonStatus.ON) ControllerButton.navigationDown,
        if (status.buttonOn == PlayButtonStatus.ON) ControllerButton.onOffLeft,
        if (status.buttonShift == PlayButtonStatus.ON) ControllerButton.sideButtonLeft,
        if (status.analogLR.abs() == 100) ControllerButton.paddleLeft,
      ],
    ];
  }
}
