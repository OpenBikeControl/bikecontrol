# SwiftControl - Play Store Description

## Short Description
Control your favorite trainer app using Zwift Click, Zwift Ride or Zwift Play devices.

## Full Description

With SwiftControl you can control your favorite trainer app using your Zwift Click, Zwift Ride or Zwift Play devices. Here's what you can do with it, depending on your configuration:

- Virtual Gear shifting
- Steering / turning
- Adjust workout intensity
- Control music on your device
- More? If you can do it via keyboard, mouse or touch, you can do it with SwiftControl

## AccessibilityService API Usage

**Important Notice**: This app uses Android's AccessibilityService API to enable control of training applications through your Zwift devices.

**Why AccessibilityService is Required:**
- To simulate touch gestures on your screen that control trainer apps
- To detect which training app window is currently active
- To enable seamless control of apps like MyWhoosh, IndieVelo, Biketerra.com, and others

**How We Use AccessibilityService:**
- When you press buttons on your Zwift Click, Zwift Ride, or Zwift Play devices, SwiftControl translates these into touch gestures at specific screen locations
- The service monitors which training app window is active to ensure gestures are sent to the correct application
- NO personal data is accessed, collected, or transmitted through this service
- The service only performs the specific touch actions you configure within the app

**Privacy and Security:**
- SwiftControl only accesses your screen to perform the gestures you configure
- No other accessibility features or personal information is accessed
- All gesture configurations remain on your device
- The app does not connect to external services for accessibility functions

## How does it work?
The app connects to your Zwift device automatically via Bluetooth. It does not connect to your trainer itself.

- **Android**: Uses AccessibilityService API to simulate touch gestures on specific parts of your screen to trigger actions in training apps
- **Desktop**: Uses keyboard shortcuts and mouse clicks to control applications

## Supported Apps
- MyWhoosh
- IndieVelo / Training Peaks Virtual
- Biketerra.com
- Any other app: You can customize touch points (Android) or keyboard shortcuts (Desktop)

## Supported Devices
- Zwift Click
- Zwift Click v2
- Zwift Ride
- Zwift Play

## Supported Platforms
- Android (with AccessibilityService for gesture simulation)
- macOS
- Windows
- Web (limited functionality)

This app is not affiliated with or endorsed by Zwift, Inc.

## Permissions Required
- **Bluetooth**: To connect to your Zwift devices
- **AccessibilityService (Android only)**: To simulate touch gestures for controlling trainer apps
- **Notifications**: To keep the app running in the background
- **Location (Android 11 and below)**: Required for Bluetooth scanning on older Android versions