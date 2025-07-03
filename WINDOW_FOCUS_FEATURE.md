# Window-Focused Key Simulation Feature

## Overview

This feature addresses the issue where users need to manually focus on training application windows (like MyWhooshHD) to receive key presses from Zwift controllers. With this implementation, key presses are sent directly to the target application window even when it's not in focus.

## How It Works

### For Windows Users
- The application automatically detects supported training apps by their process name
- Key presses are sent directly to the target window using Windows messaging
- If the target window is not found, it falls back to global key simulation

### Supported Applications
- **MyWhoosh**: Targets `MyWhooshHD.exe` process
- **IndieVelo/TrainingPeaks**: Targets `indieVelo.exe` process
- **Biketerra**: Targets `biketerra.exe` process
- **Custom Apps**: Use global key simulation (no window targeting)

### For Other Platforms
- macOS and Linux automatically fall back to the existing global key simulation
- No changes in behavior for non-Windows platforms

## Usage

1. **Start your training application** (e.g., MyWhooshHD)
2. **Start SwiftControl** and connect your Zwift device
3. **Select the appropriate application** in SwiftControl settings
4. **Use your Zwift controller** - keys will be sent directly to the training app
5. **Keep focus on other applications** (like Chrome for YouTube) while training

## Testing the Feature

### Manual Testing
1. Open MyWhooshHD (or another supported training app)
2. Open another application (like a web browser) and keep it in focus
3. Use SwiftControl with a Zwift device to send key presses
4. Verify that the training app responds to the key presses even though it's not focused

### Expected Behavior
- **With window targeting**: Keys go directly to the training app regardless of focus
- **Without window targeting**: Keys go to whatever application has focus (previous behavior)
- **App not found**: Automatic fallback to global key simulation

## Technical Details

### Windows Implementation
- Uses `EnumWindows` to find target application windows
- Identifies applications by process name (e.g., "MyWhooshHD.exe")
- Sends keys via `PostMessage` with `WM_KEYDOWN`/`WM_KEYUP` messages
- Falls back to `SendInput` for global simulation when needed

### Error Handling
- Graceful fallback if target window is not found
- Cross-platform compatibility maintained
- Proper parameter validation and error reporting

## Configuration

Applications are automatically configured with their target process names:

```dart
// MyWhoosh configuration
MyWhoosh() : super(
  name: 'MyWhoosh',
  packageName: "com.mywhoosh.whooshgame",
  windowsProcessName: "MyWhooshHD.exe",  // New: Windows process targeting
  windowsWindowTitle: "MyWhooshHD",      // New: Window title targeting
  keymap: Keymap(...)
);
```

## Troubleshooting

### Key presses not reaching the training app
1. Verify the training app is running
2. Check that you've selected the correct app in SwiftControl
3. Try manually focusing the training app to test normal key mapping
4. Check Windows Task Manager to verify the correct process name

### Fallback behavior
- If window targeting fails, the system automatically falls back to global key simulation
- This ensures the feature degrades gracefully and maintains existing functionality

## Future Enhancements

Potential improvements for this feature:
- Support for targeting by window class name
- Configuration UI for custom process names
- Real-time feedback on window targeting status
- Support for multiple instances of the same application