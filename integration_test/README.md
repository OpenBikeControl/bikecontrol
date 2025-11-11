# Screenshot Generation

This directory contains integration tests for generating app store screenshots during the build pipeline.

## Overview

The screenshot generation system automatically creates promotional screenshots for:
- **Phone screens**: 1140x2616 (mob1.png, mob2.png)
- **Tablet screens**: 2248x2480 (tab1.png, tab2.png)
- **macOS screens**: 1280x800 (mac_screenshot_1.png, mac_screenshot_2.png)

## How It Works

1. **Integration Test**: `screenshot_test.dart` defines test cases for each screen size
2. **Test Driver**: `../test_driver/integration_test.dart` handles saving screenshots to disk
3. **CI/CD Integration**: The build workflow runs these tests and packages screenshots

## Running Locally

To generate screenshots locally:

```bash
# From the project root
flutter test integration_test/screenshot_test.dart --driver=test_driver/integration_test.dart
```

Screenshots will be saved to `build/screenshots/`.

## CI/CD Process

During the GitHub Actions build workflow:
1. Flutter environment is set up
2. Dependencies are installed with `flutter pub get`
3. Integration tests run and generate screenshots
4. Screenshots are zipped into `SwiftControl.screenshots.zip`
5. The zip file is uploaded as a workflow artifact
6. The zip file is attached to the GitHub release

## Modifying Screenshots

To modify the screenshots:
1. Edit `screenshot_test.dart` to change the UI or add new screens
2. Adjust screen sizes by modifying `physicalSizeTestValue`
3. Test locally to verify the output
4. Commit changes - CI will automatically generate new screenshots

## Screenshot Content

The generated screenshots show:
- Main app screen with branding and connect button
- Device list showing various supported devices (Zwift Click, Play, Elite Sterzo, etc.)
- Dark theme matching the app's design
- Consistent branding with the app's color scheme
