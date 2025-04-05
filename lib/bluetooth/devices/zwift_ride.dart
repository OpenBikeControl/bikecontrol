import 'dart:typed_data';

import 'package:dartx/dartx.dart';
import 'package:swift_control/bluetooth/devices/base_device.dart';
import 'package:swift_control/bluetooth/messages/ride_notification.dart';
import 'package:swift_control/main.dart';
import 'package:swift_control/utils/keymap/buttons.dart';

import '../ble.dart';

class ZwiftRide extends BaseDevice {
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
      if (clickNotification.buttonsClicked.isNotEmpty) {
        actionStreamInternal.add(clickNotification);
      }

      if (clickNotification.buttonsClicked.containsAny([
        ZwiftButton.shiftDownLeft,
        ZwiftButton.shiftUpLeft,
        ZwiftButton.onOffLeft,
        ZwiftButton.powerUpLeft,
      ])) {
        actionHandler.decreaseGear();
      } else if (clickNotification.buttonsClicked.containsAny([
        ZwiftButton.shiftUpRight,
        ZwiftButton.shiftDownRight,
        ZwiftButton.onOffRight,
        ZwiftButton.powerUpRight,
      ])) {
        actionHandler.increaseGear();
      }

      /*if (clickNotification.buttonA) {
        actionHandler.controlMedia(MediaAction.next);
      } else if (clickNotification.buttonY) {
        actionHandler.controlMedia(MediaAction.volumeUp);
      } else if (clickNotification.buttonB) {
        actionHandler.controlMedia(MediaAction.volumeDown);
      } else if (clickNotification.buttonZ) {
        actionHandler.controlMedia(MediaAction.playPause);
      }*/
    }
  }
}
