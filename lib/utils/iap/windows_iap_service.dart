import 'dart:async';

import 'package:bike_control/utils/iap/iap_manager.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:windows_iap/windows_iap.dart';

/// Windows-specific IAP service
/// Note: This is a stub implementation. For actual Windows Store integration,
/// you would need to use the Windows Store APIs through platform channels.
class WindowsIAPService {
  static const String productId = '9NP42GS03Z26';
  static const int trialDays = 5;
  static const int dailyCommandLimit = 15;

  static const String _purchaseStatusKey = 'iap_purchase_status';
  static const String _dailyCommandCountKey = 'iap_daily_command_count';
  static const String _lastCommandDateKey = 'iap_last_command_date';

  final FlutterSecureStorage _prefs;

  bool _isInitialized = false;

  String? _lastCommandDate;
  int? _dailyCommandCount;

  final _windowsIapPlugin = WindowsIap();

  WindowsIAPService(this._prefs);

  /// Initialize the Windows IAP service
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // Check if already purchased
      await _checkExistingPurchase();

      _lastCommandDate = await _prefs.read(key: _lastCommandDateKey);
      _dailyCommandCount = int.tryParse(await _prefs.read(key: _dailyCommandCountKey) ?? '0');
      _isInitialized = true;
    } catch (e) {
      debugPrint('Failed to initialize Windows IAP: $e');
      _isInitialized = true;
    }
  }

  /// Check if the user has already purchased the app
  Future<void> _checkExistingPurchase() async {
    // First check if we have a stored purchase status
    final storedStatus = await _prefs.read(key: _purchaseStatusKey);
    if (storedStatus == "true") {
      IAPManager.instance.isPurchased.value = true;
      return;
    }
    final trial = await _windowsIapPlugin.getTrialStatusAndRemainingDays();
    trialDaysRemaining = trial.remainingDays;
    if (!trial.isTrial && trial.remainingDays <= 0) {
      IAPManager.instance.isPurchased.value = true;
      await _prefs.write(key: _purchaseStatusKey, value: "true");
    } else {
      IAPManager.instance.isPurchased.value = false;
    }
  }

  /// Purchase the full version
  /// TODO: Implement actual Windows Store purchase flow
  Future<bool> purchaseFullVersion() async {
    try {
      final status = await _windowsIapPlugin.makePurchase(productId);
      return status == StorePurchaseStatus.succeeded || status == StorePurchaseStatus.alreadyPurchased;
    } catch (e) {
      debugPrint('Error purchasing on Windows: $e');
      return false;
    }
  }

  /// Check if the trial period has started
  bool get hasTrialStarted => trialDaysRemaining > 0;

  /// Get the number of days remaining in the trial
  int trialDaysRemaining = 0;

  /// Check if the trial has expired
  bool get isTrialExpired {
    return !IAPManager.instance.isPurchased.value && hasTrialStarted && trialDaysRemaining <= 0;
  }

  /// Get the number of commands executed today
  int get dailyCommandCount {
    final lastDate = _lastCommandDate;
    final today = DateTime.now().toIso8601String().split('T')[0];

    if (lastDate != today) {
      // Reset counter for new day
      return 0;
    }

    return _dailyCommandCount ?? 0;
  }

  /// Increment the daily command count
  Future<void> incrementCommandCount() async {
    final today = DateTime.now().toIso8601String().split('T')[0];
    final lastDate = _lastCommandDate;

    if (lastDate != today) {
      // Reset counter for new day
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
    if (IAPManager.instance.isPurchased.value) return true;
    if (!isTrialExpired) return true;
    return dailyCommandCount < dailyCommandLimit;
  }

  /// Get the number of commands remaining today (for free tier after trial)
  int get commandsRemainingToday {
    if (IAPManager.instance.isPurchased.value || !isTrialExpired) return -1; // Unlimited
    final remaining = dailyCommandLimit - dailyCommandCount;
    return remaining > 0 ? remaining : 0; // Never return negative
  }

  /// Get a status message for the user
  String getStatusMessage() {
    if (IAPManager.instance.isPurchased.value) {
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
    // Nothing to dispose for Windows
  }
}
