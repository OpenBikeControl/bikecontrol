import 'dart:async';
import 'dart:io';

import 'package:bike_control/gen/l10n.dart';
import 'package:bike_control/services/device_identity_service.dart';
import 'package:bike_control/services/device_management_service.dart';
import 'package:bike_control/services/entitlements_service.dart';
import 'package:bike_control/utils/core.dart';
import 'package:bike_control/utils/iap/revenuecat_service.dart';
import 'package:bike_control/utils/iap/windows_iap_service.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Unified IAP manager that handles platform-specific IAP services.
class IAPManager {
  static IAPManager? _instance;
  static IAPManager get instance {
    _instance ??= IAPManager._();
    return _instance!;
  }

  static const String premiumMonthlyProductKey = 'premium_monthly';
  static int dailyCommandLimit = 15;

  RevenueCatService? _revenueCatService;
  WindowsIAPService? _windowsIapService;
  StreamSubscription<AuthState>? _authSubscription;
  bool _isInitialized = false;

  final DeviceIdentityService deviceIdentity = DeviceIdentityService();
  late final DeviceManagementService deviceManagement = DeviceManagementService(
    supabase: core.supabase,
    deviceIdentityService: deviceIdentity,
  );
  late final EntitlementsService entitlements = EntitlementsService(
    core.supabase,
    deviceIdentityService: deviceIdentity,
  );

  ValueNotifier<bool> isPurchased = ValueNotifier<bool>(false);
  ValueNotifier<bool> isLocalPro = ValueNotifier<bool>(false);

  IAPManager._();

  bool get isLoggedIn => core.supabase.auth.currentSession != null;

  bool get hasActiveSubscription =>
      (isLoggedIn && entitlements.hasActive(premiumMonthlyProductKey)) || (!isLoggedIn && isLocalPro.value);

  bool get isProEnabled => hasActiveSubscription && (isLoggedIn || (!isLoggedIn && isLocalPro.value));

  bool get isProEnabledForCurrentDevice =>
      hasActiveSubscription && ((isLoggedIn && entitlements.isRegisteredDevice) || (!isLoggedIn && isLocalPro.value));

  DateTime? get premiumActiveUntil => entitlements.activeUntil(premiumMonthlyProductKey);

  /// Initialize the IAP manager.
  Future<void> initialize() async {
    if (_isInitialized) return;

    final prefs = FlutterSecureStorage(aOptions: AndroidOptions());
    await entitlements.initialize();
    entitlements.addListener(_onEntitlementsChanged);
    _bindAuthLifecycle();

    if (kIsWeb) {
      _isInitialized = true;
      return;
    }

    try {
      if (Platform.isWindows) {
        _windowsIapService = WindowsIAPService(
          prefs,
          entitlementsService: entitlements,
        );
        await _windowsIapService!.initialize();
      } else if (Platform.isIOS || Platform.isMacOS || Platform.isAndroid) {
        _revenueCatService = RevenueCatService(
          prefs,
          isPurchasedNotifier: isPurchased,
          isProNotifier: isLocalPro,
          getDailyCommandLimit: () => dailyCommandLimit,
          setDailyCommandLimit: (limit) => dailyCommandLimit = limit,
          entitlementsService: entitlements,
          premiumProductKey: premiumMonthlyProductKey,
        );
        await _revenueCatService!.initialize();
      } else {
        throw UnsupportedError('Unsupported platform for IAP: ${Platform.operatingSystem}');
      }

      await entitlements.refresh();
      _syncPurchaseFlagFromEntitlements();
      _isInitialized = true;
    } catch (e) {
      debugPrint('Error initializing IAP manager: $e');
      _isInitialized = true;
    }
  }

  /// Called on app start when a session may already exist.
  Future<void> refreshEntitlementsOnAppStart() async {
    await entitlements.refresh(force: true);
    _syncPurchaseFlagFromEntitlements();
  }

  /// Called on app resume to refresh stale entitlement cache.
  Future<void> refreshEntitlementsOnResume() async {
    await entitlements.refresh();
    _syncPurchaseFlagFromEntitlements();
  }

  /// Check if the trial period has started.
  bool get hasTrialStarted {
    if (_revenueCatService != null) {
      return _revenueCatService!.hasTrialStarted;
    } else if (_windowsIapService != null) {
      return _windowsIapService!.hasTrialStarted;
    }
    return false;
  }

  /// Start the trial period.
  Future<void> startTrial() async {
    if (_revenueCatService != null) {
      await _revenueCatService!.startTrial();
    }
  }

  /// Get the number of days remaining in the trial.
  int get trialDaysRemaining {
    if (_revenueCatService != null) {
      return _revenueCatService!.trialDaysRemaining;
    } else if (_windowsIapService != null) {
      return _windowsIapService!.trialDaysRemaining;
    }
    return 0;
  }

  /// Check if the trial has expired.
  bool get isTrialExpired {
    if (isProEnabled) {
      return false;
    }
    if (_revenueCatService != null) {
      return _revenueCatService!.isTrialExpired;
    } else if (_windowsIapService != null) {
      return _windowsIapService!.isTrialExpired;
    }
    return false;
  }

  /// Check if the user can execute a command.
  bool get canExecuteCommand {
    if (isProEnabled) return true;
    if (_revenueCatService == null && _windowsIapService == null) return true;

    if (_revenueCatService != null) {
      return _revenueCatService!.canExecuteCommand;
    } else if (_windowsIapService != null) {
      return _windowsIapService!.canExecuteCommand;
    }
    return true;
  }

  /// Get the number of commands remaining today (for free tier after trial).
  int get commandsRemainingToday {
    if (isProEnabled) {
      return -1;
    }
    if (_revenueCatService != null) {
      return _revenueCatService!.commandsRemainingToday;
    } else if (_windowsIapService != null) {
      return _windowsIapService!.commandsRemainingToday;
    }
    return -1;
  }

  /// Get the daily command count.
  int get dailyCommandCount {
    if (_revenueCatService != null) {
      return _revenueCatService!.dailyCommandCount;
    } else if (_windowsIapService != null) {
      return _windowsIapService!.dailyCommandCount;
    }
    return 0;
  }

  /// Increment the daily command count.
  Future<void> incrementCommandCount() async {
    if (isProEnabled) {
      return;
    }
    if (_revenueCatService != null) {
      await _revenueCatService!.incrementCommandCount();
    } else if (_windowsIapService != null) {
      await _windowsIapService!.incrementCommandCount();
    }
  }

  /// Get a status message for the user.
  String getStatusMessage() {
    final activeUntil = premiumActiveUntil;
    final expiryInfo = activeUntil != null ? '\nexpires at ${_formatDate(activeUntil)}' : '';

    if (kIsWeb) {
      return "Web";
    } else if (isProEnabledForCurrentDevice) {
      return 'Pro version$expiryInfo';
    } else if (isProEnabled) {
      return 'Pro version (unregistered device)$expiryInfo';
    } else if (isPurchased.value) {
      return AppLocalizations.current.fullVersion;
    } else if (!hasTrialStarted) {
      return '${_revenueCatService?.trialDaysRemaining ?? _windowsIapService?.trialDaysRemaining} day trial available';
    } else if (!isTrialExpired) {
      return AppLocalizations.current.trialDaysRemaining(trialDaysRemaining);
    } else {
      return AppLocalizations.current.commandsRemainingToday(commandsRemainingToday, dailyCommandLimit);
    }
  }

  String _formatDate(DateTime date) {
    final local = date.toLocal();
    return '${local.day.toString().padLeft(2, '0')}.${local.month.toString().padLeft(2, '0')}.${local.year}';
  }

  /// Purchase the full version.
  Future<void> purchaseFullVersion(BuildContext context) async {
    if (_revenueCatService != null) {
      return _revenueCatService!.purchaseFullVersion(context);
    } else if (_windowsIapService != null) {
      return _windowsIapService!.purchaseFullVersion();
    }
  }

  /// Purchase the full version.
  Future<void> purchaseSubscription(BuildContext context) async {
    if (_revenueCatService != null) {
      return _revenueCatService!.purchaseSubscription(context);
    } else if (_windowsIapService != null) {
      return _windowsIapService!.purchaseSubscription(context);
    }
  }

  /// Restore previous purchases.
  Future<void> restorePurchases() async {
    if (_revenueCatService != null) {
      await _revenueCatService!.restorePurchases();
    } else if (_windowsIapService != null) {}
    _syncPurchaseFlagFromEntitlements();
  }

  /// Check if RevenueCat is being used.
  bool get isUsingRevenueCat => _revenueCatService != null;

  /// Check if running on Windows
  bool get isWindows => _windowsIapService != null;

  /// Check if user is logged in (Windows Stripe requires this)
  bool get isWindowsLoggedIn => _windowsIapService?.isLoggedIn ?? false;

  /// Open Stripe Billing Portal (Windows only)
  /// Returns false if user has no Stripe customer (should hide button)
  Future<bool> openBillingPortal(BuildContext context) async {
    if (_windowsIapService == null) return false;
    return _windowsIapService!.openBillingPortal(context);
  }

  /// Check if user has a Stripe customer record (Windows only)
  Future<bool> hasStripeCustomer() async {
    if (_windowsIapService == null) return false;
    return _windowsIapService!.hasStripeCustomer();
  }

  /// Dispose the manager.
  void dispose() {
    _authSubscription?.cancel();
    entitlements.removeListener(_onEntitlementsChanged);
    _revenueCatService?.dispose();
    _windowsIapService?.dispose();
  }

  Future<void> reset(bool fullReset) async {
    isPurchased.value = false;
    await entitlements.clearCache();
    _windowsIapService?.reset();
    await _revenueCatService?.reset(fullReset);
  }

  Future<void> redeem(String purchaseId) async {
    if (_revenueCatService != null) {
      await _revenueCatService!.redeem(purchaseId);
      await entitlements.refresh(force: true);
      _syncPurchaseFlagFromEntitlements();
    }
  }

  void setAttributes() {
    _revenueCatService?.setAttributes();
  }

  void _bindAuthLifecycle() {
    _authSubscription ??= core.supabase.auth.onAuthStateChange.listen((data) {
      unawaited(_handleAuthStateChange(data.event, data.session));
    });
  }

  Future<void> _handleAuthStateChange(AuthChangeEvent event, Session? session) async {
    switch (event) {
      case AuthChangeEvent.initialSession:
      case AuthChangeEvent.signedIn:
      case AuthChangeEvent.tokenRefreshed:
      case AuthChangeEvent.userUpdated:
      case AuthChangeEvent.mfaChallengeVerified:
        final userId = session?.user.id;
        if (userId != null) {
          await _revenueCatService?.logInWithSupabaseUserId(userId);
        }
        await _revenueCatService?.setAttributes();
        await entitlements.refresh(force: true);
        _syncPurchaseFlagFromEntitlements();
        return;
      case AuthChangeEvent.signedOut:
      // ignore: deprecated_member_use
      case AuthChangeEvent.userDeleted:
        await _revenueCatService?.logOut();
        await entitlements.clearCache();
        isPurchased.value = false;
        return;
      case AuthChangeEvent.passwordRecovery:
        return;
    }
  }

  void _onEntitlementsChanged() {
    _syncPurchaseFlagFromEntitlements();
  }

  void _syncPurchaseFlagFromEntitlements() {
    if (isProEnabled) {
      isPurchased.value = true;
    }
  }
}
