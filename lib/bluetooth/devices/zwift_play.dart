import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:swift_control/bluetooth/devices/base_device.dart';
import 'package:swift_control/bluetooth/messages/play_notification.dart';
import 'package:swift_control/utils/keymap/buttons.dart';

import '../ble.dart';

class ZwiftPlay extends BaseDevice {
  ZwiftPlay(super.scanResult);

  PlayNotification? _lastControllerNotification;

  @override
  List<int> get startCommand => Constants.RIDE_ON + Constants.RESPONSE_START_PLAY;

  @override
  Future<List<ZwiftButton>?> processClickNotification(Uint8List message) async {
    final PlayNotification clickNotification = PlayNotification(message);
    if (_lastControllerNotification == null || _lastControllerNotification != clickNotification) {
      _lastControllerNotification = clickNotification;

      if (clickNotification.buttonsClicked.isNotEmpty) {
        actionStreamInternal.add(clickNotification);
      }

      return clickNotification.buttonsClicked;
    } else {
      return null;
    }
  }
}
