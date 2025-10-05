# Custom Profiles Feature

## Overview
This feature allows users to create and manage multiple custom keymap profiles for different activity types (e.g., Workout, Race, Event, Workout with Coach).

## Changes Made

### 1. CustomApp Class (`lib/utils/keymap/apps/custom_app.dart`)
- Added `profileName` field to support named profiles
- Each CustomApp instance can now have a unique name
- Constructor now accepts an optional `profileName` parameter (defaults to 'Custom')

### 2. Settings Class (`lib/utils/settings/settings.dart`)
- Modified storage mechanism to support multiple custom profiles
  - Old format: `customapp` → single profile
  - New format: `customapp_<profileName>` → multiple profiles
- Added `getCustomAppProfiles()` to retrieve all saved custom profiles
- Added `duplicateCustomAppProfile()` to copy profiles
- Added `deleteCustomAppProfile()` to remove profiles
- Implemented backward compatibility migration from old `customapp` key to new `customapp_Custom` key
- Exposed `prefs` getter for UI access

### 3. Device Page UI (`lib/pages/device.dart`)
- Added `_getAllApps()` method to dynamically build app list including all custom profiles
- Added "New Custom Profile" button to create new profiles
- Added "Manage Profile" button (visible when a CustomApp is selected) with options to:
  - Rename profile
  - Duplicate profile
  - Delete profile
- Updated dropdown menu to use dynamic app list

### 4. Dialog Helpers
Added several dialog methods to handle user interactions:
- `_showNewProfileDialog()` - Create new profile
- `_showManageProfileDialog()` - Select management action
- `_showRenameProfileDialog()` - Rename existing profile
- `_showDuplicateProfileDialog()` - Duplicate existing profile
- `_showDeleteConfirmDialog()` - Confirm deletion

## User Experience

### Creating a New Profile
1. Click "New Custom Profile" button
2. Enter a name (e.g., "Workout", "Race", "Event")
3. Customize the keymap using the "Customize Keymap" button
4. The profile is automatically saved

### Switching Between Profiles
- Use the dropdown menu to select any saved custom profile
- All predefined keymaps (MyWhoosh, TrainingPeaks, Biketerra) remain available

### Managing Profiles
1. Select a custom profile from the dropdown
2. Click "Manage Profile" button
3. Choose an action:
   - **Rename**: Change the profile name
   - **Duplicate**: Create a copy with a new name
   - **Delete**: Remove the profile (with confirmation)

## Backward Compatibility
- Existing users with a single custom keymap will have it automatically migrated to the new format as "Custom"
- No data loss during migration
- Old `customapp` key is removed after successful migration

## Testing
Comprehensive test suite added in `test/custom_profile_test.dart` covering:
- Profile creation with default and custom names
- Saving and retrieving profiles
- Listing multiple profiles
- Duplicating profiles
- Deleting profiles
- Migration from old format
- Prevention of duplicate migrations

## Storage Format
- **Profile keymaps**: `customapp_<profileName>` → List<String>
- **Current app**: `app` → String (profile name)
- Example:
  ```
  customapp_Workout: [...keymap data...]
  customapp_Race: [...keymap data...]
  customapp_Event: [...keymap data...]
  app: "Race"
  ```
