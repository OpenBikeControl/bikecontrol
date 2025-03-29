import 'dart:typed_data';

import 'package:accessibility/accessibility.dart';
import 'package:swift_control/main.dart';
import 'package:swift_control/utils/devices/zwift_click.dart';
import 'package:swift_control/utils/messages/ride_notification.dart';

import '../ble.dart';

class ZwiftRide extends ZwiftClick {
  ZwiftRide(super.scanResult);

  @override
  String get customServiceId => BleUuid.ZWIFT_RIDE_CUSTOM_SERVICE_UUID;

  @override
  bool get supportsEncryption => false;

  RideNotification? _lastControllerNotification;

  @override
  void processClickNotification(Uint8List message) {
    final RideNotification clickNotification = RideNotification(message);
    if (_lastControllerNotification == null || _lastControllerNotification != clickNotification) {
      _lastControllerNotification = clickNotification;
      actionStreamInternal.add(clickNotification);

      if (clickNotification.analogLR.abs() == 100) {
        actionHandler.increaseGear();
      } else if (clickNotification.analogUD.abs() == 100) {
        actionHandler.decreaseGear();
      }
      if (clickNotification.buttonA) {
        actionHandler.controlMedia(MediaAction.next);
      } else if (clickNotification.buttonY) {
        actionHandler.controlMedia(MediaAction.volumeUp);
      } else if (clickNotification.buttonB) {
        actionHandler.controlMedia(MediaAction.volumeDown);
      } else if (clickNotification.buttonZ) {
        actionHandler.controlMedia(MediaAction.playPause);
      }
    }
  }
}
