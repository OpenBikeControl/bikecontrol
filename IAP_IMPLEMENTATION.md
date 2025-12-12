# In-App Purchase Implementation

This document describes the in-app purchase (IAP) implementation for BikeControl, which transitions the app from paid to free with IAP.

## Overview

The app now offers:
- **5-day free trial** for new users with unlimited commands
- **15 commands per day** after trial expires (free tier)
- **One-time purchase** to unlock unlimited commands

Existing users who purchased the paid version are automatically granted full access.

## Platform-Specific Configuration

### iOS and macOS (App Store)

1. **Create In-App Purchase in App Store Connect:**
   - Product Type: **Non-Consumable**
   - Product ID: `full_access_unlock`
   - Name: "Full Access Unlock" (or your preferred name)
   - Add localizations and pricing

2. **Receipt Verification:**
   - The app uses `appStoreReceiptURL` to check if the app was previously purchased as a paid app
   - IAP restoration is handled automatically by the `in_app_purchase` plugin

3. **App Store Transition:**
   - Submit app update with IAP support
   - After approval, change app price to **Free** in App Store Connect
   - Update app description to explain the free trial and IAP

### Android (Google Play)

1. **Create In-App Product in Google Play Console:**
   - Product Type: **One-time** (Managed Product)
   - Product ID: `full_access_unlock`
   - Add name, description, and pricing

2. **Existing User Detection:**
   - Uses `getLastSeenVersion()` from shared preferences
   - If a user has a `last_seen_version`, they're considered an existing user and granted full access

3. **Google Play Transition:**
   - Publish app update with IAP support
   - After update is live, change app to **Free** in Google Play Console
   - Update store listing to explain the trial and IAP

### Windows (Microsoft Store)

1. **Add Durable Add-on in Partner Center:**
   - Type: **Durable** (one-time purchase)
   - Product ID: `full_access_unlock`
   - Add name, description, and pricing

2. **Trial Configuration:**
   - Currently implemented with local trial tracking (5 days)
   - Can be enhanced to use Windows Store built-in trial system

3. **Existing User Detection:**
   - Currently uses `last_seen_version` to detect existing users
   - **TODO:** Integrate with Windows Store APIs for proper purchase verification
   - Requires platform channel implementation for Windows Store API calls

4. **Windows Store Transition:**
   - Submit app update with IAP support
   - After approval, set app to **Free** in Partner Center
   - Update store description

**Note:** The Windows implementation is currently a stub that needs full Windows Store API integration via platform channels. The packages `windows_store` and `windows_iap_plugin` mentioned in requirements are not yet integrated.

## Code Structure

### IAP Service Layer
- `lib/utils/iap/iap_service.dart` - Main IAP service for iOS/macOS/Android
- `lib/utils/iap/windows_iap_service.dart` - Windows-specific service (stub)
- `lib/utils/iap/iap_manager.dart` - Unified manager that routes to platform-specific service

### Integration Points
- `lib/utils/settings/settings.dart` - Initializes IAP on app start
- `lib/bluetooth/devices/base_device.dart` - Checks IAP status before executing commands
- `lib/widgets/iap_status_widget.dart` - UI widget showing status and purchase button
- `lib/pages/configuration.dart` - Displays IAP status widget

## Trial and Command Limiting

### Trial Period
- **Duration:** 5 days from first app launch
- **Access:** Unlimited commands during trial
- **Activation:** Automatically starts on first launch for new users

### After Trial Expires
- **Free Tier:** 15 commands per day
- **Reset:** Command counter resets daily at midnight
- **Messages:** Users see clear messages about remaining commands

### Purchased Users
- **Unlimited Commands:** No restrictions
- **Status Display:** "Full Version Unlocked" message

## Existing User Migration

The app automatically detects and grants full access to existing users:

### Detection Logic
1. **iOS/macOS:** Checks for app receipt and restores previous purchases
2. **Android:** Checks for `last_seen_version` in shared preferences
3. **Windows:** Checks for `last_seen_version` (to be enhanced with Store API)

### Recommendation
Before transitioning to free, ensure all existing users have updated to this version so their `last_seen_version` is recorded.

## Testing

### Test IAP on Each Platform

**iOS/macOS:**
1. Use Sandbox testers in App Store Connect
2. Test purchase flow
3. Test restoration of purchases
4. Verify existing user detection

**Android:**
1. Use test tracks (internal/closed testing)
2. Add test accounts in Google Play Console
3. Test purchase flow
4. Verify existing user detection

**Windows:**
1. Test local trial functionality
2. Test existing user detection
3. TODO: Test Windows Store purchase flow once implemented

### Test Trial and Command Limiting
1. Test new user experience (trial starts automatically)
2. Simulate trial expiration by modifying stored trial date
3. Test command counter (execute 15+ commands after trial)
4. Verify daily reset of command counter
5. Test purchase unlock

## Store Submission Checklist

- [ ] Create IAP products in all stores (iOS, macOS, Android, Windows)
- [ ] Test IAP functionality on all platforms
- [ ] Submit app update with IAP support (keep app paid)
- [ ] Wait for approval on all platforms
- [ ] Change app price to Free on all platforms
- [ ] Update store descriptions to explain:
  - Free 5-day trial
  - 15 commands/day after trial
  - One-time purchase for unlimited access
  - Existing users have automatic full access
- [ ] Monitor reviews and support requests during transition

## Known Limitations

1. **Windows Store Integration:**
   - Currently uses local trial tracking instead of Windows Store trial API
   - Purchase flow is stubbed out - needs platform channel implementation
   - Existing user detection works via `last_seen_version` but should be enhanced with Store API

2. **Receipt Verification:**
   - iOS/macOS receipt verification is simplified
   - Production apps should implement server-side receipt verification for security

## Future Enhancements

1. Implement full Windows Store API integration
2. Add server-side receipt verification for iOS/macOS
3. Add analytics for trial conversion rates
4. Add promotional codes support
5. Add family sharing support (iOS/macOS)
