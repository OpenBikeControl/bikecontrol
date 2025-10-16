## Click device cannot be found
You may need to update the firmware in Zwift Companion app.

## Click device does not send any data
You may need to update the firmware in Zwift Companion app.

## My Click v2 disconnects after a minute
Check [this](https://github.com/jonasbark/swiftcontrol/issues/68) discussion.

To make your Click V2 work best you should connect it in the Zwift app once each day.
If you don't do that SwiftControl will need to reconnect every minute.

1. Open Zwift app (not the Companion)
2. Log in (subscription not required) and open the device connection screen
3. Connect your Trainer, then connect the Click V2
4. Close the Zwift app again and connect again in SwiftControl

## Remote control is not working - nothing happens
- Try to unpair it from your phone / computer Bluetooth settings, then re-pair it.
- Try restarting the pairing process in SwiftControl
- try restarting Bluetooth on your phone and on the device you want to control
- If your other device is an iOS device, go to Settings > Accessibility > Touch > AssistiveTouch > Pointer Devices > Devices and pair your device. Make sure AssistiveTouch is enabled.
- it is very important that both devices (e.g. iPhone and iPad) receive the "pairing dialog" after initial connection. If you miss it, unpair and try again. It may take a few seconds for the dialog to appear. Afterwards you may need to click on "Reconnect" in SwiftControl / restart SwiftControl.

## Remote control only clicks on a single coordinate on my iPad
iOS seems to be buggy here - try this in the iOS settings:
AssistiveTouch settings > Pointer Devices > Devices > Connected Devices > iPhone (or SwiftControl iOS) > Button 1 
switch the setting to None, then back to Single-Tap and it should work again

## SwiftControl crashes on Windows when searching for the device 
You're probably running into [this](https://github.com/jonasbark/swiftcontrol/issues/70) issue. Disconnect your controller device (e.g. Zwift Play) from Windows Bluetooth settings.
