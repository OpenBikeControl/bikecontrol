# 0.0.3

- **NEW**: Add device source detection using Windows Raw Input API
- Media key events now include unique device identifier
- Enables distinguishing between multiple bluetooth media controllers
- Adds `addListenerWithDevice` API for device-aware event handling
- Maintains backward compatibility with existing `addListener` API
- Falls back to RegisterHotKey API for compatibility

# 0.0.2

- Implement global media key detection using Windows RegisterHotKey API
- Add event channel support for media key events
- Media keys now work even when app is not focused
- Improved error handling for hotkey registration
- Added support for volume up and volume down hotkeys

# 0.0.1

- Initial Release
