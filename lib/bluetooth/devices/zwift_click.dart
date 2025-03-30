import 'package:flutter/foundation.dart';
import 'package:swift_control/bluetooth/devices/base_device.dart';
import 'package:swift_control/main.dart';

import '../messages/click_notification.dart';

class ZwiftClick extends BaseDevice {
  ZwiftClick(super.scanResult);

  ClickNotification? _lastClickNotification;

  @override
  void processClickNotification(Uint8List message) {
    final ClickNotification clickNotification = ClickNotification(message);
    if (_lastClickNotification == null || _lastClickNotification != clickNotification) {
      _lastClickNotification = clickNotification;
      actionStreamInternal.add(clickNotification);

      if (clickNotification.buttonUp) {
        actionHandler.increaseGear();
      } else if (clickNotification.buttonDown) {
        actionHandler.decreaseGear();
      }
    }
  }
}
