import 'package:bike_control/bluetooth/devices/zwift/zwift_device.dart';
import 'package:bike_control/utils/keymap/buttons.dart';
import 'package:bike_control/widgets/controller/controller_layout.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:prop/prop.dart';

import 'constants.dart';

class ZwiftClick extends ZwiftDevice {
  ZwiftClick(super.scanResult) : super(availableButtons: [ZwiftButtons.shiftUpRight, ZwiftButtons.shiftUpLeft]);

  @override
  List<ControllerButton> processClickNotification(Uint8List message) {
    final status = ClickKeyPadStatus.fromBuffer(message);
    final buttonsClicked = [
      if (status.buttonPlus == PlayButtonStatus.ON) ZwiftButtons.shiftUpRight,
      if (status.buttonMinus == PlayButtonStatus.ON) ZwiftButtons.shiftUpLeft,
    ];
    return buttonsClicked;
  }

  @override
  String get latestFirmwareVersion => '1.1.0';

  @override
  ControllerLayout get controllerLayout => ControllerLayout(
    aspectRatio: 1.4,
    shape: ContourShape.pill,
    positions: {
      ZwiftButtons.shiftUpLeft: const Offset(0.3, 0.5),
      ZwiftButtons.shiftUpRight: const Offset(0.7, 0.5),
    },
  );
}
