# RevenueCat Setup Instructions

## Quick Start Guide

### Step 1: Get Your RevenueCat API Key

1. Sign up at [RevenueCat](https://app.revenuecat.com/)
2. Create a new project
3. Go to **Settings** → **API Keys**
4. Copy your API key (starts with `appl_` or similar)

### Step 2: Configure Products in App Store Connect / Google Play Console

#### For iOS/macOS:
1. Go to [App Store Connect](https://appstoreconnect.apple.com/)
2. Select your app → **In-App Purchases**
3. Create a new In-App Purchase:
   - **Type**: Non-Consumable
   - **Product ID**: `lifetime`
   - **Display Name**: BikeControl Lifetime
   - **Description**: Lifetime access to all BikeControl features
   - **Price**: Set your desired price

#### For Android:
1. Go to [Google Play Console](https://play.google.com/console/)
2. Select your app → **Monetize** → **In-app products**
3. Create a new product:
   - **Product ID**: `lifetime`
   - **Name**: BikeControl Lifetime
   - **Description**: Lifetime access to all BikeControl features
   - **Price**: Set your desired price

### Step 3: Configure RevenueCat Dashboard

1. Add your app to RevenueCat:
   - **iOS/macOS**: Add App Store Connect credentials
   - **Android**: Add Google Play Service Account JSON

2. Create Products:
   - Go to **Products**
   - Click **Add Product**
   - Enter Product ID: `lifetime`
   - Link to App Store / Google Play product

3. Create Entitlement:
   - Go to **Entitlements**
   - Create new entitlement: `Full Version`
   - Add the `lifetime` product to this entitlement

4. Create Offering:
   - Go to **Offerings**
   - Create or edit the default offering
   - Add `lifetime` product
   - Set as current offering

### Step 4: Configure Your Build

Add your RevenueCat API key to your build:

#### Option A: Environment Variable (Development)
```bash
export REVENUECAT_API_KEY="your_api_key_here"
flutter run
```

#### Option B: Build Command (Production)
```bash
flutter build ios --dart-define=REVENUECAT_API_KEY=your_api_key_here
flutter build apk --dart-define=REVENUECAT_API_KEY=your_api_key_here
flutter build macos --dart-define=REVENUECAT_API_KEY=your_api_key_here
```

#### Option C: CI/CD (Recommended)
Add `REVENUECAT_API_KEY` as a secret in your CI/CD environment:

**GitHub Actions:**
```yaml
- name: Build
  env:
    REVENUECAT_API_KEY: ${{ secrets.REVENUECAT_API_KEY }}
  run: flutter build ios --dart-define=REVENUECAT_API_KEY=$REVENUECAT_API_KEY
```

### Step 5: Test Your Integration

1. **Build and Run**: Build your app with the API key configured
2. **Check Logs**: Look for "RevenueCat initialized successfully"
3. **Test Purchase Flow**:
   - Click "Unlock Full Version"
   - Should see RevenueCat paywall
   - Complete test purchase (use sandbox/test account)
4. **Verify Entitlement**: After purchase, should see "Full Version" status
5. **Test Customer Center**: Click "Manage" button when purchased

### Step 6: Production Checklist

- [ ] RevenueCat project created and configured
- [ ] Products created in App Store Connect / Google Play Console
- [ ] Products imported to RevenueCat
- [ ] "Full Version" entitlement created and linked to `lifetime` product
- [ ] Offering created with `lifetime` product
- [ ] API key added to CI/CD secrets
- [ ] Test purchase completed successfully
- [ ] Sandbox testing completed
- [ ] Production testing completed (TestFlight / Internal Testing)

## Important Notes

1. **Never commit your API key** to source control
2. **Use sandbox accounts** for testing
3. **Product IDs must match** across App Store/Google Play and RevenueCat
4. **Entitlement name** must be exactly `Full Version`
5. **Windows users** will continue to use Windows Store IAP

## Fallback Behavior

If RevenueCat API key is not configured:
- App will automatically use legacy IAP service
- All features will continue to work
- iOS/macOS will use `in_app_purchase` package
- Android will use `in_app_purchase` package
- Windows will use `windows_iap` package

## Support

For issues with:
- **RevenueCat SDK**: Check [RevenueCat Docs](https://www.revenuecat.com/docs)
- **Product Setup**: Review platform-specific documentation
- **BikeControl Integration**: See `REVENUECAT_INTEGRATION.md`
