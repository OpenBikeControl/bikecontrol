import 'package:flutter/foundation.dart';
import 'package:swift_control/bluetooth/devices/base_device.dart';
import 'package:swift_control/bluetooth/messages/notification.dart';
import 'package:swift_control/main.dart';

import '../messages/click_notification.dart';

class ZwiftClick extends BaseDevice {
  ZwiftClick(super.scanResult);

  ClickNotification? _lastClickNotification;

  @override
  Future<void> processClickNotification(Uint8List message) async {
    final ClickNotification clickNotification = ClickNotification(message);
    if (_lastClickNotification == null || _lastClickNotification != clickNotification) {
      _lastClickNotification = clickNotification;
      if (clickNotification.buttonsClicked.isNotEmpty) {
        actionStreamInternal.add(clickNotification);
      }

      final buttons = clickNotification.buttonsClicked;

      for (final action in buttons) {
        actionStreamInternal.add(LogNotification(await actionHandler.performAction(action)));
      }
    }
  }
}
