import 'dart:typed_data';

import 'package:dartx/dartx.dart';
import 'package:swift_control/utils/keymap/buttons.dart';

import '../protocol/zwift.pb.dart';
import 'notification.dart';

class ClickNotification extends BaseNotification {
  late List<ZwiftButton> buttonsClicked;

  ClickNotification(Uint8List message) {
    final status = ClickKeyPadStatus.fromBuffer(message);
    buttonsClicked = [
      if (status.buttonPlus == PlayButtonStatus.ON) ZwiftButton.shiftUpLeft,
      if (status.buttonMinus == PlayButtonStatus.ON) ZwiftButton.shiftDownLeft,
    ];
  }

  @override
  String toString() {
    return 'Buttons: ${buttonsClicked.joinToString(transform: (e) => e.name)}';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ClickNotification &&
          runtimeType == other.runtimeType &&
          buttonsClicked.contentEquals(other.buttonsClicked);

  @override
  int get hashCode => buttonsClicked.hashCode;
}
