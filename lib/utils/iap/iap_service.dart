import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// Service to handle in-app purchase functionality and trial period management
class IAPService {
  static const String productId = 'full_access_unlock';
  static const int trialDays = 5;
  static const int dailyCommandLimit = 15;
  
  static const String _trialStartDateKey = 'iap_trial_start_date';
  static const String _purchaseStatusKey = 'iap_purchase_status';
  static const String _dailyCommandCountKey = 'iap_daily_command_count';
  static const String _lastCommandDateKey = 'iap_last_command_date';
  
  final InAppPurchase _inAppPurchase = InAppPurchase.instance;
  final SharedPreferences _prefs;
  
  StreamSubscription<List<PurchaseDetails>>? _subscription;
  bool _isPurchased = false;
  bool _isInitialized = false;
  
  IAPService(this._prefs);
  
  /// Initialize the IAP service
  Future<void> initialize() async {
    if (_isInitialized) return;
    
    try {
      // Check if IAP is available on this platform
      final available = await _inAppPurchase.isAvailable();
      if (!available) {
        debugPrint('IAP not available on this platform');
        _isInitialized = true;
        return;
      }
      
      // Listen for purchase updates
      _subscription = _inAppPurchase.purchaseStream.listen(
        _onPurchaseUpdate,
        onDone: () => _subscription?.cancel(),
        onError: (error) => debugPrint('IAP Error: $error'),
      );
      
      // Check if already purchased
      await _checkExistingPurchase();
      
      _isInitialized = true;
    } catch (e) {
      debugPrint('Failed to initialize IAP: $e');
      _isInitialized = true;
    }
  }
  
  /// Check if the user has already purchased the app
  Future<void> _checkExistingPurchase() async {
    // First check if we have a stored purchase status
    final storedStatus = _prefs.getBool(_purchaseStatusKey);
    if (storedStatus == true) {
      _isPurchased = true;
      return;
    }
    
    // Platform-specific checks for existing paid app purchases
    if (Platform.isIOS || Platform.isMacOS) {
      // On iOS/macOS, check if the app was previously purchased (has a receipt)
      await _checkAppleReceipt();
    } else if (Platform.isAndroid) {
      // On Android, check if user had the paid version before
      await _checkAndroidPreviousPurchase();
    }
    
    // Also check for IAP purchase
    if (!_isPurchased) {
      await _restorePurchases();
    }
  }
  
  /// Check for Apple receipt (iOS/macOS)
  Future<void> _checkAppleReceipt() async {
    try {
      // If there's an app store receipt, the app was purchased
      // This is a simplified check - in production you'd verify the receipt
      // For now, we'll check if we can restore purchases
      await _restorePurchases();
    } catch (e) {
      debugPrint('Error checking Apple receipt: $e');
    }
  }
  
  /// Check if Android user had the paid app before
  Future<void> _checkAndroidPreviousPurchase() async {
    try {
      // On Android, we use the last seen version to determine if they had the paid version
      // If the version exists and is from before the IAP transition, grant access
      final lastSeenVersion = _prefs.getString('last_seen_version');
      if (lastSeenVersion != null) {
        // If they had a previous version, they're an existing user
        final packageInfo = await PackageInfo.fromPlatform();
        final currentVersion = packageInfo.version;
        
        // If last seen version exists and is different from first install, they're existing users
        if (lastSeenVersion.isNotEmpty) {
          _isPurchased = true;
          await _prefs.setBool(_purchaseStatusKey, true);
          debugPrint('Existing Android user detected - granting full access');
        }
      }
    } catch (e) {
      debugPrint('Error checking Android previous purchase: $e');
    }
  }
  
  /// Restore previous purchases
  Future<void> _restorePurchases() async {
    try {
      await _inAppPurchase.restorePurchases();
      // The purchase stream will be called with restored purchases
    } catch (e) {
      debugPrint('Error restoring purchases: $e');
    }
  }
  
  /// Handle purchase updates
  void _onPurchaseUpdate(List<PurchaseDetails> purchaseDetailsList) {
    for (final purchase in purchaseDetailsList) {
      if (purchase.status == PurchaseStatus.purchased ||
          purchase.status == PurchaseStatus.restored) {
        _isPurchased = true;
        _prefs.setBool(_purchaseStatusKey, true);
        debugPrint('Purchase successful or restored');
      }
      
      // Complete the purchase
      if (purchase.pendingCompletePurchase) {
        _inAppPurchase.completePurchase(purchase);
      }
    }
  }
  
  /// Purchase the full version
  Future<bool> purchaseFullVersion() async {
    try {
      if (!_isInitialized) {
        await initialize();
      }
      
      final available = await _inAppPurchase.isAvailable();
      if (!available) {
        debugPrint('IAP not available');
        return false;
      }
      
      // Query product details
      final response = await _inAppPurchase.queryProductDetails({productId});
      if (response.error != null) {
        debugPrint('Error querying products: ${response.error}');
        return false;
      }
      
      if (response.productDetails.isEmpty) {
        debugPrint('Product not found: $productId');
        return false;
      }
      
      final product = response.productDetails.first;
      final purchaseParam = PurchaseParam(productDetails: product);
      
      return await _inAppPurchase.buyNonConsumable(purchaseParam: purchaseParam);
    } catch (e) {
      debugPrint('Error purchasing: $e');
      return false;
    }
  }
  
  /// Check if the user has purchased the full version
  bool get isPurchased => _isPurchased;
  
  /// Check if the trial period has started
  bool get hasTrialStarted {
    final trialStart = _prefs.getString(_trialStartDateKey);
    return trialStart != null;
  }
  
  /// Start the trial period
  Future<void> startTrial() async {
    if (!hasTrialStarted) {
      await _prefs.setString(_trialStartDateKey, DateTime.now().toIso8601String());
    }
  }
  
  /// Get the number of days remaining in the trial
  int get trialDaysRemaining {
    if (_isPurchased) return 0;
    
    final trialStart = _prefs.getString(_trialStartDateKey);
    if (trialStart == null) return trialDays;
    
    final startDate = DateTime.parse(trialStart);
    final now = DateTime.now();
    final daysPassed = now.difference(startDate).inDays;
    final remaining = trialDays - daysPassed;
    
    return remaining > 0 ? remaining : 0;
  }
  
  /// Check if the trial has expired
  bool get isTrialExpired {
    return !_isPurchased && hasTrialStarted && trialDaysRemaining <= 0;
  }
  
  /// Check if the user has access (purchased or still in trial)
  bool get hasAccess {
    return _isPurchased || !isTrialExpired;
  }
  
  /// Get the number of commands executed today
  int get dailyCommandCount {
    final lastDate = _prefs.getString(_lastCommandDateKey);
    final today = DateTime.now().toIso8601String().split('T')[0];
    
    if (lastDate != today) {
      // Reset counter for new day
      return 0;
    }
    
    return _prefs.getInt(_dailyCommandCountKey) ?? 0;
  }
  
  /// Increment the daily command count
  Future<void> incrementCommandCount() async {
    final today = DateTime.now().toIso8601String().split('T')[0];
    final lastDate = _prefs.getString(_lastCommandDateKey);
    
    if (lastDate != today) {
      // Reset counter for new day
      await _prefs.setString(_lastCommandDateKey, today);
      await _prefs.setInt(_dailyCommandCountKey, 1);
    } else {
      final count = _prefs.getInt(_dailyCommandCountKey) ?? 0;
      await _prefs.setInt(_dailyCommandCountKey, count + 1);
    }
  }
  
  /// Check if the user can execute a command
  bool get canExecuteCommand {
    if (_isPurchased) return true;
    if (!isTrialExpired) return true;
    return dailyCommandCount < dailyCommandLimit;
  }
  
  /// Get the number of commands remaining today (for free tier after trial)
  int get commandsRemainingToday {
    if (_isPurchased || !isTrialExpired) return -1; // Unlimited
    return dailyCommandLimit - dailyCommandCount;
  }
  
  /// Get a status message for the user
  String getStatusMessage() {
    if (_isPurchased) {
      return 'Full version unlocked';
    } else if (!hasTrialStarted) {
      return '$trialDays day trial available';
    } else if (!isTrialExpired) {
      return '$trialDaysRemaining days remaining in trial';
    } else {
      return '$commandsRemainingToday/$dailyCommandLimit commands remaining today';
    }
  }
  
  /// Dispose the service
  void dispose() {
    _subscription?.cancel();
  }
}
