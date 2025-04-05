import 'package:accessibility/accessibility.dart';
import 'package:dartx/dartx.dart';
import 'package:flutter/foundation.dart';
import 'package:swift_control/bluetooth/devices/base_device.dart';
import 'package:swift_control/bluetooth/messages/play_notification.dart';
import 'package:swift_control/utils/keymap/buttons.dart';

import '../../main.dart';
import '../ble.dart';

class ZwiftPlay extends BaseDevice {
  ZwiftPlay(super.scanResult);

  PlayNotification? _lastControllerNotification;

  @override
  List<int> get startCommand => Constants.RIDE_ON + Constants.RESPONSE_START_PLAY;

  @override
  void processClickNotification(Uint8List message) {
    final PlayNotification clickNotification = PlayNotification(message);
    if (_lastControllerNotification == null || _lastControllerNotification != clickNotification) {
      _lastControllerNotification = clickNotification;

      if (clickNotification.buttonsClicked.isNotEmpty) {
        actionStreamInternal.add(clickNotification);
      }

      if (clickNotification.buttonsClicked.containsAny([ZwiftButton.sideButtonRight, ZwiftButton.paddleRight])) {
        actionHandler.increaseGear();
      } else if (clickNotification.buttonsClicked.containsAny([ZwiftButton.sideButtonLeft, ZwiftButton.paddleLeft])) {
        actionHandler.decreaseGear();
      }
      if (clickNotification.buttonsClicked.contains(ZwiftButton.navigationLeft)) {
        actionHandler.controlMedia(MediaAction.next);
      } else if (clickNotification.buttonsClicked.contains(ZwiftButton.navigationUp)) {
        actionHandler.controlMedia(MediaAction.volumeUp);
      } else if (clickNotification.buttonsClicked.contains(ZwiftButton.navigationDown)) {
        actionHandler.controlMedia(MediaAction.volumeDown);
      } else if (clickNotification.buttonsClicked.contains(ZwiftButton.navigationRight)) {
        actionHandler.controlMedia(MediaAction.playPause);
      }
    }
  }
}
