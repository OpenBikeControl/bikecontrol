import 'package:bike_control/bluetooth/devices/zwift/zwift_ride.dart';

class WahooKickrBikePro extends ZwiftRide {
  WahooKickrBikePro(super.scanResult) : super();

  @override
  String? get latestFirmwareVersion => null;
}
