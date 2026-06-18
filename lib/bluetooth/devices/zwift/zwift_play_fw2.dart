import 'package:bike_control/bluetooth/devices/zwift/constants.dart';
import 'package:bike_control/bluetooth/devices/zwift/zwift_ride.dart';

class ZwiftPlayFw2 extends ZwiftRide {
  ZwiftPlayFw2(super.scanResult)
    : super(
        availableButtons: [
          ZwiftButtons.navigationUp,
          ZwiftButtons.navigationLeft,
          ZwiftButtons.navigationRight,
          ZwiftButtons.navigationDown,
          ZwiftButtons.onOffLeft,
          ZwiftButtons.shiftUpLeft,
          ZwiftButtons.paddleLeft,
          ZwiftButtons.y,
          ZwiftButtons.z,
          ZwiftButtons.a,
          ZwiftButtons.b,
          ZwiftButtons.onOffRight,
          ZwiftButtons.shiftUpRight,
          ZwiftButtons.paddleRight,
        ],
      );

  @override
  String get latestFirmwareVersion => '2.0.1';
}
