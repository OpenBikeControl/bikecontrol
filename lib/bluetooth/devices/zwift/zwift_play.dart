import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:swift_control/bluetooth/devices/zwift/messages/play_notification.dart';
import 'package:swift_control/bluetooth/devices/zwift/zwift_device.dart';
import 'package:swift_control/utils/keymap/buttons.dart';

import '../../ble.dart';

class ZwiftPlay extends ZwiftDevice {
  ZwiftPlay(super.scanResult)
    : super(
        availableButtons: [
          ControllerButton.y,
          ControllerButton.z,
          ControllerButton.a,
          ControllerButton.b,
          ControllerButton.onOffRight,
          ControllerButton.sideButtonRight,
          ControllerButton.paddleRight,
          ControllerButton.navigationUp,
          ControllerButton.navigationLeft,
          ControllerButton.navigationRight,
          ControllerButton.navigationDown,
          ControllerButton.onOffLeft,
          ControllerButton.sideButtonLeft,
          ControllerButton.paddleLeft,
        ],
      );

  PlayNotification? _lastControllerNotification;

  @override
  List<int> get startCommand => Constants.RIDE_ON + Constants.RESPONSE_START_PLAY;

  @override
  Future<List<ControllerButton>?> processClickNotification(Uint8List message) async {
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
