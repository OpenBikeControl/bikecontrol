import 'package:bike_control/bluetooth/messages/notification.dart';
import 'package:bike_control/main.dart';
import 'package:bike_control/services/entitlements_service.dart';
import 'package:bike_control/services/windows_subscription_service.dart';
import 'package:bike_control/utils/core.dart';
import 'package:bike_control/utils/iap/iap_manager.dart';
import 'package:bike_control/utils/windows_store_environment.dart';
import 'package:bike_control/widgets/ui/toast.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:windows_iap/windows_iap.dart';

/// Windows-specific IAP service for Microsoft Store purchases and server-side sync.
class WindowsIAPService {
  static const String productId = '9NP42GS03Z26';
  static const String subscriptionStoreProductId = 'TODO_WINDOWS_SUBSCRIPTION_PRODUCT_STORE_ID';
  static const int trialDays = 7;
  static const int dailyCommandLimit = 15;

  static const String _purchaseStatusKey = 'iap_purchase_status_2';
  static const String _dailyCommandCountKey = 'iap_daily_command_count';
  static const String _lastCommandDateKey = 'iap_last_command_date';

  final FlutterSecureStorage _prefs;
  final EntitlementsService _entitlementsService;
  final WindowsSubscriptionService _subscriptionService;

  bool _isInitialized = false;

  String? _lastCommandDate;
  int? _dailyCommandCount;

  final _windowsIapPlugin = WindowsIap();

  WindowsIAPService(
    this._prefs, {
    required EntitlementsService entitlementsService,
    required WindowsSubscriptionService subscriptionService,
  }) : _entitlementsService = entitlementsService,
       _subscriptionService = subscriptionService;

  /// Initialize the Windows IAP service
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      await _checkExistingPurchase();

      _lastCommandDate = await _prefs.read(key: _lastCommandDateKey);
      _dailyCommandCount = int.tryParse(await _prefs.read(key: _dailyCommandCountKey) ?? '0');
      _isInitialized = true;
    } catch (e, s) {
      recordError(e, s, context: 'Initializing');
      debugPrint('Failed to initialize Windows IAP: $e');
      _isInitialized = true;
    }
  }

  /// Check if the user has already purchased the app
  Future<void> _checkExistingPurchase() async {
    if (_entitlementsService.hasActive(IAPManager.premiumMonthlyProductKey)) {
      IAPManager.instance.isPurchased.value = true;
      return;
    }

    final storedStatus = await _prefs.read(key: _purchaseStatusKey);
    core.connection.signalNotification(LogNotification('Is purchased status: $storedStatus'));
    if (storedStatus == "true") {
      IAPManager.instance.isPurchased.value = true;
      return;
    }

    final trial = await _windowsIapPlugin.getTrialStatusAndRemainingDays();
    core.connection.signalNotification(LogNotification('Trial status: $trial'));
    final trialEndDate = trial.remainingDays;
    if (trial.isTrial && trialEndDate.isNotEmpty && !trialEndDate.contains("?")) {
      try {
        trialDaysRemaining = DateTime.parse(trialEndDate).difference(DateTime.now()).inDays;
      } catch (e) {
        core.connection.signalNotification(LogNotification('Error parsing trial end date: $e'));
        trialDaysRemaining = 0;
      }
    } else {
      final isStorePackaged = await WindowsStoreEnvironment.isPackaged();
      trial.isActive = isStorePackaged;
      trialDaysRemaining = 0;
    }

    if (trial.isActive && !trial.isTrial && trialDaysRemaining <= 0) {
      IAPManager.instance.isPurchased.value = true;
      await _prefs.write(key: _purchaseStatusKey, value: "true");
    } else {
      IAPManager.instance.isPurchased.value = false;
    }
  }

  /// Purchase and then sync subscription state to Supabase.
  Future<void> purchaseFullVersion() async {
    try {
      final status = await _windowsIapPlugin.makePurchase(productId);
      if (status == StorePurchaseStatus.succeeded || status == StorePurchaseStatus.alreadyPurchased) {
        await restoreOrSyncSubscription();
        IAPManager.instance.isPurchased.value = IAPManager.instance.isPremiumEnabled;
        buildToast(
          title: 'Purchase Successful',
          subtitle: IAPManager.instance.isPremiumEnabled
              ? 'Subscription activated successfully.'
              : 'Purchase complete. Sync may take a moment.',
        );
      }
    } catch (e, s) {
      recordError(e, s, context: 'Purchasing on Windows');
      debugPrint('Error purchasing on Windows: $e');
    }
  }

  Future<void> restoreOrSyncSubscription() async {
    try {
      await _subscriptionService.restoreOrSyncSubscription(
        productStoreId: subscriptionStoreProductId,
      );
      IAPManager.instance.isPurchased.value = IAPManager.instance.isPremiumEnabled;
    } catch (e, s) {
      recordError(e, s, context: 'Syncing Windows subscription');
      rethrow;
    }
  }

  /// Check if the trial period has started
  bool get hasTrialStarted => trialDaysRemaining >= 0;

  /// Get the number of days remaining in the trial
  int trialDaysRemaining = 0;

  /// Check if the trial has expired
  bool get isTrialExpired {
    if (IAPManager.instance.isPremiumEnabled) {
      return false;
    }
    return !IAPManager.instance.isPurchased.value && hasTrialStarted && trialDaysRemaining <= 0;
  }

  /// Get the number of commands executed today
  int get dailyCommandCount {
    final lastDate = _lastCommandDate;
    final today = DateTime.now().toIso8601String().split('T')[0];

    if (lastDate != today) {
      return 0;
    }

    return _dailyCommandCount ?? 0;
  }

  /// Increment the daily command count
  Future<void> incrementCommandCount() async {
    final today = DateTime.now().toIso8601String().split('T')[0];
    final lastDate = _lastCommandDate;

    if (lastDate != today) {
      _lastCommandDate = today;
      _dailyCommandCount = 1;
      await _prefs.write(key: _lastCommandDateKey, value: today);
      await _prefs.write(key: _dailyCommandCountKey, value: "1");
    } else {
      final count = _dailyCommandCount ?? 0;
      _dailyCommandCount = count + 1;
      await _prefs.write(key: _dailyCommandCountKey, value: _dailyCommandCount.toString());
    }
  }

  /// Check if the user can execute a command
  bool get canExecuteCommand {
    if (IAPManager.instance.isPremiumEnabled || IAPManager.instance.isPurchased.value) return true;
    if (!isTrialExpired) return true;
    return dailyCommandCount < dailyCommandLimit;
  }

  /// Get the number of commands remaining today (for free tier after trial)
  int get commandsRemainingToday {
    if (IAPManager.instance.isPremiumEnabled || IAPManager.instance.isPurchased.value || !isTrialExpired) {
      return -1;
    }
    final remaining = dailyCommandLimit - dailyCommandCount;
    return remaining > 0 ? remaining : 0;
  }

  /// Dispose the service
  void dispose() {}

  void reset() {
    _prefs.deleteAll();
  }
}
