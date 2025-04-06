import 'dart:typed_data';

import 'package:swift_control/bluetooth/devices/base_device.dart';
import 'package:swift_control/bluetooth/messages/ride_notification.dart';
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
  Future<List<ZwiftButton>?> processClickNotification(Uint8List message) async {
    final RideNotification clickNotification = RideNotification(message);
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
