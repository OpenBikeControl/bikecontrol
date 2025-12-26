import 'dart:async';
import 'dart:io';

import 'package:bike_control/bluetooth/messages/notification.dart';
import 'package:bike_control/main.dart';
import 'package:bike_control/utils/core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:purchases_ui_flutter/purchases_ui_flutter.dart';

/// RevenueCat-based IAP service for iOS, macOS, and Android
class RevenueCatService {
  static const int trialDays = 5;

  static const String _trialStartDateKey = 'iap_trial_start_date';
  static const String _purchaseStatusKey = 'iap_purchase_status';
  static const String _dailyCommandCountKey = 'iap_daily_command_count';
  static const String _lastCommandDateKey = 'iap_last_command_date';
  static const String _lastPurchaseCheckKey = 'iap_last_purchase_check';

  // RevenueCat entitlement identifier
  static const String fullVersionEntitlement = 'Full Version';

  final FlutterSecureStorage _prefs;
  final ValueNotifier<bool> isPurchasedNotifier;
  final int Function() getDailyCommandLimit;
  final void Function(int limit) setDailyCommandLimit;

  bool _isInitialized = false;
  String? _trialStartDate;
  String? _lastCommandDate;
  int? _dailyCommandCount;
  StreamSubscription<CustomerInfo>? _customerInfoSubscription;

  RevenueCatService(
    this._prefs, {
    required this.isPurchasedNotifier,
    required this.getDailyCommandLimit,
    required this.setDailyCommandLimit,
  });

  /// Initialize the RevenueCat service
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // Skip RevenueCat initialization on web or unsupported platforms
      if (kIsWeb) {
        debugPrint('RevenueCat not supported on web');
        _isInitialized = true;
        return;
      }

      // Get API key from environment variable
      final apiKey = Platform.environment['REVENUECAT_API_KEY'] ?? 
                     String.fromEnvironment('REVENUECAT_API_KEY');

      if (apiKey.isEmpty) {
        debugPrint('RevenueCat API key not found in environment');
        core.connection.signalNotification(
          LogNotification('RevenueCat API key not configured'),
        );
        isPurchasedNotifier.value = false;
        _isInitialized = true;
        return;
      }

      // Configure RevenueCat
      final configuration = PurchasesConfiguration(apiKey);
      
      // Enable debug logs in debug mode
      if (kDebugMode) {
        configuration.logLevel = LogLevel.debug;
      }

      await Purchases.configure(configuration);

      debugPrint('RevenueCat initialized successfully');
      core.connection.signalNotification(
        LogNotification('RevenueCat initialized'),
      );

      // Listen for customer info updates
      _customerInfoSubscription = Purchases.addCustomerInfoUpdateListener((customerInfo) {
        _handleCustomerInfoUpdate(customerInfo);
      });

      _trialStartDate = await _prefs.read(key: _trialStartDateKey);
      core.connection.signalNotification(
        LogNotification('Trial start date: $_trialStartDate => $trialDaysRemaining'),
      );

      _lastCommandDate = await _prefs.read(key: _lastCommandDateKey);
      final commandCount = await _prefs.read(key: _dailyCommandCountKey) ?? '0';
      _dailyCommandCount = int.tryParse(commandCount);

      // Check existing purchase status
      await _checkExistingPurchase();

      _isInitialized = true;

      if (!isTrialExpired && Platform.isAndroid) {
        setDailyCommandLimit(80);
      }
    } catch (e, s) {
      recordError(e, s, context: 'Initializing RevenueCat Service');
      core.connection.signalNotification(
        AlertNotification(
          LogLevel.LOGLEVEL_ERROR,
          'There was an error initializing RevenueCat: ${e.toString()}',
        ),
      );
      debugPrint('Failed to initialize RevenueCat: $e');
      isPurchasedNotifier.value = false;
      _isInitialized = true;
    }
  }

  /// Check if the user has an active entitlement
  Future<void> _checkExistingPurchase() async {
    try {
      // First check if we have a stored purchase status
      final storedStatus = await _prefs.read(key: _purchaseStatusKey);
      final lastPurchaseCheck = await _prefs.read(key: _lastPurchaseCheckKey);
      
      final todayDate = DateTime.now().toIso8601String().split('T')[0];

      if (storedStatus == "true") {
        if (Platform.isAndroid) {
          if (lastPurchaseCheck == todayDate) {
            isPurchasedNotifier.value = true;
            return;
          }
        } else {
          isPurchasedNotifier.value = true;
          return;
        }
      }

      await _prefs.write(key: _lastPurchaseCheckKey, value: todayDate);

      // Check current entitlement status from RevenueCat
      final customerInfo = await Purchases.getCustomerInfo();
      _handleCustomerInfoUpdate(customerInfo);
    } catch (e, s) {
      debugPrint('Error checking existing purchase: $e');
      recordError(e, s, context: 'Checking existing purchase');
    }
  }

  /// Handle customer info updates from RevenueCat
  void _handleCustomerInfoUpdate(CustomerInfo customerInfo) {
    final hasEntitlement = customerInfo.entitlements.active.containsKey(fullVersionEntitlement);
    
    debugPrint('RevenueCat entitlement check: $hasEntitlement');
    core.connection.signalNotification(
      LogNotification('Full Version entitlement: $hasEntitlement'),
    );

    isPurchasedNotifier.value = hasEntitlement;

    if (hasEntitlement) {
      _prefs.write(key: _purchaseStatusKey, value: "true");
    }
  }

  /// Present the RevenueCat paywall
  Future<void> presentPaywall() async {
    try {
      if (!_isInitialized) {
        await initialize();
      }

      final paywallResult = await RevenueCatUI.presentPaywall();
      
      debugPrint('Paywall result: $paywallResult');
      
      // The customer info listener will handle the purchase update
    } catch (e, s) {
      debugPrint('Error presenting paywall: $e');
      recordError(e, s, context: 'Presenting paywall');
      core.connection.signalNotification(
        AlertNotification(
          LogLevel.LOGLEVEL_ERROR,
          'There was an error displaying the paywall: ${e.toString()}',
        ),
      );
    }
  }

  /// Present the Customer Center
  Future<void> presentCustomerCenter() async {
    try {
      if (!_isInitialized) {
        await initialize();
      }

      await RevenueCatUI.presentCustomerCenter();
    } catch (e, s) {
      debugPrint('Error presenting customer center: $e');
      recordError(e, s, context: 'Presenting customer center');
      core.connection.signalNotification(
        AlertNotification(
          LogLevel.LOGLEVEL_ERROR,
          'There was an error displaying customer center: ${e.toString()}',
        ),
      );
    }
  }

  /// Restore previous purchases
  Future<void> restorePurchases() async {
    try {
      final customerInfo = await Purchases.restorePurchases();
      _handleCustomerInfoUpdate(customerInfo);
      
      core.connection.signalNotification(
        LogNotification('Purchases restored'),
      );
    } catch (e, s) {
      core.connection.signalNotification(
        AlertNotification(
          LogLevel.LOGLEVEL_ERROR,
          'There was an error restoring purchases: ${e.toString()}',
        ),
      );
      recordError(e, s, context: 'Restore Purchases');
      debugPrint('Error restoring purchases: $e');
    }
  }

  /// Purchase the full version (use paywall instead)
  Future<void> purchaseFullVersion() async {
    // Direct the user to the paywall for a better experience
    await presentPaywall();
  }

  /// Check if the trial period has started
  bool get hasTrialStarted {
    return _trialStartDate != null;
  }

  /// Start the trial period
  Future<void> startTrial() async {
    if (!hasTrialStarted) {
      await _prefs.write(key: _trialStartDateKey, value: DateTime.now().toIso8601String());
    }
  }

  /// Get the number of days remaining in the trial
  int get trialDaysRemaining {
    if (isPurchasedNotifier.value) return 0;

    final trialStart = _trialStartDate;
    if (trialStart == null) return trialDays;

    final startDate = DateTime.parse(trialStart);
    final now = DateTime.now();
    final daysPassed = now.difference(startDate).inDays;
    final remaining = trialDays - daysPassed;

    return remaining > 0 ? remaining : 0;
  }

  /// Check if the trial has expired
  bool get isTrialExpired {
    return (!isPurchasedNotifier.value && hasTrialStarted && trialDaysRemaining <= 0);
  }

  /// Get the number of commands executed today
  int get dailyCommandCount {
    final lastDate = _lastCommandDate;
    final today = DateTime.now().toIso8601String().split('T')[0];

    if (lastDate != today) {
      // Reset counter for new day
      _lastCommandDate = today;
      _dailyCommandCount = 0;
    }

    return _dailyCommandCount ?? 0;
  }

  /// Increment the daily command count
  Future<void> incrementCommandCount() async {
    final today = DateTime.now().toIso8601String().split('T')[0];
    final lastDate = await _prefs.read(key: _lastCommandDateKey);

    if (lastDate != today) {
      // Reset counter for new day
      _lastCommandDate = today;
      _dailyCommandCount = 1;
      await _prefs.write(key: _lastCommandDateKey, value: today);
      await _prefs.write(key: _dailyCommandCountKey, value: '1');
    } else {
      final count = _dailyCommandCount ?? 0;
      _dailyCommandCount = count + 1;
      await _prefs.write(key: _dailyCommandCountKey, value: _dailyCommandCount.toString());
    }
  }

  /// Check if the user can execute a command
  bool get canExecuteCommand {
    if (isPurchasedNotifier.value) return true;
    if (!isTrialExpired && !Platform.isAndroid) return true;
    return dailyCommandCount < getDailyCommandLimit();
  }

  /// Get the number of commands remaining today (for free tier after trial)
  int get commandsRemainingToday {
    if (isPurchasedNotifier.value || (!isTrialExpired && !Platform.isAndroid)) return -1; // Unlimited
    final remaining = getDailyCommandLimit() - dailyCommandCount;
    return remaining > 0 ? remaining : 0; // Never return negative
  }

  /// Dispose the service
  void dispose() {
    _customerInfoSubscription?.cancel();
  }

  void reset(bool fullReset) async {
    if (fullReset) {
      await _prefs.deleteAll();
    } else {
      await _prefs.delete(key: _purchaseStatusKey);
      _isInitialized = false;
      await initialize();
    }
  }

  Future<void> redeem() async {
    isPurchasedNotifier.value = true;
    await _prefs.write(key: _purchaseStatusKey, value: isPurchasedNotifier.value.toString());
  }

  /// Get customer info from RevenueCat
  Future<CustomerInfo?> getCustomerInfo() async {
    try {
      return await Purchases.getCustomerInfo();
    } catch (e) {
      debugPrint('Error getting customer info: $e');
      return null;
    }
  }

  /// Get available offerings
  Future<Offerings?> getOfferings() async {
    try {
      return await Purchases.getOfferings();
    } catch (e) {
      debugPrint('Error getting offerings: $e');
      return null;
    }
  }
}
