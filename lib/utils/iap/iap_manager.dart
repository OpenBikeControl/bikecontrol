import 'dart:async';
import 'dart:io';

import 'package:bike_control/gen/l10n.dart';
import 'package:bike_control/services/device_identity_service.dart';
import 'package:bike_control/services/device_management_service.dart';
import 'package:bike_control/services/entitlements_service.dart';
import 'package:bike_control/services/windows_subscription_service.dart';
import 'package:bike_control/utils/core.dart';
import 'package:bike_control/utils/iap/iap_service.dart';
import 'package:bike_control/utils/iap/revenuecat_service.dart';
import 'package:bike_control/utils/iap/windows_iap_service.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:windows_iap/windows_iap.dart';

/// Unified IAP manager that handles platform-specific IAP services.
class IAPManager {
  static IAPManager? _instance;
  static IAPManager get instance {
    _instance ??= IAPManager._();
    return _instance!;
  }

  static const String premiumMonthlyProductKey = 'premium_monthly';
  static int dailyCommandLimit = 15;

  IAPService? _iapService;
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

  IAPManager._();

  bool get hasActiveSubscription => entitlements.hasActive(premiumMonthlyProductKey);

  bool get isPremiumEnabled => hasActiveSubscription && entitlements.isRegisteredDevice;

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
        final windowsIap = WindowsIap();
        final windowsSubscriptionService = WindowsSubscriptionService(
          supabase: core.supabase,
          windowsIap: windowsIap,
          entitlements: entitlements,
          deviceIdentityService: deviceIdentity,
        );

        _windowsIapService = WindowsIAPService(
          prefs,
          entitlementsService: entitlements,
          subscriptionService: windowsSubscriptionService,
        );
        await _windowsIapService!.initialize();
      } else if (Platform.isIOS || Platform.isMacOS || Platform.isAndroid) {
        _revenueCatService = RevenueCatService(
          prefs,
          isPurchasedNotifier: isPurchased,
          getDailyCommandLimit: () => dailyCommandLimit,
          setDailyCommandLimit: (limit) => dailyCommandLimit = limit,
          entitlementsService: entitlements,
          premiumProductKey: premiumMonthlyProductKey,
        );
        await _revenueCatService!.initialize();
      } else {
        debugPrint('Using legacy IAP service (no RevenueCat key)');
        _iapService = IAPService(prefs);
        await _iapService!.initialize();
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
    } else if (_iapService != null) {
      return _iapService!.hasTrialStarted;
    } else if (_windowsIapService != null) {
      return _windowsIapService!.hasTrialStarted;
    }
    return false;
  }

  /// Start the trial period.
  Future<void> startTrial() async {
    if (_revenueCatService != null) {
      await _revenueCatService!.startTrial();
    } else if (_iapService != null) {
      await _iapService!.startTrial();
    }
  }

  /// Get the number of days remaining in the trial.
  int get trialDaysRemaining {
    if (_revenueCatService != null) {
      return _revenueCatService!.trialDaysRemaining;
    } else if (_iapService != null) {
      return _iapService!.trialDaysRemaining;
    } else if (_windowsIapService != null) {
      return _windowsIapService!.trialDaysRemaining;
    }
    return 0;
  }

  /// Check if the trial has expired.
  bool get isTrialExpired {
    if (isPremiumEnabled) {
      return false;
    }
    if (_revenueCatService != null) {
      return _revenueCatService!.isTrialExpired;
    } else if (_iapService != null) {
      return _iapService!.isTrialExpired;
    } else if (_windowsIapService != null) {
      return _windowsIapService!.isTrialExpired;
    }
    return false;
  }

  /// Check if the user can execute a command.
  bool get canExecuteCommand {
    if (isPremiumEnabled) return true;
    if (_revenueCatService == null && _iapService == null && _windowsIapService == null) return true;

    if (_revenueCatService != null) {
      return _revenueCatService!.canExecuteCommand;
    } else if (_iapService != null) {
      return _iapService!.canExecuteCommand;
    } else if (_windowsIapService != null) {
      return _windowsIapService!.canExecuteCommand;
    }
    return true;
  }

  /// Get the number of commands remaining today (for free tier after trial).
  int get commandsRemainingToday {
    if (isPremiumEnabled) {
      return -1;
    }
    if (_revenueCatService != null) {
      return _revenueCatService!.commandsRemainingToday;
    } else if (_iapService != null) {
      return _iapService!.commandsRemainingToday;
    } else if (_windowsIapService != null) {
      return _windowsIapService!.commandsRemainingToday;
    }
    return -1;
  }

  /// Get the daily command count.
  int get dailyCommandCount {
    if (_revenueCatService != null) {
      return _revenueCatService!.dailyCommandCount;
    } else if (_iapService != null) {
      return _iapService!.dailyCommandCount;
    } else if (_windowsIapService != null) {
      return _windowsIapService!.dailyCommandCount;
    }
    return 0;
  }

  /// Increment the daily command count.
  Future<void> incrementCommandCount() async {
    if (isPremiumEnabled) {
      return;
    }
    if (_revenueCatService != null) {
      await _revenueCatService!.incrementCommandCount();
    } else if (_iapService != null) {
      await _iapService!.incrementCommandCount();
    } else if (_windowsIapService != null) {
      await _windowsIapService!.incrementCommandCount();
    }
  }

  /// Get a status message for the user.
  String getStatusMessage() {
    if (kIsWeb) {
      return "Web";
    } else if (isPremiumEnabled || IAPManager.instance.isPurchased.value) {
      return AppLocalizations.current.fullVersion;
    } else if (!hasTrialStarted) {
      return '${_revenueCatService?.trialDaysRemaining ?? _iapService?.trialDaysRemaining ?? _windowsIapService?.trialDaysRemaining} day trial available';
    } else if (!isTrialExpired) {
      return AppLocalizations.current.trialDaysRemaining(trialDaysRemaining);
    } else {
      return AppLocalizations.current.commandsRemainingToday(commandsRemainingToday, dailyCommandLimit);
    }
  }

  /// Purchase the full version.
  Future<void> purchaseFullVersion(BuildContext context) async {
    if (_revenueCatService != null) {
      return _revenueCatService!.purchaseFullVersion(context);
    } else if (_iapService != null) {
      return _iapService!.purchase(productId: IAPService.fullVersionId);
    } else if (_windowsIapService != null) {
      return _windowsIapService!.purchaseFullVersion();
    }
  }

  /// Purchase the full version.
  Future<void> purchaseSubscription(BuildContext context) async {
    if (_revenueCatService != null) {
      return _revenueCatService!.purchaseSubscription(context);
    } else if (_iapService != null) {
      return _iapService!.purchase(productId: IAPService.subscriptionId);
    } else if (_windowsIapService != null) {
      return _windowsIapService!.purchaseFullVersion();
    }
  }

  /// Restore previous purchases.
  Future<void> restorePurchases() async {
    if (_revenueCatService != null) {
      await _revenueCatService!.restorePurchases();
    } else if (_iapService != null) {
      await _iapService!.restorePurchases();
    } else if (_windowsIapService != null) {
      await _windowsIapService!.restoreOrSyncSubscription();
    }
    _syncPurchaseFlagFromEntitlements();
  }

  /// Check if RevenueCat is being used.
  bool get isUsingRevenueCat => _revenueCatService != null;

  /// Dispose the manager.
  void dispose() {
    _authSubscription?.cancel();
    entitlements.removeListener(_onEntitlementsChanged);
    _revenueCatService?.dispose();
    _iapService?.dispose();
    _windowsIapService?.dispose();
  }

  Future<void> reset(bool fullReset) async {
    isPurchased.value = false;
    await entitlements.clearCache();
    _windowsIapService?.reset();
    await _revenueCatService?.reset(fullReset);
    await _iapService?.reset(fullReset);
  }

  Future<void> redeem(String purchaseId) async {
    if (_revenueCatService != null) {
      await _revenueCatService!.redeem(purchaseId);
      await entitlements.refresh(force: true);
      _syncPurchaseFlagFromEntitlements();
    } else if (_iapService != null) {
      await _iapService!.redeem();
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
    if (isPremiumEnabled) {
      isPurchased.value = true;
    }
  }
}
