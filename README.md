# SwiftControl

<img src="logo.jpg" alt="SwiftControl Logo"/>

## Description

With SwiftControl you can control your favorite trainer app using your Zwift Click, Zwift Ride or Zwift Play devices. Here's what you can do with it, depending on your configuration:
- Virtual Gear shifting
- Steering / turning
- adjust workout intensity
- control music on your device
- more? If you can do it via keyboard, mouse or touch, you can do it with SwiftControl


https://github.com/user-attachments/assets/1f81b674-1628-4763-ad66-5f3ed7a3f159




## Downloads
Get the latest version here: https://github.com/jonasbark/swiftcontrol/releases

## Supported Apps
- MyWhoosh
- indieVelo / Training Peaks
- Biketerra.com
- any other: 
  - Android: you can customize simulated touch points of all your buttons in the app
  - Desktop: you can customize keyboard shortcuts and mouse clicks in the app

## Supported Devices
- Zwift Click
- Zwift Ride
- Zwift Play

## Supported Platforms
- Android
- macOS
- Windows 
  - make sure you have installed the "[Microsoft Visual C++ Runtime libraries](https://learn.microsoft.com/en-us/cpp/windows/latest-supported-vc-redist?view=msvc-170)"
  - Windows may flag the app as virus. I think it does so because the app does control the mouse and keyboard.
- [Web](https://jonasbark.github.io/swiftcontrol/) (you won't be able to do much)

## Troubleshooting
- Your Zwift device is found but connection does not work properly? You may need to update the firmware in Zwift Companion app.
- The Android app is losing connection over time? Read about how to [keep the app alive](https://dontkillmyapp.com/).

## How does it work?
The app connects to your Zwift device automatically. 

- When using Android a "click" on a certain part of the screen is simulated to trigger the action.
- When using macOS or Windows a keyboard or mouse click is used to trigger the action. 
  - there are predefined Keymaps for MyWhoosh and indieVelo / Training Peaks
  - you can also create your own Keymaps for any other app
  - you can also use the mouse to click on a certain part of the screen, or use keyboard shortcuts

## Donate
Please consider donating to support the development of this app :)

[![Donate](https://img.shields.io/badge/Donate-PayPal-green.svg)](https://paypal.me/boni)

