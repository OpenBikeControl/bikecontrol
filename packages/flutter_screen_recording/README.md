# flutter_screen_recording

Flutter plugin to record the screen on Android, iOS, and web.

Current platform support in this repository:

- Android: `minSdkVersion 23`
- iOS: `iOS 11.0+`
- Web: supported through the federated web implementation

## Getting Started

Import the package:

```dart
import 'package:flutter_screen_recording/flutter_screen_recording.dart';
```

Start screen recording:

```dart
final bool started = await FlutterScreenRecording.startRecordScreen(
  'my_recording',
  titleNotification: 'Screen recording',
  messageNotification: 'Recording in progress',
);
```

Start screen recording with microphone audio:

```dart
final bool started = await FlutterScreenRecording.startRecordScreenAndAudio(
  'my_recording',
  titleNotification: 'Screen recording',
  messageNotification: 'Recording in progress',
);
```

Stop recording and get the output path or file name:

```dart
final String path = await FlutterScreenRecording.stopRecordScreen;
```

## Android

The Android implementation uses `MediaProjection`, `MediaRecorder`, and a foreground service.

- The plugin currently builds with `compileSdkVersion 35`
- The plugin manifest already includes its service declaration and required foreground-service permissions
- If you record audio, request microphone permission at runtime in your app
- On modern Android versions, you may also need notification permission for the foreground service notification

The example app requests permissions with `permission_handler` before starting recording.

## iOS

The iOS implementation uses `ReplayKit` and requires `iOS 11.0+`.

Add the usage description for microphone access if you record audio:

```xml
<key>NSMicrophoneUsageDescription</key>
<string>Save audio in video</string>
```

The plugin returns the local output file path. If your app later saves the file to the Photos library, also add the appropriate Photos usage description to your app.

## Web

The web implementation uses `getDisplayMedia` and `MediaRecorder`.

- Best experience is on modern desktop browsers
- Browser support depends on screen-capture and codec support
- The web implementation downloads the recorded file in the browser when recording stops

## Notes

- This package exposes asynchronous APIs; use `await` when starting and stopping recordings
- Notification title and message parameters are used by the Android implementation
- Returned output differs by platform: native platforms return a local path, while web triggers a browser download
