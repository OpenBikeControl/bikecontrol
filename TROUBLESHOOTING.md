## Click / Ride device cannot be found
You may need to update the firmware in Zwift Companion app.

## Click / Ride device does not send any data
You may need to update the firmware in Zwift Companion app.

## My Click v2 disconnects after a minute
Check [this](https://github.com/OpenBikeControl/bikecontrol/issues/68) discussion.

To make your Click V2 work best you should connect it in the Zwift app once each day.
If you don't do that BikeControl will need to reconnect every minute.

1. Open Zwift app (not the Companion)
2. Log in (subscription not required) and open the device connection screen
3. Connect your Trainer, then connect the Click V2
4. Close the Zwift app again and connect again in BikeControl

## Android: Connection works, buttons work but nothing happens in MyWhoosh and similar
- especially for Redmi and other chinese Android devices please follow the instructions on [https://dontkillmyapp.com/](https://dontkillmyapp.com/):
  - disable battery optimization for BikeControl
  - enable auto start of BikeControl
  - grant accessibility permission for BikeControl
- see [https://github.com/OpenBikeControl/bikecontrol/issues/38](https://github.com/OpenBikeControl/bikecontrol/issues/38) for more details

## Remote control is not working - nothing happens
- Try to unpair it from your phone / computer Bluetooth settings, then re-pair it.
- Try restarting the pairing process in BikeControl
- try restarting Bluetooth on your phone and on the device you want to control
- If your other device is an iOS device, go to Settings > Accessibility > Touch > AssistiveTouch > Pointer Devices > Devices and pair your device. Make sure AssistiveTouch is enabled.
- it is very important that both devices (e.g. iPhone and iPad) receive the "pairing dialog" after initial connection. If you miss it, unpair and try again. It may take a few seconds for the dialog to appear. Afterwards you may need to click on "Reconnect" in BikeControl / restart BikeControl.

## Remote control only clicks on a single coordinate on my iPad
iOS seems to be buggy here - try this in the iOS settings:
AssistiveTouch settings > Pointer Devices > Devices > Connected Devices > iPhone (or BikeControl iOS) > Button 1 
switch the setting to None, then back to Single-Tap and it should work again

## BikeControl crashes on Windows when searching for the device 
You're probably running into [this](https://github.com/OpenBikeControl/bikecontrol/issues/70) issue. Disconnect your controller device (e.g. Zwift Play) from Windows Bluetooth settings.

## MyWhoosh Direct Connect never connects
The same network restrictions apply for BikeControl as it applies to MyWhoosh Link app. Please verify with the MyWhoosh Link app if connection is possible at all.
Here are some instructions that can help:

[https://mywhoosh.com/troubleshoot/](https://mywhoosh.com/troubleshoot/)
[https://www.facebook.com/groups/mywhoosh/posts/1323791068858873/](https://www.facebook.com/groups/mywhoosh/posts/1323791068858873/)
[INSTRUCTIONS_IOS.md](INSTRUCTIONS_IOS.md)

In essence:
- your two devices (phone, tablet) need to be on the same WiFi network
- on iOS you have to turn off "Private Wi-Fi Address" in the WiFi settings
- Limit IP Address Tracking may need to be disabled
- mesh networks may not work

