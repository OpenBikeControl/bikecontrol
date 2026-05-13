multi_window_native

A Flutter plugin that enables native multi-window support on macOS and Windows.
It allows you to create and manage multiple Flutter windows, communicate between them, and synchronize UI state across windows.
This package requires the use of window manager to handle multiple windows individually.

✨ Features

1. **Multi-Platform Support**: Native implementation for both macOS and Windows.

2. **Create Multiple Windows**: Create new secondary Flutter windows with custom routes and themes.

3. **Inter-Window Communication**: Broadcast messages between windows using method channels.

4. **Window Title Management**: Generate unique window titles automatically.


5. **Theme & Route Arguments**: Pass theme and route arguments when creating windows.

6. **Dart-Side Listeners**: Listen for updates via `registerListener` / `unregisterListener`.

7. **Automatic Plugin Registration**: Automatically registers plugins for each new window engine.

8. **Robust Lifecycle Management**: Proper window cleanup and engine shutdown.

🚀 Installation

Add to your `pubspec.yaml`:

```yaml
dependencies:
multi_window_native: ^1.0.5
```

Then run:

```sh
flutter pub get
```

🖼️ Screenshots

![Main window](https://raw.githubusercontent.com/Swatimishra8/multi_window_native/develop/example/assets/images/main_window.png)
*Main window with multi-window support*

![Secondary window](https://raw.githubusercontent.com/Swatimishra8/multi_window_native/develop/example/assets/images/new_window.png)
*Example of a secondary window opened by the plugin*

🛠️ Setup

### macOS

No extra setup required. The plugin will automatically:

- Register plugins for newly created window engines.
- Keep track of all FlutterBinaryMessenger instances for broadcasting.
- Handle window focus and activation events.
- Manage dock icon clicks to restore hidden windows.

### Windows

No extra setup required. The plugin will automatically:

- Register plugins for newly created window engines.
- Manage window messengers for cross-window communication.
- Handle window activation and focus to prevent freezing.
- Support custom window styling (optional).

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

### Window Management

**`createWindow(List<String> args)`**: Creates a new Flutter window with route, arguments, and theme.

**`closeWindow()`**: Closes the current window.

**`notifyUiRendered()`**: Informs native that the window is ready to display.

### Window Title Management (New in v1.1.0)

**`generateUniqueTitle(String baseTitle)`**: Generates a unique window title by appending a numeric suffix.

**`registerWindowTitle(String title)`**: Registers a window title as used.

**`unregisterWindowTitle(String title)`**: Unregisters a window title when window closes.

### Communication

**`notifyAllWindows(String method, dynamic arguments)`**: Broadcasts a method call to all windows.

**`registerListener(String method, MethodCallHandler handler)`**: Registers a listener for method calls from native. Returns an id.

**`unregisterListener({required String methodName, required String id})`**: Unregisters a specific listener by method and id.

**`getMessengerCount()`**: Returns the number of active window messengers.

📌 Notes

- **Platform Support**: Fully supports macOS and Windows with native implementations.

- **Linux Support**: May be added in future releases.

- **Multiple Engines**: Each secondary window runs its own Flutter engine.

- **Focus Management**: Automatic handling of window activation and focus events to prevent UI freezing.

- **Window Lifecycle**: Proper cleanup and shutdown of engines when windows close.

- **Custom Styling**: Windows version supports custom borderless windows with draggable title bars.

- **Performance**: Optimized messenger tracking and broadcasting for efficient inter-window communication.

## 🤝 Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## 📞 Support

For issues, feature requests, or questions, please file an issue on the [GitHub repository](https://github.com/Swatimishra8/multi_window_native/issues).

📄 License

MIT License. See LICENSE for details.