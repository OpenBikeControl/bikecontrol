import 'package:flutter/foundation.dart';
import 'package:swift_control/bluetooth/devices/zwift/messages/click_notification.dart';
import 'package:swift_control/bluetooth/devices/zwift/zwift_device.dart';
import 'package:swift_control/utils/keymap/buttons.dart';

class ZwiftClick extends ZwiftDevice {
  ZwiftClick(super.scanResult)
    : super(availableButtons: [ControllerButton.shiftUpRight, ControllerButton.shiftDownLeft]);

  ClickNotification? _lastClickNotification;

  @override
  Future<List<ControllerButton>?> processClickNotification(Uint8List message) async {
    final ClickNotification clickNotification = ClickNotification(message);
    if (_lastClickNotification == null || _lastClickNotification != clickNotification) {
      _lastClickNotification = clickNotification;

      if (clickNotification.buttonsClicked.isNotEmpty) {
        actionStreamInternal.add(clickNotification);
      }
      return clickNotification.buttonsClicked;
    } else {
      return null;
    }
  }
}
