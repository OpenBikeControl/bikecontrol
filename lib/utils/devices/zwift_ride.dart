import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:swift_control/utils/devices/zwift_play.dart';

import '../ble.dart';

class ZwiftRide extends ZwiftPlay {
  ZwiftRide(super.scanResult);

  @override
  Guid get customServiceId => BleUuid.ZWIFT_RIDE_CUSTOM_SERVICE_UUID;

  @override
  bool get supportsEncryption => false;
}
