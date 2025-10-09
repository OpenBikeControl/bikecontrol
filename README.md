# SwiftControl

<img src="logo.jpg" alt="SwiftControl Logo"/>

## Description

With SwiftControl you can **control your favorite trainer app** using your Zwift Click, Zwift Ride or Zwift Play devices. Here's what you can do with it, depending on your configuration:
- Virtual Gear shifting
- Steering / turning
- adjust workout intensity
- control music on your device
- more? If you can do it via keyboard, mouse or touch, you can do it with SwiftControl


https://github.com/user-attachments/assets/1f81b674-1628-4763-ad66-5f3ed7a3f159




## Downloads
<a href="https://play.google.com/store/apps/details?id=de.jonasbark.swiftcontrol"><img width="270" height="80" alt="GetItOnGooglePlay_Badge_Web_color_English" src="https://github.com/user-attachments/assets/a059d5a1-2efb-4f65-8117-ef6a99823b21" /></a>
<a href="https://apps.apple.com/us/app/swiftcontrol/id6753721284"><img width="270" height="80" alt="App Store" src="https://github.com/user-attachments/assets/c23f977a-48f6-4951-811e-ae530dbfa014" /></a>
<a href="https://apps.apple.com/us/app/swiftcontrol/id6753721284"><img width="270" height="80" alt="Mac App Store" src="https://github.com/user-attachments/assets/b3552436-409c-43b0-ba7d-b6a72ae30ff1" /></a>


Get the latest version for Windows here: https://github.com/jonasbark/swiftcontrol/releases

## Supported Apps
- MyWhoosh
- indieVelo / Training Peaks
- Biketerra.com
- any other! Customize touch points or keyboard shortcuts to your liking

## Supported Devices
- Zwift Click
- Zwift Click v2 (mostly, see issue #68)
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
- iOS (iPhone, iPad)
  - Note that you can't run SwiftControl and your trainer app on the same iPhone due to iOS limitations, but you can use it to remotely control MyWhoosh and similar on e.g. an iPad.

## Troubleshooting
Check the troubleshooting guide [here](TROUBLESHOOTING.md).

## How does it work?
The app connects to your Zwift device automatically. It does not connect to your trainer itself.

- **Android**: SwiftControl uses the AccessibilityService API to simulate touch gestures on specific parts of your screen to trigger actions in training apps. The service monitors which training app window is currently active to ensure gestures are sent to the correct app.
- **macOS** / **Windows** a keyboard or mouse click is used to trigger the action. 
  - there are predefined Keymaps for MyWhoosh, indieVelo / Training Peaks, and others
  - you can also create your own Keymaps for any other app
  - you can also use the mouse to click on a certain part of the screen, or use keyboard shortcuts
- **iOS**: use SwiftControl as "remote control" for other devices, such as an iPad. Example scenario:
    - your phone (Android/iOS) runs SwiftControl and connects to your Zwift devices
    - your iPad or other tablet runs e.g. MyWhoosh (does not need to have SwiftControl installed)
    - after pairing SwiftControl to your iPad / tablet via Bluetooth your phone will send the button presses to your iPad / tablet

## Alternatives
- [qdomyos-zwift](https://www.qzfitness.com/) directly controls the trainer (as opposed to controlling the trainer app). This can be useful if your trainer app does not support virtual shifting.

## Donate
Please consider donating to support the development of this app :)

- [via PayPal](https://paypal.me/boni)
- [via Credit Card, Google Pay, Apple Pay, etc (USD)](https://donate.stripe.com/8x24gzc5c4ZE3VJdt36J201)
- [via Credit Card, Google Pay, Apple Pay, etc (EUR)](https://donate.stripe.com/9B6aEX0muajY8bZ1Kl6J200)
