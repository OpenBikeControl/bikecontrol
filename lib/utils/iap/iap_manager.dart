import 'dart:async';
import 'dart:io';

import 'package:bike_control/gen/l10n.dart';
import 'package:bike_control/models/device_limit_reached_error.dart';
import 'package:bike_control/pages/paywall.dart';
import 'package:bike_control/widgets/ui/sheet_pull_to_dismiss.dart';
import 'package:bike_control/services/device_identity_service.dart';
import 'package:bike_control/services/device_management_service.dart';
import 'package:bike_control/services/entitlements_service.dart';
import 'package:bike_control/utils/core.dart';
import 'package:bike_control/utils/iap/revenuecat_service.dart';
import 'package:bike_control/utils/iap/windows_iap_service.dart';
import 'package:bike_control/utils/windows_store_environment.dart';
import 'package:bike_control/widgets/go_pro_dialog.dart';
import 'package:bike_control/widgets/ui/toast.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

enum SubscriptionPlan {
  monthly,
  yearly,
}

/// Unified IAP manager that handles platform-specific IAP services.
class IAPManager {
  static IAPManager? _instance;
  static IAPManager get instance {
    _instance ??= IAPManager._();
    return _instance!;
  }

  static const String premiumMonthlyProductKey = 'premium_monthly';
  static const String premiumYearlyProductKey = 'premium_yearly';
  static const String fullVersionProductKey = 'full_version';
  static const String betaAccessProductKey = 'beta_access';
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

  /// Whether the logged-in user is flagged for the Shorebird beta update
  /// track (a manual `beta_access` entitlement granted from the admin
  /// dashboard). Reads the cached entitlements; false when logged out or
  /// before the first entitlements fetch.
  bool get isBetaTester => (isLoggedIn && entitlements.hasActive(betaAccessProductKey) || kDebugMode);

  bool get hasActiveSubscription =>
      (isLoggedIn && (entitlements.hasActive(premiumMonthlyProductKey)) ||
          entitlements.hasActive(premiumYearlyProductKey)) ||
      (!isLoggedIn && isLocalPro.value);

  bool get isProEnabled => hasActiveSubscription && (isLoggedIn || (!isLoggedIn && isLocalPro.value));

  bool get isProEnabledForCurrentDevice {
    if (!_isInitialized) return false;
    if (_unregisteredDeviceForTesting) return false;
    return hasActiveSubscription &&
        ((isLoggedIn && entitlements.isRegisteredDevice) || (!isLoggedIn && isLocalPro.value));
  }

  /// Pro is on the account but this device is not registered for it, so the
  /// Pro-gated features stay off here. Riders in this state used to see only
  /// "Pro (unregistered device)" in the title bar and wrote in believing Pro
  /// was broken — the home banner, the virtual-shifting notice and the
  /// post-purchase dialog all key off this.
  bool get isProButDeviceUnregistered => isProEnabled && !isProEnabledForCurrentDevice;

  bool get isProEnabledForCurrentDeviceOrDidPurchaseOld {
    if (!_isInitialized) return false;
    return isProEnabledForCurrentDevice || hasPurchasedBefore50RVC;
  }

  /// Test-only: makes [isProEnabledForCurrentDevice] report false while
  /// [isProEnabled] holds — the state a logged-in rider lands in when the
  /// device could not be registered (platform limit reached). Nothing in the
  /// production paths sets it.
  bool _unregisteredDeviceForTesting = false;

  /// Test-only: force the Pro entitlement state so Pro-gated actions/UI can be
  /// exercised without a live subscription or device registration.
  /// [registeredDevice] false yields "Pro on the account, not on this device".
  @visibleForTesting
  void setProForTesting({required bool enabled, bool registeredDevice = true}) {
    _isInitialized = true;
    _unregisteredDeviceForTesting = enabled && !registeredDevice;
    isLocalPro.value = enabled;
  }

  bool get hasPurchasedBefore50RVC =>
      isPurchased.value &&
      ((_revenueCatService?.hasPurchasedBefore50 ?? false) || (_windowsIapService?.hasPurchasedBefore50 ?? false));

  DateTime? get premiumActiveUntil =>
      entitlements.activeUntil(premiumMonthlyProductKey) ?? entitlements.activeUntil(premiumYearlyProductKey);

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
          premiumProductKeyMonthly: premiumMonthlyProductKey,
          premiumProductKeyYearly: premiumYearlyProductKey,
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
    if (isOutsideStoreWindowsBuild) {
      return true;
    }
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
    if (isOutsideStoreWindowsBuild) {
      return 0;
    }
    if (_revenueCatService != null) {
      return _revenueCatService!.trialDaysRemaining;
    } else if (_windowsIapService != null) {
      return _windowsIapService!.trialDaysRemaining;
    }
    return 0;
  }

  /// Check if the trial has expired.
  bool get isTrialExpired {
    // Before IAP is initialized there is no trial to have expired yet, and the
    // pro/subscription checks below reach into Supabase which isn't wired up
    // until startup completes. Mirror isProEnabledForCurrentDevice's guard.
    if (!_isInitialized) return false;
    if (isProEnabled) {
      return false;
    }
    if (isOutsideStoreWindowsBuild && !isPurchased.value) {
      return true;
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
      return 'Pro$expiryInfo';
    } else if (isProEnabled) {
      return 'Pro (unregistered device)$expiryInfo';
    } else if (isPurchased.value) {
      return AppLocalizations.current.fullVersion;
    } else if (isOutsideStoreWindowsBuild) {
      return AppLocalizations.current.trialExpired(dailyCommandLimit);
    } else if (!hasTrialStarted) {
      return AppLocalizations.current.trialDaysAvailable(
        _revenueCatService?.trialDaysRemaining ?? _windowsIapService?.trialDaysRemaining ?? 0,
      );
    } else if (!isTrialExpired) {
      return AppLocalizations.current.trialDaysRemaining(trialDaysRemaining);
    } else {
      return AppLocalizations.current.commandsRemainingToday(commandsRemainingToday, dailyCommandLimit);
    }
  }

  String _formatDate(DateTime date) {
    final local = date.toLocal();
    // when today return full time, otherwise just date
    final now = DateTime.now();
    if (local.year == now.year && local.month == now.month && local.day == now.day) {
      return '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
    } else {
      return '${local.day.toString().padLeft(2, '0')}.${local.month.toString().padLeft(2, '0')}.${local.year}';
    }
  }

  /// Purchase the full version.
  Future<void> purchaseFullVersion(BuildContext context, {bool fromPaywall = false}) async {
    if (isOutsideStoreWindowsBuild) {
      if (!fromPaywall) {
        return _showPaywall(context, false);
      }
      return _windowsIapService!.purchaseFullVersionViaStripe(context);
    }
    // The in-app paywall is what riders see on every platform — RevenueCat's
    // hosted sheet is only reached as a fallback when an offering has no
    // matching package (see RevenueCatService.purchase*). `fromPaywall` is
    // the paywall's own buttons asking for the direct store purchase.
    if (!fromPaywall) {
      return _showPaywall(context, false);
    } else if (_revenueCatService != null) {
      return _revenueCatService!.purchaseFullVersion(
        context,
        directPurchase: fromPaywall,
      );
    } else if (_windowsIapService != null) {
      return _windowsIapService!.purchaseFullVersion();
    }
  }

  /// Purchase a subscription.
  Future<void> purchaseSubscription(
    BuildContext context, {
    SubscriptionPlan plan = SubscriptionPlan.monthly,
    bool fromPaywall = false,
  }) async {
    if (!fromPaywall) {
      return _showPaywall(context, true);
    } else if (_revenueCatService != null) {
      return _revenueCatService!.purchaseSubscription(
        context,
        directPurchase: fromPaywall,
        yearly: plan == SubscriptionPlan.yearly,
      );
    } else if (_windowsIapService != null) {
      return _windowsIapService!.purchaseSubscription(
        context,
        yearly: plan == SubscriptionPlan.yearly,
      );
    }
  }

  Future<void> _showPaywall(BuildContext context, bool subscription) async {
    // openDrawer needs a DrawerOverlay ancestor (Scaffold creates one) and does
    // `parentLayer!` in release, so a caller that hands us a context from above
    // its own Scaffold turns "Go Pro" into a bare "Null check operator used on
    // a null value" toast and the paywall never opens. Callers should pass a
    // context below the Scaffold, but the paywall is the last thing that should
    // break when one doesn't — fall back to a dialog, which only needs a
    // Navigator. Paywall already constrains and scrolls itself.
    if (DrawerOverlay.maybeFind(context) == null) {
      await showDialog<void>(
        context: context,
        builder: (c) => Paywall(defaultToFullVersion: !subscription),
      );
      return;
    }
    openDrawer(
      context: context,
      // The paywall scrolls, which swallows the drawer's own swipe-to-close —
      // SheetPullToDismiss restores it (pull down past the top).
      builder: (c) => SheetPullToDismiss(child: Paywall(defaultToFullVersion: !subscription)),
      position: OverlayPosition.bottom,
    );
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

  bool get isOutsideStoreWindowsBuild =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.windows && WindowsStoreEnvironment.isOutsideStoreCached;

  /// Check if user is logged in (Windows Stripe requires this)
  bool get isWindowsLoggedIn => _windowsIapService?.isLoggedIn ?? false;

  /// Open Stripe Billing Portal (Windows only)
  /// Returns false if user has no Stripe customer (should hide button)
  Future<bool> openBillingPortal(BuildContext context) async {
    if (_revenueCatService != null) {
      return _revenueCatService!.openBillingPortal(context);
    } else if (_windowsIapService != null) {
      return _windowsIapService!.openBillingPortal(context);
    } else {
      return false;
    }
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
          await _revenueCatService?.logInWithSupabaseUserId(
            userId,
            performSync: [AuthChangeEvent.initialSession, AuthChangeEvent.signedIn].contains(event),
          );
        }
        await _revenueCatService?.setAttributes();
        await entitlements.refresh(force: true);
        _syncPurchaseFlagFromEntitlements();
        // A rider who tapped Buy on the Windows Stripe build while logged out was
        // sent to the login gate; a genuine `signedIn` is our cue to finish the
        // checkout they started. Skip token refreshes / the initial session,
        // which are not a fresh login and would fire on every launch.
        if (event == AuthChangeEvent.signedIn) {
          await _windowsIapService?.resumePendingPurchaseAfterLogin(isAlreadyPro: isProEnabled);
        }
        return;
      case AuthChangeEvent.signedOut:
      // ignore: deprecated_member_use
      case AuthChangeEvent.userDeleted:
        await _revenueCatService?.logOut();
        await entitlements.clearCache();
        // reset isPurchased value
        if (Platform.isWindows) {
          await _windowsIapService?.initialize();
        } else if (Platform.isIOS || Platform.isMacOS || Platform.isAndroid) {
          await _revenueCatService?.initialize();
        }
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
    } else if (isOutsideStoreWindowsBuild && entitlements.hasActive(fullVersionProductKey)) {
      isPurchased.value = true;
    }
  }

  /// Registers this device for the account's Pro subscription and refreshes
  /// the entitlements, so [isProEnabledForCurrentDevice] reflects the result.
  /// One call shared by the Registered Devices view, the home banner, the
  /// virtual-shifting notice and the post-purchase dialog. Throws
  /// [DeviceLimitReachedError] when the platform's device limit is reached —
  /// the rider then has to pick a device to revoke.
  Future<void> registerCurrentDevice() async {
    final platform = await deviceManagement.currentPlatform();
    final package = await PackageInfo.fromPlatform();
    await deviceManagement.registerCurrentDevice(
      deviceName: 'BikeControl ${platform?.toUpperCase() ?? ''}',
      appVersion: package.version,
    );
    await entitlements.refresh(force: true);
  }

  /// [featureName] names the gated feature in the upgrade dialog — see
  /// [showGoProDialog].
  Future<bool> ensureProForFeature(
    BuildContext context, {
    bool isAllowedForOldPurchases = false,
    String? featureName,
  }) async {
    if (isProEnabledForCurrentDevice || (isAllowedForOldPurchases && hasPurchasedBefore50RVC)) {
      return true;
    } else if (isProEnabled) {
      buildToast(title: AppLocalizations.of(context).currentDeviceIsNotRegistered);
      return isProEnabledForCurrentDevice;
    } else {
      await showGoProDialog(context, featureName: featureName);
    }
    return IAPManager.instance.hasActiveSubscription;
  }

  void setWinBoughtBefore50() {
    _windowsIapService?.setBoughtBefore50();
  }
}
