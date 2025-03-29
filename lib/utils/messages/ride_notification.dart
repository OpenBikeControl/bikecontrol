import 'dart:typed_data';

import 'package:swift_control/utils/messages/notification.dart';

import '../../protocol/zwift.pb.dart';

enum _RideButtonMask {
  LEFT_BTN(0x00001),
  UP_BTN(0x00002),
  RIGHT_BTN(0x00004),
  DOWN_BTN(0x00008),
  A_BTN(0x00010),
  B_BTN(0x00020),
  Y_BTN(0x00040),

  Z_BTN(0x00100),
  SHFT_UP_L_BTN(0x00200),
  SHFT_DN_L_BTN(0x00400),
  POWERUP_L_BTN(0x00800),
  ONOFF_L_BTN(0x01000),
  SHFT_UP_R_BTN(0x02000),
  SHFT_DN_R_BTN(0x04000),

  POWERUP_R_BTN(0x10000),
  ONOFF_R_BTN(0x20000);

  final int mask;

  const _RideButtonMask(this.mask);
}

class RideNotification extends BaseNotification {
  static const int BTN_PRESSED = 0;

  late bool buttonLeft, buttonRight, buttonUp, buttonDown;
  late bool buttonA, buttonB, buttonY, buttonZ;
  late bool buttonShiftUpLeft, buttonShiftDownLeft;
  late bool buttonShiftUpRight, buttonShiftDownRight;
  late bool buttonPowerUpLeft, buttonPowerDownLeft;
  late bool buttonOnOffLeft, buttonOnOffRight;

  late int analogLR, analogUD;

  RideNotification(Uint8List message) {
    final status = RideKeyPadStatus.fromBuffer(message);

    buttonLeft = status.buttonMap & _RideButtonMask.LEFT_BTN.mask == BTN_PRESSED;
    buttonRight = status.buttonMap & _RideButtonMask.RIGHT_BTN.mask == BTN_PRESSED;
    buttonUp = status.buttonMap & _RideButtonMask.UP_BTN.mask == BTN_PRESSED;
    buttonDown = status.buttonMap & _RideButtonMask.DOWN_BTN.mask == BTN_PRESSED;
    buttonA = status.buttonMap & _RideButtonMask.A_BTN.mask == BTN_PRESSED;
    buttonB = status.buttonMap & _RideButtonMask.B_BTN.mask == BTN_PRESSED;
    buttonY = status.buttonMap & _RideButtonMask.Y_BTN.mask == BTN_PRESSED;
    buttonZ = status.buttonMap & _RideButtonMask.Z_BTN.mask == BTN_PRESSED;
    buttonShiftUpLeft = status.buttonMap & _RideButtonMask.SHFT_UP_L_BTN.mask == BTN_PRESSED;
    buttonShiftDownLeft = status.buttonMap & _RideButtonMask.SHFT_DN_L_BTN.mask == BTN_PRESSED;
    buttonShiftUpRight = status.buttonMap & _RideButtonMask.SHFT_UP_R_BTN.mask == BTN_PRESSED;
    buttonShiftDownRight = status.buttonMap & _RideButtonMask.SHFT_DN_R_BTN.mask == BTN_PRESSED;
    buttonPowerUpLeft = status.buttonMap & _RideButtonMask.POWERUP_L_BTN.mask == BTN_PRESSED;
    buttonPowerDownLeft = status.buttonMap & _RideButtonMask.POWERUP_R_BTN.mask == BTN_PRESSED;
    buttonOnOffLeft = status.buttonMap & _RideButtonMask.ONOFF_L_BTN.mask == BTN_PRESSED;
    buttonOnOffRight = status.buttonMap & _RideButtonMask.ONOFF_R_BTN.mask == BTN_PRESSED;

    for (final analogue in status.analogButtons.groupStatus) {
      if (analogue.location == RideAnalogLocation.LEFT) {
        analogLR = analogue.analogValue;
      } else if (analogue.location == RideAnalogLocation.DOWN) {
        analogUD = analogue.analogValue;
      }
    }
  }

  @override
  String toString() {
    final allTrueParameters = [
      if (buttonLeft) 'buttonLeft',
      if (buttonRight) 'buttonRight',
      if (buttonUp) 'buttonUp',
      if (buttonDown) 'buttonDown',
      if (buttonA) 'buttonA',
      if (buttonB) 'buttonB',
      if (buttonY) 'buttonY',
      if (buttonZ) 'buttonZ',
      if (buttonShiftUpLeft) 'buttonShiftUpLeft',
      if (buttonShiftDownLeft) 'buttonShiftDownLeft',
      if (buttonShiftUpRight) 'buttonShiftUpRight',
      if (buttonShiftDownRight) 'buttonShiftDownRight',
      if (buttonPowerUpLeft) 'buttonPowerUpLeft',
      if (buttonPowerDownLeft) 'buttonPowerDownLeft',
      if (buttonOnOffLeft) 'buttonOnOffLeft',
      if (buttonOnOffRight) 'buttonOnOffRight',
    ];
    return '{$allTrueParameters, analogLR: $analogLR, analogUD: $analogUD}';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RideNotification &&
          runtimeType == other.runtimeType &&
          buttonLeft == other.buttonLeft &&
          buttonRight == other.buttonRight &&
          buttonUp == other.buttonUp &&
          buttonDown == other.buttonDown &&
          buttonA == other.buttonA &&
          buttonB == other.buttonB &&
          buttonY == other.buttonY &&
          buttonZ == other.buttonZ &&
          buttonShiftUpLeft == other.buttonShiftUpLeft &&
          buttonShiftDownLeft == other.buttonShiftDownLeft &&
          buttonShiftUpRight == other.buttonShiftUpRight &&
          buttonShiftDownRight == other.buttonShiftDownRight &&
          buttonPowerUpLeft == other.buttonPowerUpLeft &&
          buttonPowerDownLeft == other.buttonPowerDownLeft &&
          buttonOnOffLeft == other.buttonOnOffLeft &&
          buttonOnOffRight == other.buttonOnOffRight &&
          analogLR == other.analogLR &&
          analogUD == other.analogUD;

  @override
  int get hashCode =>
      buttonLeft.hashCode ^
      buttonRight.hashCode ^
      buttonUp.hashCode ^
      buttonDown.hashCode ^
      buttonA.hashCode ^
      buttonB.hashCode ^
      buttonY.hashCode ^
      buttonZ.hashCode ^
      buttonShiftUpLeft.hashCode ^
      buttonShiftDownLeft.hashCode ^
      buttonShiftUpRight.hashCode ^
      buttonShiftDownRight.hashCode ^
      buttonPowerUpLeft.hashCode ^
      buttonPowerDownLeft.hashCode ^
      buttonOnOffLeft.hashCode ^
      buttonOnOffRight.hashCode ^
      analogLR.hashCode ^
      analogUD.hashCode;
}
