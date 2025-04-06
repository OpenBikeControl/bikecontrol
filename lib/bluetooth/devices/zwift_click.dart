import 'package:flutter/foundation.dart';
import 'package:swift_control/bluetooth/devices/base_device.dart';
import 'package:swift_control/utils/keymap/buttons.dart';

import '../messages/click_notification.dart';

class ZwiftClick extends BaseDevice {
  ZwiftClick(super.scanResult);

  ClickNotification? _lastClickNotification;

  @override
  Future<List<ZwiftButton>?> processClickNotification(Uint8List message) async {
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
