import 'dart:typed_data';

import 'package:dartx/dartx.dart';
import 'package:swift_control/bluetooth/messages/notification.dart';
import 'package:swift_control/bluetooth/protocol/zwift.pb.dart';
import 'package:swift_control/utils/keymap/buttons.dart';

enum _RideButtonMask {
  LEFT_BTN(0x00001),
  UP_BTN(0x00002),
  RIGHT_BTN(0x00004),
  DOWN_BTN(0x00008),

  A_BTN(0x00010),
  B_BTN(0x00020),
  Y_BTN(0x00040),
  Z_BTN(0x00080),

  SHFT_UP_L_BTN(0x00100),
  SHFT_DN_L_BTN(0x00200),
  SHFT_UP_R_BTN(0x01000),
  SHFT_DN_R_BTN(0x02000),

  POWERUP_L_BTN(0x00400),
  POWERUP_R_BTN(0x04000),
  ONOFF_L_BTN(0x00800),
  ONOFF_R_BTN(0x08000);

  final int mask;

  const _RideButtonMask(this.mask);
}

class RideNotification extends BaseNotification {
  late List<ZwiftButton> buttonsClicked;

  RideNotification(Uint8List message) {
    final status = RideKeyPadStatus.fromBuffer(message);

    buttonsClicked = [
      if (status.buttonMap & _RideButtonMask.LEFT_BTN.mask == PlayButtonStatus.ON.value) ZwiftButton.navigationLeft,
      if (status.buttonMap & _RideButtonMask.RIGHT_BTN.mask == PlayButtonStatus.ON.value) ZwiftButton.navigationRight,
      if (status.buttonMap & _RideButtonMask.UP_BTN.mask == PlayButtonStatus.ON.value) ZwiftButton.navigationUp,
      if (status.buttonMap & _RideButtonMask.DOWN_BTN.mask == PlayButtonStatus.ON.value) ZwiftButton.navigationDown,
      if (status.buttonMap & _RideButtonMask.A_BTN.mask == PlayButtonStatus.ON.value) ZwiftButton.a,
      if (status.buttonMap & _RideButtonMask.B_BTN.mask == PlayButtonStatus.ON.value) ZwiftButton.b,
      if (status.buttonMap & _RideButtonMask.Y_BTN.mask == PlayButtonStatus.ON.value) ZwiftButton.y,
      if (status.buttonMap & _RideButtonMask.Z_BTN.mask == PlayButtonStatus.ON.value) ZwiftButton.z,
      if (status.buttonMap & _RideButtonMask.SHFT_UP_L_BTN.mask == PlayButtonStatus.ON.value) ZwiftButton.shiftUpLeft,
      if (status.buttonMap & _RideButtonMask.SHFT_DN_L_BTN.mask == PlayButtonStatus.ON.value) ZwiftButton.shiftDownLeft,
      if (status.buttonMap & _RideButtonMask.SHFT_UP_R_BTN.mask == PlayButtonStatus.ON.value) ZwiftButton.shiftUpRight,
      if (status.buttonMap & _RideButtonMask.SHFT_DN_R_BTN.mask == PlayButtonStatus.ON.value)
        ZwiftButton.shiftDownRight,
      if (status.buttonMap & _RideButtonMask.POWERUP_L_BTN.mask == PlayButtonStatus.ON.value) ZwiftButton.powerUpLeft,
      if (status.buttonMap & _RideButtonMask.POWERUP_R_BTN.mask == PlayButtonStatus.ON.value) ZwiftButton.powerUpRight,
      if (status.buttonMap & _RideButtonMask.ONOFF_L_BTN.mask == PlayButtonStatus.ON.value) ZwiftButton.onOffLeft,
      if (status.buttonMap & _RideButtonMask.ONOFF_R_BTN.mask == PlayButtonStatus.ON.value) ZwiftButton.onOffRight,
    ];

    for (final analogue in status.analogButtons.groupStatus) {
      if (analogue.analogValue.abs() == 100) {
        if (analogue.location == RideAnalogLocation.LEFT) {
          buttonsClicked.add(ZwiftButton.paddleLeft);
        } else if (analogue.location == RideAnalogLocation.RIGHT) {
          buttonsClicked.add(ZwiftButton.paddleRight);
        } else if (analogue.location == RideAnalogLocation.DOWN || analogue.location == RideAnalogLocation.UP) {
          // TODO what is this even?
        }
      }
    }
  }

  @override
  String toString() {
    return 'Buttons: ${buttonsClicked.joinToString(transform: (e) => e.name)}';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RideNotification &&
          runtimeType == other.runtimeType &&
          buttonsClicked.contentEquals(other.buttonsClicked);

  @override
  int get hashCode => buttonsClicked.hashCode;
}
