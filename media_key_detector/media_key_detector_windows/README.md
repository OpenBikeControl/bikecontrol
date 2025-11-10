# media_key_detector_windows

[![style: very good analysis][very_good_analysis_badge]][very_good_analysis_link]

The windows implementation of `media_key_detector`.

## Features

This plugin provides global media key detection on Windows using the Windows `RegisterHotKey` API. This allows your application to respond to media keys (play/pause, next track, previous track) even when it's not the focused application.

### Supported Media Keys

- Play/Pause (VK_MEDIA_PLAY_PAUSE)
- Next Track (VK_MEDIA_NEXT_TRACK)
- Previous Track (VK_MEDIA_PREV_TRACK)

### Implementation Details

The plugin uses:
- `RegisterHotKey` Windows API for global hotkey registration
- Event channels for communicating media key events to Dart
- Window message handlers to process WM_HOTKEY messages

Hotkeys are registered when `setIsPlaying(true)` is called and automatically unregistered when `setIsPlaying(false)` is called or when the plugin is destroyed.

## Usage

This package is [endorsed][endorsed_link], which means you can simply use `media_key_detector`
normally. This package will be automatically included in your app when you do.

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
  }
});
```

[endorsed_link]: https://flutter.dev/docs/development/packages-and-plugins/developing-packages#endorsed-federated-plugin
[very_good_analysis_badge]: https://img.shields.io/badge/style-very_good_analysis-B22C89.svg
[very_good_analysis_link]: https://pub.dev/packages/very_good_analysis
