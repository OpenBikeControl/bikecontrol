## Click / Ride device cannot be found
*
You may need to update the firmware in Zwift Companion app.

## Click / Ride device does not send any data
*
You may need to update the firmware in Zwift Companion app.

## My Click v2 disconnects after a minute
*
Check [this](https://github.com/jonasbark/swiftcontrol/issues/68) discussion.

To make your Click V2 work best you should connect it in the Zwift app once each day.
If you don't do that BikeControl will need to reconnect every minute.

1. Open Zwift app (not the Companion)
2. Log in (subscription not required) and open the device connection screen
3. Connect your Trainer, then connect the Click V2
4. Optional: some users report that keeping the Click connected for more than a few seconds is more reliable.
5. Close the Zwift app again and connect again in BikeControl

## Android: Connection works, buttons work but nothing happens in MyWhoosh and similar
*
- especially for Redmi and other chinese Android devices please follow the instructions on [https://dontkillmyapp.com/](https://dontkillmyapp.com/):
  - disable battery optimization for BikeControl
  - enable auto start of BikeControl
  - grant accessibility permission for BikeControl
- see [https://github.com/jonasbark/swiftcontrol/issues/38](https://github.com/OpenBikeControl/bikecontrol/issues/38) for more details

## BikeControl crashes on Windows when searching for the device
*
You're probably running into [this](https://github.com/OpenBikeControl/bikecontrol/issues/70) issue. Disconnect your controller device (e.g. Zwift Play) from Windows Bluetooth settings.


## My Clicks do not get recognized in MyWhoosh, but I am connected / use local control
*
Make sure you've enabled Virtual Shifting in MyWhoosh's settings
