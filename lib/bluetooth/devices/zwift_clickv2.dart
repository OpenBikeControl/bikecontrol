import 'package:swift_control/bluetooth/devices/zwift_ride.dart';

import '../ble.dart';

class ZwiftClickV2 extends ZwiftRide {
  ZwiftClickV2(super.scanResult);

  @override
  bool get supportsEncryption => false;

  @override
  List<int> get startCommand => Constants.RIDE_ON + Constants.RESPONSE_START_CLICK_V2;
}
