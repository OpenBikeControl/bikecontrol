## 1.0.0

- Initial release.
- Added support for creating multiple Flutter windows on macOS.
- Added communication between windows using MethodChannel.
- Added notifyUiRendered to prevent blank screen flashes.
- Added registerListener/unregisterListener APIs for Dart-side communication.
- Added broadcastToAllWindows native implementation.


## 1.0.1

- Formatted and updated README.md with detailed usage instructions and screenshots.
- Added usage of window manager in the main screen to handle window.

## 1.0.2
- Fixed image links in README.md

## 1.0.3
- Updated README.md

## 1.0.5
### Major Improvements
- **Added Windows Support**: Full native Windows implementation with multi-window support
- **Window Title Management**: Generate unique window titles automatically with `generateUniqueTitle`, `registerWindowTitle`, and `unregisterWindowTitle` methods
- **Enhanced Focus Handling**: 
  - macOS: Added `windowDidBecomeKey` delegate for proper render pipeline resumption
  - Windows: Added `WM_ACTIVATE` and `WM_SETFOCUS` handlers to prevent frozen windows
- **Improved Window Lifecycle**: 
  - macOS: Delayed cleanup for secondary windows to allow Flutter callbacks to execute
  - Windows: Better engine shutdown and messenger cleanup
- **Custom Window Styling** (Windows): Support for borderless windows with custom title bar (40px draggable area)
- **Dock Icon Handling** (macOS): Added `applicationShouldHandleReopen` to restore hidden windows
- **Code Quality**: Added explicit `return` statements in all method handlers for better control flow

### Bug Fixes
- Fixed lambda capture issue in Windows FlutterWindow (changed `[&]` to `[this]`)
- Improved controller validation in Windows implementation
- Fixed window activation and focus issues on both platforms
- Better messenger tracking and cleanup

### Breaking Changes
- None - fully backward compatible