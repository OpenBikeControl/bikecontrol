### 4.6.0 (28-01-2026)

**Features**:
- Improve Zwift Click V2 connection and handling
- Buttons in Configuration are now grouped by device

### 4.5.0 (22-01-2026)

**Features**:
- Android: simulate additional actions for local connection method (Left, Down, Right, Up, Select, Back, Home, Recent Apps)
  - control your phone with your controller
  - control UI within the trainer app (if supported)
- BikeControl now supports individual mapping when you use more than one Cycplus BC2 and ThinkRider VS200 controller
- Windows & macOS: allow configuration of volume keys on Bluetooth HID devices

### 4.4.0 (16-01-2026)

**Features**:
- Support for Thinkrider VS200

**Fixes**:
- Android: Local connection method allows passing keyboard events to the trainer app
- macOS: Compatibility with macOS Tahoe
- Windows: send keyboard events to the correct window when using multiple monitors or when another app is focused
- Windows: fix media key detection

### 4.3.0 (07-01-2026)

**Features**:
- Onboarding for new users
- support controlling music & volume for Windows, macOS and Android
- App is now available in Italian (thanks to Connect_Thanks2613)

**Fixes**:
- Vibration setting now available for Zwift Ride devices

### 4.2.0 (20-12-2025)

BikeControl now offers a free trial period of 5 days for all features, so you can test everything before deciding to purchase a license. Please contact the support if you experience any issues!

**Features**:
- support for SRAM AXS/eTap
  - only single or double click is supported (no individual button mapping possible, yet)
- use your phone/tablet for steering by attaching your device on your handlebar!
- App is now available in Polish (thanks to Wandrocek)

**Fixes**:
- You will now be notified when a connection to your controller is lost
- improved UI of the Keymap customization screen

### 4.1.0 (16-12-2025)

**Features**:
- control your trainer manually without requiring a controller - just like a Companion app
- support for Wahoo KICKR HEADWIND: control the fan via your controller 

**Fixes**:
- Gamepads: handle analog values correctly on Windows
- MyWhoosh: updated default keymap to use the new A+D keys for steering 

### 4.0.0 (07-12-2025)

- a brand-new design
  - Accessibility Permission is now optional on Android
- Zwift is now fully supported on all operating systems
    - you can choose between network based control or bluetooth based control
- MyWhoosh can now also be controlled with BikeControl running on the same iPad / iPhone
- Translations available in German and French
- support for Wahoo KICKR BIKE PRO
- support for the OpenBikeControl protocol for supported Trainer apps
  - this enables seamless and official integration, independent of the operating system
  - learn more at https://openbikecontrol.org

### 3.6.0 (23-11-2025)

SwiftControl is now called BikeControl!

**Features:**
- show a list of predefined keymaps for the selected trainer app when using a custom keymap
- status icons so it's clear what's missing

**Fixes:**
- Update Rouvy keymap to support virtual shifting in their latest version 

### 3.5.0 (16-11-2025)
**New Features:**
- Dark mode support
- Cycplus BC2 support (thanks @schneewoehner)
- Ignored devices now persist across app restarts - remove them from ignored devices via the menu

**Fixes:**
- resolve issues during app start

### 3.4.0 (08-11-2025)
**New Features:**
- Support for Shimano Di2
- Support Keyboard shortcuts with modifier keys (Ctrl, Alt, Shift, ...)
- Support cheap BLE HID remotes 
- add Keymap for Rouvy, supporting the new keyboard shortcuts for virtual shifting

**Fixes:**
- fix detection of Elite Square Sterzo devices
- recognize cheap Bluetooth device clicks also when BikeControl is in the background

### 3.3.0 (31-10-2025)

**New Features:**
- Support for Elite Sterzo (thanks @michidk)
- Support for Gamepads
- Support for cheap bluetooth remotes (such as [these](https://www.amazon.com/s?k=bluetooth+remote))
- you can now customize the Keymap right from the Customize section
- show signal strength of connected devices (thanks @michidk)
- Android and Windows only: simulate bluetooth controllers
  - enables gamepad and bluetooth remotes support for Zwift, Rouvy and Biketerra

**Fixes:**
- fix firmware version display for Zwift Click V2 devices
- fix touch position on some Android devices
- Wahoo Kickr Bike Shift can now be connected
- update default keymap for TrainingPeaks

### 3.2.0 (2025-10-22)
- a brand-new way of controlling MyWhoosh:
  - device pairing no longer required as mouse emulation is no longer needed  
  - BikeControl can now stay in the background
  - more devices can be controlled
  - do more, such as define Emotes, Camera angles and steering

### 3.1.0 (2025-10-17) 
- new app icon
- adjusted MyWhoosh keyboard navigation mapping (thanks @bin101)
- support for Wahook Kickr Bike Shift (thanks @MattW2)
- initial support for Elite Square Smart Frame
- reconnects to your device automatically when connection is lost
- BikeControl now warns you if your device firmware is outdated
- BikeControl is now available in Microsoft Store: https://apps.microsoft.com/detail/9NP42GS03Z26

### 3.0.3 (2025-10-12)
- BikeControl now supports iOS!
  - Note that you can't run BikeControl and your trainer app on the same iPhone due to iOS limitations but...:
- You can now use BikeControl as "remote control" for other devices, such as an iPad. Example scenario:
    - your phone (Android/iOS) runs BikeControl and connects to your Click devices
    - your iPad or other tablet runs e.g. MyWhoosh (does not need to have BikeControl installed)
    - after pairing BikeControl to your iPad / tablet via Bluetooth your phone will send the button presses to your iPad / tablet
- Ride: analog paddles are now supported thanks to contributor @jmoro
- you can now zoom in and out in the Keymap customization screen

### 2.6.3 (2025-10-01)
- fix a few issues with the new touch placement feature
- add a workaround for Zwift Click V2 which resets the device when button events are no longer sent
- fix issue on Android and Desktop where only a "touch down" was sent, but no "touch up"
- improve UI when handling custom keymaps around the edges of the screen

### 2.6.0 (2025-09-30)
- refactor touch placements: show touches on screen, fix misplaced coordinates - should fix #64
- show firmware version of connected device
- Fix crashes on some Android devices
- warn the user how to make Zwift Click V2 work properly
- many UI improvements
- add setting to enable or disable vibration on button press for Zwift Ride and Zwift Play controllers

### 2.5.0 (2025-09-25)
- Improve usability
- BikeControl is now available via the Play Store: https://play.google.com/store/apps/details?id=de.jonasbark.swiftcontrol
  - BikeControl will continue to be available to download for free on GitHub
  - contact me if you already donated and I'll get a voucher for you :)

### 2.4.0+1 (2025-09-17)
- Windows: fix mouse clicks at wrong location due to display scaling (fixes #64)

### 2.4.0 (2025-09-16)
- Show an overview of the keymap bindings
- Allow customizing an existing keymap
- Add more donation options

### 2.3.0 (2025-09-11)
- Add support for latest Zwift Click v2

### 2.2.0 (2025-09-08)
- Add Long Press Mode option for custom keymaps - buttons can now send sustained key presses instead of repeated taps, perfect for movement controls in games (fixes #61)
- Windows: adjust key sending method to improve compatibility with more apps (fixes #62)

### 2.1.0 (2025-07-03)
- Windows: automatically focus compatible training apps (MyWhoosh, IndieVelo, Biketerra) when sending keystrokes, enabling seamless multi-window usage

### 2.0.9 (2025-05-04)
- you can now assign Escape and arrow down key to your custom keymap (#18)

### 2.0.8 (2025-05-02)
- only use the light theme for the app
- more troubleshooting information

### 2.0.7 (2025-04-18)
- add Biketerra.com keymap
- some UX improvements

### 2.0.6 (2025-04-15)
- fix MyWhoosh up / downshift button assignment (I key vs K key)

### 2.0.5 (2025-04-13)
- fix Zwift Click button assignment (#12)

### 2.0.4 (2025-04-10)
- vibrate Zwift Play / Zwift Ride controller on gear shift (thanks @cagnulein, closes #16)

### 2.0.3 (2025-04-08)
- adjust TrainingPeaks Virtual key mapping (#12)
- attempt to reconnect device if connection is lost 
- Android: detect freeform windows for MyWhoosh + TrainingPeaks Virtual keymaps 

### 2.0.2 (2025-04-07)
- fix bluetooth scan issues on older Android devices by asking for location permission

### 2.0.1 (2025-04-06)
- long pressing a button will trigger the action again every 250ms

### 2.0.0 (2025-04-06)
- You can now customize the actions (touches, mouse clicks or keyboard keys) for all buttons on all supported Zwift devices
- now shows the battery level of the connected devices
- add more troubleshooting information

### 1.1.10 (2025-04-03)
- Add more troubleshooting during connection

### 1.1.8 (2025-04-02)
- Android: make sure the touch reassignment page is fullscreen

### 1.1.7 (2025-04-01)
- Zwift Ride: fix connection issues by connecting only to the left controller
- Windows: connect sequentially to fix (finally?) fix connection issues
- Windows: change the way keyboard is simulated, should fix glitches

### 1.1.6 (2025-03-31)
- Zwift Ride: add buttonPowerDown to shift gears
- Zwift Play: Fix buttonShift assignment
- Android: fix action to go to next song
- App now checks if you run the latest available version

### 1.1.5 (2025-03-30)
- fix bluetooth connection #6, also add missing entitlement on macOS

### 1.1.3 (2025-03-30)
- Windows: fix custom keyboard profile recreation after restart, also warn when choosing MyWhoosh profile (may fix #7)
- Zwift Ride: button map adjustments to prevent double shifting
- potential fix for #6 

### 1.1.1 (2025-03-30)
- potential fix for Bluetooth device detection

### 1.1.0 (2025-03-30)
- Windows & macOS: allow setting custom keymap and store the setting
- Android: allow customizing the touch area, so it can work with any device without guesswork where the buttons are (#4)
- Zwift Ride: update Zwift Ride decoding based on Feedback from @JayyajGH (#3)

### 1.0.6 (2025-03-29)
- Another potential keyboard fix for Windows
- Zwift Play: actually also use the dedicated shift buttons 

### 1.0.5 (2025-03-29)
- Zwift Ride: remap the shifter buttons to the correct values

### 1.0.0+4 (2025-03-29)
- Zwift Ride: attempt to fix button parsing
- Android: fix missing permissions
- Windows: potential fix for key press issues

### 1.0.0+3 (2025-03-29)

- Windows: fix connection by using a different Bluetooth stack (issue #1)
- Android: fix non-working touch propagation (issue #2)
