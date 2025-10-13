import 'dart:typed_data';

import 'package:dartx/dartx.dart';
import 'package:swift_control/bluetooth/messages/notification.dart';
import 'package:swift_control/bluetooth/protocol/zwift.pb.dart';
import 'package:swift_control/utils/keymap/buttons.dart';
import 'package:swift_control/widgets/keymap_explanation.dart';

class PlayNotification extends BaseNotification {
  late List<ControllerButton> buttonsClicked;

  PlayNotification(Uint8List message) {
    final status = PlayKeyPadStatus.fromBuffer(message);

    buttonsClicked = [
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

  @override
  String toString() {
    return 'Buttons: ${buttonsClicked.joinToString(transform: (e) => e.name.splitByUpperCase())}';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PlayNotification &&
          runtimeType == other.runtimeType &&
          buttonsClicked.contentEquals(other.buttonsClicked);

  @override
  int get hashCode => buttonsClicked.hashCode;
}
