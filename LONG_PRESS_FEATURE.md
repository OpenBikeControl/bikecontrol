# Long Press Mode Feature Documentation

## Overview
The Long Press Mode feature allows users to configure custom keymap buttons to behave as sustained key presses instead of repeated key taps. This is particularly useful for applications like games where continuous movement requires holding down a key.

## How It Works

### Regular Mode (Default Behavior)
- Button press triggers immediate key down + key up
- If button is held, repeats key down + key up every 250ms
- Perfect for discrete actions like shifting gears or menu navigation

### Long Press Mode (New Feature)
- Button press triggers key down only
- Key remains "held down" until button is released
- Button release triggers key up
- No repeated key presses while held
- Perfect for movement controls, steering, or any sustained action

## Implementation Details

### Core Changes
1. **KeyPair Class**: Added `isLongPress` boolean property
2. **DesktopActions**: Tracks held keys and handles separate key down/up operations
3. **BaseDevice**: Detects button release events to trigger key up
4. **UI**: Added checkbox to configure long press mode per button

### State Management
- `DesktopActions._heldKeys` tracks which buttons are currently pressed in long press mode
- Button release detection ensures proper key up events
- Cleanup methods available to release all held keys if needed

## User Interface

### Configuration
1. Select "Custom" keymap in the main interface
2. Click "Customize Keymap" 
3. Right-click on any configured button
4. Check "Long Press Mode" in the popup menu

### Visual Indicators
- Long press enabled buttons show a green border
- Icon changes to double-arrow-down to indicate long press mode
- "Long Press" label appears under the button configuration

### Example Use Case
A user wants to control avatar movement in a game:
1. Configure a Zwift button to send the 'W' key (forward movement)
2. Enable "Long Press Mode" for that button
3. Now pressing and holding the Zwift button will:
   - Send 'W' key down when pressed
   - Keep 'W' held down while button is held
   - Send 'W' key up when button is released
   - Perfect for smooth, continuous movement

## Backward Compatibility
- Existing keymaps continue to work unchanged (default isLongPress = false)
- Legacy encoded keymaps are automatically upgraded with isLongPress = false
- No breaking changes to existing functionality

## Technical Notes
- Long press mode only applies to keyboard keys, not touch positions or media keys
- The 250ms repeat timer is bypassed in long press mode to prevent conflicts
- Proper cleanup ensures no "stuck" keys if connection is lost