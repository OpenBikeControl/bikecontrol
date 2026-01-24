# BikeControl Feature Ideas

This document contains potential feature ideas and enhancements for BikeControl.

> **Note**: BikeControl is a controller bridge app focused on connecting physical controllers to trainer apps. Ideas should align with this core mission of input mapping and control simulation.

## 🎮 Controller & Device Support

### New Device Support
- **Garmin Edge Integration**: Support for Garmin Edge cycling computers to control trainer apps via ANT+ or Bluetooth
- **Apple Watch Control**: Add Apple Watch companion app for quick button actions during rides
- **Additional ANT+ Devices**: Support for ANT+ LEV (e-bike) controllers and other ANT+ button devices
- **Logitech Gaming Controllers**: Enhanced support for Logitech racing wheels and button boxes
- **Stream Deck Integration**: Support for Elgato Stream Deck buttons for desktop control
- **MIDI Controllers**: Use MIDI button pads and controllers as input devices

### Enhanced Controller Features
- **Controller Battery Monitoring**: Display battery levels for all connected Bluetooth devices with low battery warnings
- **Connection Profiles**: Quick-switch between different device configurations (e.g., "Zwift Click only" vs "Di2 + Sterzo")
- **Button Remapping Templates**: Pre-configured button layouts for different hand positions or use cases
- **Hold/Long-Press Actions**: Configure different actions for long-press vs short-press on the same button
- **Multi-Button Combos**: Support simultaneous button presses (e.g., left + right = uturn)

## 🎯 Trainer App Integration

### Enhanced Control Actions
- **Quick Action Sequences**: Record and replay sequences of button presses (e.g., "navigate to workout menu and start")
- **Conditional Button Mapping**: Change button behavior based on which app is focused
- **Timed Actions**: Schedule button presses at specific intervals (e.g., auto-steer corrections every 10 seconds)
- **Rapid Fire Mode**: Repeat a button action multiple times with configurable delay
- **Mouse Gesture Support**: Record and replay mouse gestures for apps that don't support keyboard shortcuts

### App-Specific Enhancements
- **TrainerRoad Integration**: Add native support for TrainerRoad controls
- **Bkool Support**: Add button mappings for Bkool simulator
- **FulGaz Integration**: Native support for FulGaz controls
- **IndieVelo Support**: Add mappings for IndieVelo actions
- **Systm (formerly Sufferfest)**: Add control mappings for Wahoo Systm app

## 📱 User Experience

### Interface Improvements
- **Quick Setup Wizard**: Streamlined setup for common device + app combinations
- **Connection Status Dashboard**: Visual indicators for all connected devices with signal strength
- **Widget Support**: Home screen widgets showing connection status and quick reconnect buttons
- **Landscape/Portrait Optimization**: Better layouts for both orientations on tablets
- **Color-Blind Friendly Mode**: Alternative color schemes for accessibility
- **Button Test Mode**: Test button presses without connecting to trainer app

### Configuration Management
- **Cloud Backup**: Backup and restore button configurations across devices
- **QR Code Sharing**: Share configurations via QR codes for quick setup
- **Configuration Versioning**: Track and revert to previous configuration versions
- **Search in Settings**: Quick search functionality for finding specific settings
- **Favorites/Bookmarks**: Mark frequently used settings for quick access

## 🔧 Advanced Features

### Automation & Integration
- **AutoHotkey Integration** (Windows): Export button mappings as AutoHotkey scripts for advanced customization
- **Keyboard Maestro Support** (macOS): Create Keyboard Maestro macros triggered by BikeControl buttons
- **Accessibility Improvements**: Better integration with platform accessibility APIs for more reliable control
- **Multi-Window Control**: Send inputs to specific windows/apps when multiple are open
- **Focus Management**: Auto-focus the trainer app window when a button is pressed

### Customization
- **Scripting Engine**: Simple scripting language for complex button sequences (e.g., "press A, wait 500ms, press B")
- **Macro Recording**: Record sequences of actions and replay with a single button press
- **Conditional Actions**: Configure actions based on conditions (e.g., "if in Zwift menu, do X, else do Y")
- **Variable Delays**: Configurable delays between repeated button presses
- **Export/Import Configurations**: Share custom configurations with the community as JSON files
- **Regex-based App Matching**: Use window title patterns to auto-switch configurations

## 🎮 Input Simulation Enhancements

### Keyboard & Mouse Control
- **Unicode Character Support**: Send special characters and symbols to trainer apps
- **Mouse Wheel Simulation**: Support mouse wheel actions for apps that use scroll controls
- **Multi-Key Combinations**: Support complex key combinations (Ctrl+Shift+Alt+Key)
- **Dead Key Support**: Support for international keyboard layouts with dead keys
- **Clipboard Integration**: Copy/paste actions triggered by controller buttons
- **Drag and Drop**: Simulate drag-and-drop actions with button sequences

### Touch & Gesture Simulation
- **Multi-Touch Gestures**: Pinch to zoom, two-finger scroll, etc.
- **Swipe Actions**: Configure swipe directions and speeds
- **Touch and Hold**: Long-press touch actions with configurable duration
- **Touch Coordinate Precision**: Fine-tune touch positions with sub-pixel accuracy
- **Relative vs Absolute Touch**: Choose between relative (from current position) or absolute touch coordinates

## 🔌 Accessory Control

### Fan Control Enhancements (Beyond KICKR HEADWIND)
- **Generic Smart Fan Support**: Control any WiFi/Bluetooth smart fan (Lasko, Vornado, etc.)
- **Fan Curve Customization**: Create custom speed curves based on button presses
- **Multiple Fan Control**: Independently control multiple fans with different buttons
- **Fan Oscillation**: Toggle oscillation mode on/off
- **Fan Timer**: Auto-shut-off after configurable duration

### Other Smart Accessories
- **Smart Trainer Direct Control**: Send direct commands to smart trainers (resistance, simulation mode)
- **RGB Lighting Control**: Control LED strips or smart bulbs to indicate intensity zones
- **Power Outlet Control**: Turn equipment on/off via smart plugs
- **Audio System Control**: Volume and source switching for home audio systems
- **Camera Control**: Trigger action cameras for recording specific moments

## 🛡️ Reliability & Diagnostics

### Connection Reliability
- **Auto-Reconnect**: Automatically reconnect to devices that disconnect
- **Connection Quality Monitor**: Show signal strength and connection stability
- **Fallback Modes**: Automatically switch connection methods if primary fails
- **Connection Logging**: Detailed logs of connection events for troubleshooting
- **Bluetooth Range Indicator**: Warn when devices are getting out of range

### Diagnostics & Testing
- **Input Latency Meter**: Measure and display button-to-action latency
- **Button Response Test**: Test individual buttons to verify they're working
- **Connection Speed Test**: Measure network latency for remote connections
- **Device Firmware Info**: Display firmware versions of connected devices
- **Compatibility Checker**: Verify device compatibility before attempting connection
- **Debug Mode**: Verbose logging for troubleshooting connection issues

## 🌍 Community Configuration Sharing

### Configuration Marketplace
- **Community Config Library**: Browse and download button mappings shared by other users
- **Rating System**: Rate and review configurations
- **Configuration Comments**: Allow users to comment on shared configs with tips
- **Version Tracking**: Track updates to shared configurations
- **Search and Filter**: Find configurations by device, app, or use case
- **One-Click Install**: Import configurations with a single click

### Collaboration
- **Configuration Templates**: Official templates for common setups maintained by BikeControl team
- **Device-Specific Defaults**: Crowd-sourced optimal configurations for each device type
- **App Update Notifications**: Notify when trainer apps change and configurations need updates
- **Compatibility Tags**: Tag configurations with compatible devices and app versions

## 🔄 Platform-Specific Enhancements

### Android Specific
- **Tasker Integration**: Deep integration with Tasker for advanced automation
- **Intent Broadcasting**: Broadcast button press events that other apps can listen to
- **Quick Settings Tile**: Toggle BikeControl connection from quick settings
- **Accessibility Service Enhancements**: More reliable touch simulation using accessibility APIs
- **Scoped Storage Optimization**: Better file management for configurations

### iOS/iPadOS Specific
- **Shortcuts Support**: Create custom Siri Shortcuts for common actions
- **Widget Support**: Interactive widgets for device connection control
- **Focus Mode Integration**: Auto-enable workout focus mode during rides
- **Split View Optimization**: Better layout when used in split-screen mode
- **Handoff Support**: Continue configuration on another Apple device

### Windows/macOS Specific
- **System Tray/Menu Bar**: Quick access to common functions from system tray/menu bar
- **Global Hotkeys**: Configure keyboard shortcuts to control BikeControl from any app
- **Multi-Monitor Awareness**: Better window positioning on multi-monitor setups
- **Focus Stealing Prevention**: Prevent trainer apps from stealing focus from BikeControl
- **Power Management**: Prevent sleep mode during active connections

## 📚 Documentation & Support

### Help System
- **Interactive Troubleshooting**: Step-by-step guided troubleshooting wizard for common connection issues
- **Video Tutorials**: In-app video tutorials for setting up different devices
- **Contextual Help**: Context-sensitive help tooltips throughout the app
- **Device-Specific Guides**: Detailed setup guides for each supported device
- **Live Chat Support**: In-app chat support for premium users

### Localization
- **More Languages**: Add support for Spanish, Portuguese, Chinese, Japanese, Dutch, Swedish, Danish, Norwegian
- **Right-to-Left Support**: Full support for RTL languages like Arabic and Hebrew
- **Regional Settings**: Adapt to local conventions and terminology
- **Community Translations**: Allow community to contribute translations

## 💡 Developer & Integration Features

### API & Extensions
- **Public API**: RESTful API for third-party apps to trigger BikeControl actions
- **Webhook Support**: Send events to external services when buttons are pressed
- **Plugin System**: Allow developers to create plugins for custom functionality
- **Command Line Interface**: CLI tool for automation and scripting
- **Web Interface**: Browser-based configuration and monitoring

### Developer Tools
- **Button Mapping Validator**: Verify button mappings work correctly before saving
- **Event Logger**: Real-time log of all button events and actions
- **Performance Profiler**: Measure latency and performance of button mappings
- **Mock Device Mode**: Test configurations without physical devices
- **Configuration Diff Tool**: Compare two configurations to see differences

---

## Contributing Ideas

Have more ideas? Feel free to:
1. Open an issue on GitHub with the "enhancement" label
2. Join the discussion in our community forums
3. Submit a pull request adding to this document
4. Contact us through the app's feedback feature

## Prioritization

Features in this document are ideas and not commitments. Prioritization will be based on:
- User demand and feedback
- Technical feasibility
- Alignment with BikeControl's core mission as a controller bridge
- Platform compatibility
- Development resources

## Out of Scope

The following types of features are **outside BikeControl's scope** as a controller bridge app:
- Performance tracking and analytics (power zones, FTP, training load)
- Social features (forums, leaderboards, ride sharing)
- Health monitoring (HRV, recovery tracking, injury prevention)
- Training platform features (workout creation, coaching, training plans)
- Content creation (video recording, highlights, telemetry overlays)
- Data storage and analysis of ride metrics

BikeControl focuses on **control** - connecting your physical controllers to trainer apps. For analytics and training features, use dedicated platforms like TrainingPeaks, Strava, or your trainer app's built-in features.

---

*Last updated: January 2026*
*Document maintained by the BikeControl community*
