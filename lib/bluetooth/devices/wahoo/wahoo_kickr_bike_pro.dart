import 'package:swift_control/bluetooth/devices/zwift/zwift_ride.dart';

import '../zwift/constants.dart';

class WahooKickrBikePro extends ZwiftRide {
  WahooKickrBikePro(super.scanResult) : super();

  @override
  String get customServiceId => ZwiftConstants.ZWIFT_CUSTOM_SERVICE_UUID;
}
