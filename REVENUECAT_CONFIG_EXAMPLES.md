# Example: RevenueCat Configuration

This file contains example configurations for different build scenarios.

## Development Environment

### Local Development (Terminal)

```bash
# Set environment variable for current session
export REVENUECAT_API_KEY="appl_YourDevelopmentKeyHere"

# Run the app
flutter run

# Or in one line
REVENUECAT_API_KEY="appl_YourDevelopmentKeyHere" flutter run
```

### VS Code Launch Configuration

Add to `.vscode/launch.json`:

```json
{
  "version": "0.2.0",
  "configurations": [
    {
      "name": "Flutter (Development with RevenueCat)",
      "request": "launch",
      "type": "dart",
      "program": "lib/main.dart",
      "args": [
        "--dart-define=REVENUECAT_API_KEY=appl_YourDevelopmentKeyHere"
      ]
    },
    {
      "name": "Flutter (Development without RevenueCat)",
      "request": "launch",
      "type": "dart",
      "program": "lib/main.dart"
    }
  ]
}
```

### Android Studio / IntelliJ

1. Go to **Run** → **Edit Configurations**
2. Select your Flutter configuration
3. Add to **Additional run args**:
   ```
   --dart-define=REVENUECAT_API_KEY=appl_YourKeyHere
   ```

## Production Builds

### iOS Production

```bash
# Build for App Store
flutter build ios \
  --release \
  --dart-define=REVENUECAT_API_KEY=$REVENUECAT_API_KEY \
  --no-codesign

# Build and archive with Xcode
xcodebuild archive \
  -workspace ios/Runner.xcworkspace \
  -scheme Runner \
  -archivePath build/Runner.xcarchive \
  -configuration Release
```

### macOS Production

```bash
# Build for Mac App Store
flutter build macos \
  --release \
  --dart-define=REVENUECAT_API_KEY=$REVENUECAT_API_KEY
```

### Android Production

```bash
# Build App Bundle for Google Play
flutter build appbundle \
  --release \
  --dart-define=REVENUECAT_API_KEY=$REVENUECAT_API_KEY

# Build APK
flutter build apk \
  --release \
  --dart-define=REVENUECAT_API_KEY=$REVENUECAT_API_KEY
```

### Windows Production

Windows builds don't need RevenueCat configuration (uses Windows Store IAP):

```bash
flutter build windows --release
```

## CI/CD Configuration

### GitHub Actions

```yaml
name: Build and Release

on:
  push:
    branches: [ main ]

jobs:
  build-ios:
    runs-on: macos-latest
    steps:
      - uses: actions/checkout@v3
      
      - uses: subosito/flutter-action@v2
        with:
          flutter-version: '3.9.0'
      
      - name: Build iOS
        env:
          REVENUECAT_API_KEY: ${{ secrets.REVENUECAT_API_KEY }}
        run: |
          flutter build ios \
            --release \
            --dart-define=REVENUECAT_API_KEY=$REVENUECAT_API_KEY \
            --no-codesign

  build-android:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      
      - uses: actions/setup-java@v3
        with:
          distribution: 'zulu'
          java-version: '17'
      
      - uses: subosito/flutter-action@v2
        with:
          flutter-version: '3.9.0'
      
      - name: Build Android
        env:
          REVENUECAT_API_KEY: ${{ secrets.REVENUECAT_API_KEY }}
        run: |
          flutter build appbundle \
            --release \
            --dart-define=REVENUECAT_API_KEY=$REVENUECAT_API_KEY

  build-windows:
    runs-on: windows-latest
    steps:
      - uses: actions/checkout@v3
      
      - uses: subosito/flutter-action@v2
        with:
          flutter-version: '3.9.0'
      
      - name: Build Windows
        run: flutter build windows --release
```

**Don't forget to add `REVENUECAT_API_KEY` to GitHub Secrets:**
1. Go to repository **Settings** → **Secrets and variables** → **Actions**
2. Click **New repository secret**
3. Name: `REVENUECAT_API_KEY`
4. Value: Your RevenueCat API key

### GitLab CI

```yaml
stages:
  - build

build:ios:
  stage: build
  tags:
    - macos
  script:
    - flutter build ios --release --dart-define=REVENUECAT_API_KEY=$REVENUECAT_API_KEY --no-codesign
  only:
    - main

build:android:
  stage: build
  image: cirrusci/flutter:stable
  script:
    - flutter build appbundle --release --dart-define=REVENUECAT_API_KEY=$REVENUECAT_API_KEY
  only:
    - main
```

**Add `REVENUECAT_API_KEY` to GitLab CI/CD Variables:**
1. Go to project **Settings** → **CI/CD** → **Variables**
2. Click **Add variable**
3. Key: `REVENUECAT_API_KEY`
4. Value: Your RevenueCat API key
5. Check **Mask variable** and **Protect variable**

### Fastlane

Add to your `Fastfile`:

```ruby
lane :build_ios do
  flutter_build(
    platform: :ios,
    dart_defines: {
      "REVENUECAT_API_KEY" => ENV["REVENUECAT_API_KEY"]
    }
  )
end

lane :build_android do
  flutter_build(
    platform: :android,
    dart_defines: {
      "REVENUECAT_API_KEY" => ENV["REVENUECAT_API_KEY"]
    }
  )
end
```

## Testing Configurations

### Sandbox Testing (iOS/macOS)

Use a different API key for sandbox testing:

```bash
# Development/Sandbox builds
flutter run --dart-define=REVENUECAT_API_KEY=appl_YourSandboxKeyHere

# Production builds
flutter build ios --dart-define=REVENUECAT_API_KEY=appl_YourProductionKeyHere
```

### Test Without RevenueCat

To test the fallback to legacy IAP:

```bash
# Simply don't provide the API key
flutter run

# Or explicitly unset it
unset REVENUECAT_API_KEY
flutter run
```

The app will automatically use the legacy IAP service.

## Security Best Practices

1. **Never commit API keys to source control**
   - Add `.env` files to `.gitignore`
   - Use environment variables or CI/CD secrets

2. **Use different keys for different environments**
   - Sandbox/Development key for testing
   - Production key for releases

3. **Rotate keys periodically**
   - RevenueCat allows generating new keys
   - Update in all CI/CD pipelines

4. **Limit key permissions**
   - Use read-only keys where possible
   - Separate keys for different purposes

## Verifying Configuration

After building with RevenueCat configured, check the logs:

```
✅ Success indicators:
- "Using RevenueCat service for IAP"
- "RevenueCat initialized successfully"
- Paywall displays when clicking "Unlock Full Version"

❌ Fallback indicators (no key):
- "Using legacy IAP service (no RevenueCat key)"
- "RevenueCat API key not configured"
- Standard purchase dialog instead of paywall

❌ Error indicators:
- "Failed to initialize RevenueCat"
- Check API key is correct
- Verify network connectivity
- Check RevenueCat Dashboard configuration
```

## Troubleshooting

### "API key not configured" in logs

**Cause**: Environment variable or dart-define not set correctly

**Solution**:
```bash
# Verify key is set
echo $REVENUECAT_API_KEY

# If empty, set it
export REVENUECAT_API_KEY="your_key_here"

# Or use dart-define
flutter run --dart-define=REVENUECAT_API_KEY=your_key_here
```

### Key works locally but not in CI/CD

**Cause**: Secret not configured or not accessible

**Solution**:
1. Verify secret is added to CI/CD platform
2. Check secret name matches exactly
3. Ensure job has permission to access secrets
4. Check if running on forked repository (secrets may not be available)

### Different behavior in release vs debug

**Cause**: Different API keys or missing configuration in release build

**Solution**:
- Ensure `--dart-define` is included in release build command
- Verify production API key is correct
- Check RevenueCat Dashboard for production vs sandbox configuration
