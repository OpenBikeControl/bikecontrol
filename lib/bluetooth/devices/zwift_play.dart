import 'package:flutter/foundation.dart';
import 'package:swift_control/bluetooth/devices/base_device.dart';
import 'package:swift_control/bluetooth/messages/play_notification.dart';

import '../../main.dart';
import '../ble.dart';
import '../messages/notification.dart';

class ZwiftPlay extends BaseDevice {
  ZwiftPlay(super.scanResult);

  PlayNotification? _lastControllerNotification;

  @override
  List<int> get startCommand => Constants.RIDE_ON + Constants.RESPONSE_START_PLAY;

  @override
  Future<void> processClickNotification(Uint8List message) async {
    final PlayNotification clickNotification = PlayNotification(message);
    if (_lastControllerNotification == null || _lastControllerNotification != clickNotification) {
      _lastControllerNotification = clickNotification;

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
