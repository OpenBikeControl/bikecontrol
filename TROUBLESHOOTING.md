## Click / Ride device cannot be found
*
This means BikeControl does NOT see the device via Bluetooth.
- Put the controller into pairing mode (LED should blink)
- Ensure the controller is NOT connected to another app/device (e.g. Zwift)
- Update controller firmware in Zwift Companion, if available
- Reboot Bluetooth / reboot phone/PC

## Click / Ride device does not send any data
*
You may need to update the firmware in Zwift Companion app.

## My Click v2 disconnects after a minute or buttons do not work
*

To make your Click V2 work best you should connect it in the Zwift app once before a workout session.
If you don't do that BikeControl will need to reconnect every minute.

1. Open Zwift app (not the Companion)
2. Log in (subscription not required) → device connection screen
3. Connect trainer, then connect Click v2
4. Keep it connected for ~10–30 seconds
5. Close Zwift completely, then connect in BikeControl

Details/updates: https://github.com/OpenBikeControl/bikecontrol/issues/68

## Android: Connection works, buttons work but nothing happens in MyWhoosh and similar
*
- especially for Redmi and other chinese Android devices please follow the instructions on [https://dontkillmyapp.com/](https://dontkillmyapp.com/):
  - disable battery optimization for BikeControl
  - enable auto start of BikeControl
  - grant accessibility permission for BikeControl
- see [https://github.com/OpenBikeControl/bikecontrol/issues/38](https://github.com/OpenBikeControl/bikecontrol/issues/38) for more details


## My Clicks do not get recognized in MyWhoosh, but I am connected / use local control
*
Make sure you've enabled Virtual Shifting in MyWhoosh's settings
