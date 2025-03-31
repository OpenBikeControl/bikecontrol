import 'dart:typed_data';

import 'package:swift_control/bluetooth/messages/notification.dart';
import 'package:swift_control/bluetooth/protocol/zwift.pb.dart';

class PlayNotification extends BaseNotification {
  late bool rightPad, buttonY, buttonZ, buttonA, buttonB, buttonOn, buttonShift;
  late int analogLR, analogUD;

  PlayNotification(Uint8List message) {
    final status = PlayKeyPadStatus.fromBuffer(message);

    rightPad = status.rightPad == PlayButtonStatus.ON;
    buttonY = status.buttonYUp == PlayButtonStatus.ON;
    buttonZ = status.buttonZLeft == PlayButtonStatus.ON;
    buttonA = status.buttonARight == PlayButtonStatus.ON;
    buttonB = status.buttonBDown == PlayButtonStatus.ON;
    buttonOn = status.buttonOn == PlayButtonStatus.ON;
    buttonShift = status.buttonShift == PlayButtonStatus.ON;
    analogLR = status.analogLR;
    analogUD = status.analogUD;
  }

  @override
  String toString() {
    final allTrueParameters = [
      //if (rightPad) 'rightPad',
      if (buttonY) 'buttonY',
      if (buttonZ) 'buttonZ',
      if (buttonA) 'buttonA',
      if (buttonB) 'buttonB',
      if (buttonOn) 'buttonOn',
      if (buttonShift) 'buttonShift',
    ];
    return '${rightPad ? 'Right' : 'Left'}: {$allTrueParameters, analogLR: $analogLR, analogUD: $analogUD}';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PlayNotification &&
          runtimeType == other.runtimeType &&
          rightPad == other.rightPad &&
          buttonY == other.buttonY &&
          buttonZ == other.buttonZ &&
          buttonA == other.buttonA &&
          buttonB == other.buttonB &&
          buttonOn == other.buttonOn &&
          buttonShift == other.buttonShift &&
          analogLR == other.analogLR &&
          analogUD == other.analogUD;

  @override
  int get hashCode =>
      rightPad.hashCode ^
      buttonY.hashCode ^
      buttonZ.hashCode ^
      buttonA.hashCode ^
      buttonB.hashCode ^
      buttonOn.hashCode ^
      buttonShift.hashCode ^
      analogLR.hashCode ^
      analogUD.hashCode;
}
