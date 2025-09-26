# SwiftControl

<img src="logo.jpg" alt="SwiftControl Logo"/>

## Description

With SwiftControl you can **control your favorite trainer app** using your Zwift Click, Zwift Ride or Zwift Play devices. Here's what you can do with it, depending on your configuration:
- Virtual Gear shifting
- Steering / turning
- adjust workout intensity
- control music on your device
- more? If you can do it via keyboard, mouse or touch, you can do it with SwiftControl

**Android AccessibilityService Usage**: On Android, SwiftControl uses the AccessibilityService API to simulate touch gestures on your screen, allowing your Zwift devices to control training apps. This service only monitors which app window is active and performs touch gestures at the locations you configure. No personal data is accessed or collected.


https://github.com/user-attachments/assets/1f81b674-1628-4763-ad66-5f3ed7a3f159




## Downloads
<a href="https://play.google.com/store/apps/details?id=de.jonasbark.swiftcontrol"><img width="270" height="80" alt="GetItOnGooglePlay_Badge_Web_color_English" src="https://github.com/user-attachments/assets/a059d5a1-2efb-4f65-8117-ef6a99823b21" /></a>

Get the latest version for free for Windows, macOS and Android here: https://github.com/jonasbark/swiftcontrol/releases

## Supported Apps
- MyWhoosh
- indieVelo / Training Peaks
- Biketerra.com
- any other: 
  - Android: you can customize simulated touch points of all your buttons in the app
  - Desktop: you can customize keyboard shortcuts and mouse clicks in the app

## Supported Devices
- Zwift Click
- Zwift Click v2 (mostly, see #68)
- Zwift Ride
- Zwift Play

## Supported Platforms
- Android
  - App is losing connection over time? Read about how to [keep the app alive](https://dontkillmyapp.com/).
- macOS
- Windows 
  - Windows may flag the app as virus. I think it does so because the app does control the mouse and keyboard.
  - Bluetooth connection unstable? You may need to use an [external Bluetooth adapter](https://github.com/jonasbark/swiftcontrol/issues/14#issuecomment-3193839509).
  - Make sure your Zwift device is not paired with Windows Bluetooth settings: [more information](https://github.com/jonasbark/swiftcontrol/issues/70).
- [Web](https://jonasbark.github.io/swiftcontrol/) (you won't be able to do much)
- NOT SUPPORTED: iOS (iPhone, iPad) as Apple does not provide any way to simulate touches or keyboard events

## Troubleshooting
- Your Zwift device is found but connection does not work properly? You may need to update the firmware in Zwift Companion app.

## How does it work?
The app connects to your Zwift device automatically. It does not connect to your trainer itself.

- When using Android: SwiftControl uses the AccessibilityService API to simulate touch gestures on specific parts of your screen to trigger actions in training apps. The service monitors which training app window is currently active to ensure gestures are sent to the correct app.
- When using macOS or Windows a keyboard or mouse click is used to trigger the action. 
  - there are predefined Keymaps for MyWhoosh, indieVelo / Training Peaks, and others
  - you can also create your own Keymaps for any other app
  - you can also use the mouse to click on a certain part of the screen, or use keyboard shortcuts

## Alternatives
- [qdomyos-zwift](https://www.qzfitness.com/) directly controls the trainer (as opposed to controlling the trainer app)

## Donate
Please consider donating to support the development of this app :)

- [via PayPal](https://paypal.me/boni)
- [via Credit Card, Google Pay, Apple Pay, etc (USD)](https://donate.stripe.com/8x24gzc5c4ZE3VJdt36J201)
- [via Credit Card, Google Pay, Apple Pay, etc (EUR)](https://donate.stripe.com/9B6aEX0muajY8bZ1Kl6J200)
