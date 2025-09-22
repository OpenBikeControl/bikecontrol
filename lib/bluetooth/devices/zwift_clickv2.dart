import 'package:swift_control/bluetooth/devices/zwift_ride.dart';

class ZwiftClickV2 extends ZwiftRide {
  ZwiftClickV2(super.scanResult);

  @override
  bool get supportsEncryption => true;
}
