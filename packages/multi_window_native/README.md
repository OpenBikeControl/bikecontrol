multi_window_native

A Flutter plugin that enables native multi-window support on macOS and Windows.
It allows you to create and manage multiple Flutter windows, communicate between them, and synchronize UI state across windows.
This package requires the use of window manager to handle multiple windows individually.

✨ Features

1. Create new secondary Flutter windows.

2. Broadcast messages between windows using method channels.

3. Pass theme & route arguments when creating windows.

4. Listen for updates via Dart-side listeners (registerListener / unregisterListener).

5. Automatically registers plugins for each new window engine.

6. Native macOS and Windows implementation with seamless Dart integration.

🚀 Installation

Add to your `pubspec.yaml`:

```yaml
dependencies:
multi_window_native: ^1.0.0
```

Then run:

```sh
flutter pub get
```

🖼️ Screenshots

In Windows - 
![Main window](https://raw.githubusercontent.com/Swatimishra8/multi_window_native/develop/example/assets/images/main_window.png)
*Main window with multi-window support*

![Secondary window](https://raw.githubusercontent.com/Swatimishra8/multi_window_native/develop/example/assets/images/new_window.png)
*Example of a secondary window opened by the plugin*

In Macos - 

![Main window](https://raw.githubusercontent.com/Swatimishra8/multi_window_native/develop/example/assets/images/main_window_mac.png)
*Main window with multi-window support*

![Secondary window](https://raw.githubusercontent.com/Swatimishra8/multi_window_native/develop/example/assets/images/second_window_mac.png)
*Example of a secondary window opened by the plugin*

Theme changes- 
![Both windows](https://raw.githubusercontent.com/Swatimishra8/multi_window_native/develop/example/assets/images/theme_change_mac.png)

🛠️ Setup (macOS)

No extra setup required. The plugin will automatically:

Register plugins for newly created window engines.

Keep track of all FlutterBinaryMessenger instances for broadcasting.

📖 Usage

Import the package:

```dart
import 'package:multi_window_native/multi_window_native.dart';
```

Create a new instance and window:

```dart
final _multiWindowNative = MultiWindowNative();

void _openWindow() async {
  await _multiWindowNative.createWindow([
    'secondScreen', // Route name
    '{}', // Arguments as JSON string
    'light' // Theme mode
  ]);
}

```

To access window IDs, initialize the window manager early in your app. It offers methods such as windowFocus and windowClose to manage window lifecycle events like focusing and closing windows.

```dart
await windowManager.ensureInitialized();
```

Notify native when UI is ready to be rendered:
The secondary window screen should call this in init state to notify native.
NOTE - Its an mandatory step to avoid black screen issues.

```dart
@override
void initState() {
  super.initState();
  WidgetsBinding.instance.addPostFrameCallback((_) async {
    await WidgetsBinding.instance.endOfFrame;
    await _multiWindowNative.notifyUiRendered();
  });
}
```

Communication between windows:

Send updates from Dart to native (and broadcast to all windows):

```dart
await _multiWindowNative.notifyAllWindows(
  "updateText",
  {"message": "Hello from Main Window"},
);
```

Listen for updates in each window:

```dart
late String _listenerId;
String _text = "";

@override
void initState() {
  super.initState();
  _listenerId = MultiWindowNative.registerListener("updateText", (call) async {
    setState(() {
      _text = (call.arguments as Map)['message'] ?? "";
    });
  });
}

@override
void dispose() {
  MultiWindowNative.unregisterListener(
    methodName: "updateText", id: _listenerId);
  super.dispose();
}
```

📊 API Reference

createWindow(List<String> args): Creates a new Flutter window with route, arguments, and theme.

closeWindow(): Closes the current window.

notifyUiRendered(): Informs native that the window is ready to display.

notifyAllWindows(String method, dynamic arguments): Broadcasts a method call to all windows.

registerListener(String method, MethodCallHandler handler): Registers a listener for method calls from native. Returns an id.

unregisterListener({required String methodName, required String id}): Unregisters a specific listener by method and id.

📌 Notes

Supports macOS and Windows both.

Linux support may be added in future releases.

Each secondary window runs its own Flutter engine.

📄 License

MIT License. See LICENSE for details.