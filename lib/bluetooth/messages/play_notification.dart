import 'dart:typed_data';

import 'package:dartx/dartx.dart';
import 'package:swift_control/bluetooth/messages/notification.dart';
import 'package:swift_control/bluetooth/protocol/zwift.pb.dart';
import 'package:swift_control/utils/keymap/buttons.dart';

class PlayNotification extends BaseNotification {
  late List<ZwiftButton> buttonsClicked;

  PlayNotification(Uint8List message) {
    final status = PlayKeyPadStatus.fromBuffer(message);

    buttonsClicked = [
      if (status.rightPad == PlayButtonStatus.ON) ...[
        if (status.buttonYUp == PlayButtonStatus.ON) ZwiftButton.y,
        if (status.buttonZLeft == PlayButtonStatus.ON) ZwiftButton.z,
        if (status.buttonARight == PlayButtonStatus.ON) ZwiftButton.a,
        if (status.buttonBDown == PlayButtonStatus.ON) ZwiftButton.b,
        if (status.buttonOn == PlayButtonStatus.ON) ZwiftButton.onOffRight,
        if (status.buttonShift == PlayButtonStatus.ON) ZwiftButton.sideButtonRight,
        if (status.analogLR.abs() == 100) ZwiftButton.paddleRight,
      ],
      if (status.rightPad == PlayButtonStatus.OFF) ...[
        if (status.buttonYUp == PlayButtonStatus.ON) ZwiftButton.navigationUp,
        if (status.buttonZLeft == PlayButtonStatus.ON) ZwiftButton.navigationLeft,
        if (status.buttonARight == PlayButtonStatus.ON) ZwiftButton.navigationRight,
        if (status.buttonBDown == PlayButtonStatus.ON) ZwiftButton.navigationDown,
        if (status.buttonOn == PlayButtonStatus.ON) ZwiftButton.onOffLeft,
        if (status.buttonShift == PlayButtonStatus.ON) ZwiftButton.sideButtonLeft,
        if (status.analogLR.abs() == 100) ZwiftButton.paddleLeft,
      ],
    ];
  }

  @override
  String toString() {
    return 'Buttons: ${buttonsClicked.joinToString(transform: (e) => e.name)}';
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
