# BikeControl (formerly SwiftControl)

<img src="logo.png" alt="BikeControl Logo"/>

## Description

With BikeControl you can **control your favorite trainer app** using your Zwift Click, Zwift Ride, Zwift Play, Shimano Di2, or other similar devices. Here's what you can do with it, depending on your configuration:
- Virtual Gear shifting
- Steering / navigation
- adjust workout intensity
- control music on your device
- more? If you can do it via keyboard, mouse, or touch, you can do it with BikeControl

[![Youtube Video](https://github.com/user-attachments/assets/14a45ca1-e31b-4fbd-8d03-95aa60470405)](https://youtu.be/0r3LO5lFlyc)


## Download
Best follow our landing page and the "Get Started" button: [bikecontrol.app](https://bikecontrol.app/) to understand on which platform you want to run BikeControl. A testing period is available, allowing you to try out the full functionality of BikeControl:

<a href="https://play.google.com/store/apps/details?id=de.jonasbark.swiftcontrol"><img width="270" height="80" alt="GetItOnGooglePlay_Badge_Web_color_English" src="https://github.com/user-attachments/assets/a059d5a1-2efb-4f65-8117-ef6a99823b21" /></a>

<a href="https://apps.apple.com/us/app/swiftcontrol/id6753721284?platform=iphone"><img width="270" alt="App Store" src="https://github.com/user-attachments/assets/c23f977a-48f6-4951-811e-ae530dbfa014" /></a>

<a href="https://apps.apple.com/us/app/swiftcontrol/id6753721284?platform=mac"><img width="270" height="80" alt="Mac App Store" src="https://github.com/user-attachments/assets/b3552436-409c-43b0-ba7d-b6a72ae30ff1" /></a>

<a href="https://apps.microsoft.com/detail/9NP42GS03Z26"><img width="270" alt="Microsoft Store" src="https://github.com/user-attachments/assets/7a8a3cd6-ec26-4678-a850-732eedd27c48" /></a>

## Supported Apps
- MyWhoosh
- Zwift
- TrainingPeaks Virtual
- Biketerra.com
- Rouvy
- [OpenBikeControl](https://openbikecontrol.org) compatible apps
- any other!
  - You can add custom mapping and adjust touch points or keyboard shortcuts to your liking

## Supported Devices
- Zwift Click
- Zwift Click v2 (mostly, see issue #68)
- Zwift Ride
- Zwift Play
- Shimano Di2
  - Configure your levers to use D-Fly channels with Shimano E-Tube app
- SRAM AXS/eTap
  - Configure your levers not to do any action in the "SRAM AXS" app
  - only single or double click is supported (no individual button mapping possible, yet)
- Wahoo Kickr Bike Shift
- Wahoo Kickr Bike Pro
- CYCPLUS BC2 Virtual Shifter
- Thinkrider VS200 Virtual Shifter (beta)
- Elite Sterzo Smart (for steering support)
- Elite Square Smart Frame (beta)
- Your Phone!
  - Mount your phone on the handlebar to detect e.g. steering
  - Available on Android and iOS
- Gamepads
- Keyboard input
  - like a Companion App
  - some trainers do not support keyboard input for all functions - now they do!
  - useful when remapping keys from other devices using e.g. AutoHotkey
- Cheap Bluetooth buttons such as [these](https://www.amazon.com/s?k=bluetooth+remote) (beta)
  - BLE HID devices and classic Bluetooth HID devices are supported
  - works out of the box on Android
  - on Windows, iOS and macOS requires BikeControl to act as media player
- We're working on creating an affordable alternative based on an open standard, supported by all major trainer apps
  - register your interest [here](https://openbikecontrol.org/#HARDWARE)

Support for other devices can be added; check the issues tab here on GitHub.

## Supported Accessories
- Wahoo KICKR HEADWIND (beta)
    - control fan speed using your controller

## Supported Platforms

Follow the "Get Started" button over at [bikecontrol.app](https://bikecontrol.app) to understand on which platform you want to run BikeControl.
You can even try it out in your [Browser](https://openbikecontrol.github.io/bikecontrol/), if it supports Bluetooth connections. No controlling possible, though.

## Help
Check the troubleshooting guide [here](TROUBLESHOOTING.md).

## How does it work?
The app connects to your Controller devices (such as Zwift ones) automatically. BikeControl uses different methods of connecting to the trainer app, depending on the trainer app and operating system:
- Connect to the trainer app on the same device or on another device using Network
    - available on Android, iOS, iPadOS, macOS, Windows
    - supported by e.g. MyWhoosh, Rouvy and Zwift
- Connect to the trainer app on another device by simulating a Bluetooth device
  - available on Android, iOS, iPadOS, macOS, Windows
  - supported by e.g. Rouvy and Zwift
- Directly control the trainer app via Accessibility features (simulating touch and keyboard input)
  - available on Android, macOS, Windows
  - supported by all trainer apps
- Connect to the supported trainer app using the [OpenBikeControl](https://openbikecontrol.org) protocol
  - available on Android, iOS, iPadOS, macOS, Windows

## Accessories

- 3D printable models from Zwift [Zwift 3D-printable mounts for Click](https://www.zwift.com/uk/news/33400-zwift-3d-printable-mounts-for-click).

## Donate
Please consider donating to support the development of this app :)

- [via PayPal](https://paypal.me/boni)
- [via Credit Card, Google Pay, Apple Pay, etc. (USD)](https://donate.stripe.com/8x24gzc5c4ZE3VJdt36J201)
- [via Credit Card, Google Pay, Apple Pay, etc. (EUR)](https://donate.stripe.com/9B6aEX0muajY8bZ1Kl6J200)
