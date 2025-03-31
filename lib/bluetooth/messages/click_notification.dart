import 'dart:typed_data';

import '../protocol/zwift.pb.dart';
import 'notification.dart';

class ClickNotification extends BaseNotification {
  bool buttonUp = false;
  bool buttonDown = false;

  ClickNotification(Uint8List message) {
    final status = ClickKeyPadStatus.fromBuffer(message);
    buttonUp = status.buttonPlus == PlayButtonStatus.ON;
    buttonDown = status.buttonMinus == PlayButtonStatus.ON;
  }

  @override
  String toString() {
    return 'Click: {buttonUp: $buttonUp, buttonDown: $buttonDown}';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ClickNotification &&
          runtimeType == other.runtimeType &&
          buttonUp == other.buttonUp &&
          buttonDown == other.buttonDown;

  @override
  int get hashCode => buttonUp.hashCode ^ buttonDown.hashCode;
}
