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
<a href="https://play.google.com/store/apps/details?id=de.jonasbark.swiftcontrol"><img src="https://storage.googleapis.com/pe-portal-consumer-prod-wagtail-static/images/googleplay-badge-01-getit.max-1920x1070.format-webp.webp?X-Goog-Algorithm=GOOG4-RSA-SHA256&X-Goog-Credential=wagtail%40pe-portal-consumer-prod.iam.gserviceaccount.com%2F20250925%2Fauto%2Fstorage%2Fgoog4_request&X-Goog-Date=20250925T084315Z&X-Goog-Expires=86400&X-Goog-SignedHeaders=host&X-Goog-Signature=6eab941e460ae5973f162ce5740adf1e71cf8dd47fd5a9ba60ec673d31f807b0bea359f123a5f5151eb2315fac9c2aa641886e9fda8c545837274a04ca2e8c3217f54495f3b225ecf55a1ba1a34fe52836562583f387c62a4e140c64d1a13094d455a157df514bf7ea088ec2a2aa294ec5e594aea873ab3b63fc9f6d586ac15c04a0d05a4ec557bcb9cb9de48087508219ebf4bc5686dd8051c9949024baba1933cecdc6035b3766ff9fb9a9dd0c3418b225c155173d3b6911043244966a9df1f06ede2c5128fa7625d168c0c4bebf4e9b4c47439b4056c9fe9056e07399e85f3d875ac3478224e226d778fe8d9e7a8d54cae1a7dceb36494aa0326477ca7ffd" width="220"></a>

Get the latest version for free here: https://github.com/jonasbark/swiftcontrol/releases

## Supported Apps
- MyWhoosh
- indieVelo / Training Peaks
- Biketerra.com
- any other: 
  - Android: you can customize simulated touch points of all your buttons in the app
  - Desktop: you can customize keyboard shortcuts and mouse clicks in the app

## Supported Devices
- Zwift Click
- Zwift Click v2
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
- [via CreditCard (USD)](https://donate.stripe.com/8x24gzc5c4ZE3VJdt36J201)
- [via CreditCard (EUR)](https://donate.stripe.com/9B6aEX0muajY8bZ1Kl6J200)
