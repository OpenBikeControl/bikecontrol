# Changelog Integration - Implementation Summary

This document describes the changelog integration feature that was implemented.

## Overview

The changelog integration adds three main features:
1. A "Changelog" screen that displays the full changelog history
2. Automatic display of a changelog dialog when the app is opened with a new version for the first time
3. A script to extract the latest changelog entry for Play Store uploads

## Components Created

### 1. Changelog Parser (`lib/utils/changelog.dart`)
- Parses `CHANGELOG.md` file to extract version entries
- Each entry contains: version number, date, and list of changes
- Supports parsing of main bullet points and sub-bullet points
- Provides methods to:
  - `parse()`: Load and parse the entire changelog
  - `getLatestEntry()`: Get just the latest version entry
  - `getLatestEntryForPlayStore()`: Format latest entry for Play Store uploads

### 2. Changelog Page (`lib/pages/changelog.dart`)
- Full-screen page displaying all changelog entries in a scrollable list
- Each entry is displayed in a card with:
  - Version number and date in the header
  - List of changes as bullet points
- Accessible from the menu

### 3. Changelog Dialog (`lib/widgets/changelog_dialog.dart`)
- Shows a "What's New" dialog with the latest changelog entry
- Automatically displayed when:
  - The app is opened for the first time after an update
  - The stored version differs from the current version
- Uses `SharedPreferences` to track the last seen version

### 4. Version Tracking (updated `lib/utils/settings/settings.dart`)
- Added `getLastSeenVersion()`: Retrieve the last version the user saw
- Added `setLastSeenVersion(version)`: Update the stored version
- Modified `setApp()` to be async (properly awaited in all call sites)

### 5. Menu Integration (updated `lib/widgets/menu.dart`)
- Added "Changelog" menu item to the popup menu
- Opens the changelog page when clicked

### 6. Auto-display Logic (updated `lib/pages/requirements.dart`)
- Added `_checkAndShowChangelog()` method
- Called on app initialization to check for version changes
- Shows changelog dialog if version has changed
- Updates stored version after display

### 7. Play Store Script (`scripts/get_latest_changelog.sh`)
- Bash script to extract latest changelog entry
- Formats output with bullet points suitable for Play Store
- Usage: `./scripts/get_latest_changelog.sh`

### 8. Tests (`test/changelog_test.dart`)
- Unit tests for the changelog parser
- Tests parsing of various changelog formats
- Tests edge cases (empty content, single entry, etc.)

## Usage

### For Users
1. **View Full Changelog**: Open the menu (three dots) → "Changelog"
2. **What's New Dialog**: Shown automatically after updating the app

### For Developers
1. **Add New Changelog Entry**: Edit `CHANGELOG.md` following the existing format:
   ```markdown
   ### VERSION (DATE)
   - Change description
   - Another change
     - Sub-bullet point
   ```

2. **Extract Latest Entry for Play Store**:
   ```bash
   ./scripts/get_latest_changelog.sh
   ```
   Copy the output to Play Store release notes.

## Technical Details

### Changelog Format
The parser expects entries in this format:
```markdown
### VERSION (DATE)
- Change 1
- Change 2
  - Sub-change 2.1
```

### Version Tracking
- Stored in SharedPreferences with key `'last_seen_version'`
- Compared with `PackageInfo.version` to detect updates
- Dialog shown only when versions differ (after initial install)

### Asset Bundling
The `CHANGELOG.md` file is bundled with the app by adding it to `pubspec.yaml`:
```yaml
flutter:
  assets:
    - CHANGELOG.md
```

## Files Modified

1. `lib/pages/requirements.dart` - Added changelog dialog auto-display
2. `lib/utils/settings/settings.dart` - Added version tracking methods
3. `lib/widgets/menu.dart` - Added changelog menu item
4. `lib/pages/device.dart` - Updated setApp calls to await
5. `pubspec.yaml` - Added CHANGELOG.md as asset

## Files Created

1. `lib/utils/changelog.dart` - Changelog parser
2. `lib/pages/changelog.dart` - Changelog display page
3. `lib/widgets/changelog_dialog.dart` - What's New dialog
4. `scripts/get_latest_changelog.sh` - Play Store extraction script
5. `scripts/README.md` - Scripts documentation
6. `test/changelog_test.dart` - Parser tests

## Testing

Run tests with:
```bash
flutter test test/changelog_test.dart
```

## Future Enhancements

Possible improvements:
- Add search/filter functionality to changelog page
- Add markdown rendering for richer formatting
- Add deep links to specific changelog entries
- Add analytics to track which changelog entries users read
