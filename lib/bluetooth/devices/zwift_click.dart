import 'package:flutter/foundation.dart';
import 'package:swift_control/bluetooth/devices/base_device.dart';
import 'package:swift_control/main.dart';
import 'package:swift_control/utils/keymap/buttons.dart';

import '../messages/click_notification.dart';

class ZwiftClick extends BaseDevice {
  ZwiftClick(super.scanResult);

  ClickNotification? _lastClickNotification;

  @override
  void processClickNotification(Uint8List message) {
    final ClickNotification clickNotification = ClickNotification(message);
    if (_lastClickNotification == null || _lastClickNotification != clickNotification) {
      _lastClickNotification = clickNotification;
      if (clickNotification.buttonsClicked.isNotEmpty) {
        actionStreamInternal.add(clickNotification);
      }

      if (clickNotification.buttonsClicked.contains(ZwiftButton.shiftUpLeft)) {
        actionHandler.increaseGear();
      } else if (clickNotification.buttonsClicked.contains(ZwiftButton.shiftDownLeft)) {
        actionHandler.decreaseGear();
      }
    }
  }
}
