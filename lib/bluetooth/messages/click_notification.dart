import 'dart:typed_data';

import '../protocol/zwift.pb.dart';
import 'notification.dart';

class ClickNotification extends BaseNotification {
  static const int BTN_PRESSED = 0;

  bool buttonUp = false;
  bool buttonDown = false;

  ClickNotification(Uint8List message) {
    final status = ClickKeyPadStatus.fromBuffer(message);
    buttonUp = status.buttonPlus.value == BTN_PRESSED;
    buttonDown = status.buttonMinus.value == BTN_PRESSED;
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
