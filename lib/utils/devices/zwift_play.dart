import 'package:flutter/foundation.dart';
import 'package:swift_control/utils/devices/zwift_click.dart';
import 'package:swift_control/utils/messages/controller_notification.dart';

import '../../main.dart';
import '../ble.dart';

class ZwiftPlay extends ZwiftClick {
  ZwiftPlay(super.scanResult);

  ControllerNotification? _lastControllerNotification;

  @override
  List<int> get startCommand => Constants.RIDE_ON + Constants.RESPONSE_START_PLAY;

  @override
  void processClickNotification(Uint8List message) {
    final ControllerNotification clickNotification = ControllerNotification(message);
    if (_lastControllerNotification == null || _lastControllerNotification != clickNotification) {
      _lastControllerNotification = clickNotification;
      actionStreamInternal.add(clickNotification);

      if (clickNotification.rightPad && clickNotification.analogLR.abs() == 100) {
        actionHandler.increaseGear();
      } else if (!clickNotification.rightPad && clickNotification.analogLR.abs() == 100) {
        actionHandler.decreaseGear();
      }
    }
  }
}
