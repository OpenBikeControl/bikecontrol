# Quick Reference: Changelog Integration

## For End Users

### Viewing the Changelog
1. Open the app
2. Tap the menu button (⋮) in the top-right
3. Select "Changelog"
4. Browse through all version updates

### What's New Dialog
- Appears automatically when you update the app
- Shows the latest changes in the new version
- Tap "Got it!" to dismiss

## For Developers

### Adding a New Changelog Entry
Edit `CHANGELOG.md` and add a new entry at the top:
```markdown
### X.Y.Z (YYYY-MM-DD)
- Change description 1
- Change description 2
```

### Extracting for Play Store
```bash
./scripts/get_latest_changelog.sh > release_notes.txt
```
Then copy the contents to Play Store.

### Running Tests
```bash
flutter test test/changelog_test.dart
```

## Technical Details

### Files
- **Parser:** `lib/utils/changelog.dart`
- **Page:** `lib/pages/changelog.dart`
- **Dialog:** `lib/widgets/changelog_dialog.dart`
- **Settings:** `lib/utils/settings/settings.dart`
- **Script:** `scripts/get_latest_changelog.sh`
- **Tests:** `test/changelog_test.dart`

### SharedPreferences Key
- Key: `last_seen_version`
- Stores: Current app version (e.g., "2.6.0")
- Purpose: Track which version the user last saw

### Changelog Format
```markdown
### VERSION (DATE)
- Main bullet point
  - Sub-bullet point (2 spaces indent)
```

## Troubleshooting

### Dialog not showing?
- Check that CHANGELOG.md is in the assets
- Verify version number changed in pubspec.yaml
- Check SharedPreferences has `last_seen_version` key

### Script not working?
- Ensure script is executable: `chmod +x scripts/get_latest_changelog.sh`
- Check CHANGELOG.md exists and has correct format

### Parser errors?
- Verify CHANGELOG.md follows the format: `### VERSION (DATE)`
- Each entry must have this exact format
- Changes must start with `- ` or `  - `

## Key Benefits

✓ **For Users**: Always see what's new after updates
✓ **For Developers**: Easy Play Store release notes
✓ **For Maintainers**: Single source of truth (CHANGELOG.md)
✓ **For Everyone**: Full history accessible in-app
