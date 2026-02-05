# media_key_detector_windows

[![style: very good analysis][very_good_analysis_badge]][very_good_analysis_link]

The windows implementation of `media_key_detector`.

## Features

This plugin provides global media key detection on Windows with device source identification. This allows your application to respond to media keys (play/pause, next track, previous track, volume up, volume down) from multiple devices and distinguish which device sent each event.

### Supported Media Keys

- Play/Pause (VK_MEDIA_PLAY_PAUSE)
- Next Track (VK_MEDIA_NEXT_TRACK)
- Previous Track (VK_MEDIA_PREV_TRACK)
- Volume Up (VK_VOLUME_UP)
- Volume Down (VK_VOLUME_DOWN)

### Implementation Details

The plugin uses:
- **Raw Input API** for device-specific media key detection (primary method)
- `RegisterHotKey` Windows API for global hotkey registration (fallback)
- Event channels for communicating media key events with device information to Dart
- Window message handlers to process WM_INPUT and WM_HOTKEY messages

The Raw Input API allows the plugin to identify which physical device (e.g., keyboard, bluetooth remote) sent the media key event. This enables users with multiple media controllers to configure different actions for each device.

Hotkeys and raw input are registered when `setIsPlaying(true)` is called and automatically unregistered when `setIsPlaying(false)` is called or when the plugin is destroyed.

### Device Source Detection

When a media key is pressed, the plugin provides:
- The media key that was pressed (e.g., playPause, fastForward)
- The unique device identifier of the source device

This enables scenarios where:
- A user has two bluetooth media remotes
- Both remotes have a "play" button
- Each remote can be configured to trigger different actions

## Usage

This package is [endorsed][endorsed_link], which means you can simply use `media_key_detector`
normally. This package will be automatically included in your app when you do.

### Basic Usage (without device information)

```dart
import 'package:media_key_detector/media_key_detector.dart';

// Enable media key detection
mediaKeyDetector.setIsPlaying(isPlaying: true);

// Listen for media key events
mediaKeyDetector.addListener((MediaKey key) {
  switch (key) {
    case MediaKey.playPause:
      // Handle play/pause
      break;
    case MediaKey.fastForward:
      // Handle next track
      break;
    case MediaKey.rewind:
      // Handle previous track
      break;
    case MediaKey.volumeUp:
      // Handle volume up
      break;
    case MediaKey.volumeDown:
      // Handle volume down
      break;
  }
});
```

### Advanced Usage (with device identification)

```dart
import 'package:media_key_detector/media_key_detector.dart';

// Enable media key detection
mediaKeyDetector.setIsPlaying(isPlaying: true);

// Listen for media key events with device information
mediaKeyDetector.addListenerWithDevice((MediaKey key, String deviceId) {
  // deviceId contains the unique identifier of the device that sent the event
  // For example: "\\?\HID#VID_046D&PID_C52B&MI_00#..."
  
  print('Media key $key pressed by device: $deviceId');
  
  // Configure different actions based on device
  if (deviceId.contains('VID_046D')) {
    // Handle keys from Logitech device
    handleLogitechRemote(key);
  } else if (deviceId.contains('VID_05AC')) {
    // Handle keys from Apple device
    handleAppleKeyboard(key);
  } else {
    // Handle keys from other devices
    handleGenericDevice(key);
  }
});
```

[endorsed_link]: https://flutter.dev/docs/development/packages-and-plugins/developing-packages#endorsed-federated-plugin
[very_good_analysis_badge]: https://img.shields.io/badge/style-very_good_analysis-B22C89.svg
[very_good_analysis_link]: https://pub.dev/packages/very_good_analysis
