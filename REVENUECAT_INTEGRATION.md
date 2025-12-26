# RevenueCat Integration Guide

This document explains how to configure and use RevenueCat SDK in BikeControl.

## Overview

BikeControl now supports RevenueCat for subscription management on iOS, macOS, and Android platforms. Windows continues to use the Windows IAP service.

## Configuration

### 1. Environment Variables

Set your RevenueCat API key as an environment variable:

```bash
export REVENUECAT_API_KEY="your_api_key_here"
```

Or pass it during build:

```bash
flutter build ios --dart-define=REVENUECAT_API_KEY=your_api_key_here
```

### 2. RevenueCat Dashboard Setup

1. Go to [RevenueCat Dashboard](https://app.revenuecat.com/)
2. Create a new project or select existing one
3. Configure your app:
   - **iOS**: Add your App Store Connect API key
   - **Android**: Add your Google Play Service Account credentials
   - **macOS**: Add your App Store Connect API key

### 3. Product Configuration

Configure the following product in RevenueCat:

#### Product ID: `lifetime`
- **Type**: Non-consumable / Lifetime
- **Description**: Lifetime access to BikeControl full version

### 4. Entitlement Configuration

Create an entitlement in RevenueCat:

#### Entitlement ID: `Full Version`
- **Products**: Link the `lifetime` product to this entitlement

### 5. Offerings Setup

Create an offering with the lifetime product:

1. Go to **Offerings** in RevenueCat Dashboard
2. Create a new offering (or use the default)
3. Add the `lifetime` product to the offering
4. Mark it as current if desired

## Features

### Implemented Features

1. **RevenueCat SDK Integration**
   - Automatic initialization with API key from environment
   - Customer info listener for real-time entitlement updates
   - Graceful fallback to legacy IAP when RevenueCat key is not available

2. **Entitlement Checking**
   - Checks for "Full Version" entitlement
   - Automatically grants/revokes access based on entitlement status
   - Persistent purchase status storage

3. **Paywall**
   - Native RevenueCat Paywall UI
   - Automatically displays available offerings
   - Handles purchase flow end-to-end

4. **Customer Center**
   - Access to subscription management
   - Available when user has purchased
   - Shown as "Manage" button in IAP status widget

5. **Purchase Restoration**
   - Restore previous purchases across devices
   - Automatic entitlement validation

6. **Trial & Command Limits**
   - Existing trial logic preserved
   - Daily command limits for free tier
   - Seamless integration with existing app logic

### Platform Support

- ✅ **iOS**: Full RevenueCat support
- ✅ **macOS**: Full RevenueCat support
- ✅ **Android**: Full RevenueCat support
- ✅ **Windows**: Uses existing Windows IAP service (unchanged)
- ❌ **Web**: Not supported

## Usage

### For Users

1. **First Launch**: Trial period starts automatically (5 days)
2. **During Trial**: Full access to all features
3. **After Trial**: Limited to daily command quota
4. **Purchase**: Click "Unlock Full Version" to see paywall
5. **Manage Subscription**: Click "Manage" button (visible after purchase)

### For Developers

#### Initialize RevenueCat

RevenueCat is initialized automatically in `Settings.init()`:

```dart
await IAPManager.instance.initialize();
```

#### Check Entitlement

```dart
if (IAPManager.instance.isPurchased.value) {
  // User has full version
}
```

#### Present Paywall

```dart
await IAPManager.instance.presentPaywall();
```

#### Present Customer Center

```dart
await IAPManager.instance.presentCustomerCenter();
```

#### Restore Purchases

```dart
await IAPManager.instance.restorePurchases();
```

## Testing

### Test Mode

RevenueCat automatically detects sandbox environments:

- **iOS**: Use TestFlight or Xcode sandbox accounts
- **Android**: Use test tracks in Google Play Console
- **macOS**: Use Xcode sandbox accounts

### Debug Logs

Debug logs are automatically enabled in debug mode. Check console for:

```
RevenueCat initialized successfully
Full Version entitlement: true/false
```

## Troubleshooting

### API Key Not Found

If you see "RevenueCat API key not configured":

1. Ensure `REVENUECAT_API_KEY` environment variable is set
2. Or pass via `--dart-define` during build
3. Check that the key is valid in RevenueCat Dashboard

### Entitlement Not Working

1. Verify product ID matches in:
   - App Store Connect / Google Play Console
   - RevenueCat Dashboard
2. Check that product is linked to "Full Version" entitlement
3. Verify offering is set as current in RevenueCat

### Paywall Not Showing

1. Ensure offerings are properly configured
2. Check that at least one product is available
3. Review RevenueCat Dashboard for configuration errors

## Best Practices

1. **Error Handling**: All RevenueCat calls include proper error handling
2. **Fallback**: Legacy IAP service is used if RevenueCat key is not available
3. **Customer Info Listener**: Real-time updates ensure immediate access after purchase
4. **Platform Separation**: Windows maintains its own IAP implementation
5. **Security**: API key should never be committed to source code

## Resources

- [RevenueCat Documentation](https://www.revenuecat.com/docs)
- [Getting Started - Flutter](https://www.revenuecat.com/docs/getting-started/installation/flutter)
- [Paywalls Documentation](https://www.revenuecat.com/docs/tools/paywalls)
- [Customer Center Documentation](https://www.revenuecat.com/docs/tools/customer-center)
- [RevenueCat Dashboard](https://app.revenuecat.com/)
