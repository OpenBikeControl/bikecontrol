import 'dart:async';

import 'package:bike_control/utils/core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:version/version.dart';
import 'package:windows_iap/windows_iap.dart';

/// Windows-specific IAP service
/// Note: This is a stub implementation. For actual Windows Store integration,
/// you would need to use the Windows Store APIs through platform channels.
class WindowsIAPService {
  static const String productId = 'full_access_unlock';
  static const int trialDays = 5;
  static const int dailyCommandLimit = 15;

  static const String _trialStartDateKey = 'iap_trial_start_date';
  static const String _purchaseStatusKey = 'iap_purchase_status';
  static const String _dailyCommandCountKey = 'iap_daily_command_count';
  static const String _lastCommandDateKey = 'iap_last_command_date';

  final FlutterSecureStorage _prefs;

  bool _isPurchased = false;
  bool _isInitialized = false;

  String? _trialStartDate;
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

      _trialStartDate = await _prefs.read(key: _trialStartDateKey);
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
      _isPurchased = true;
      return;
    }
    _windowsIapPlugin.
    // TODO: Add Windows Store API integration
    // Check if the app was purchased from the Windows Store
    // This would require platform channel implementation to call Windows Store APIs

    // For now, we'll check if there's a previous version installed
    await _checkPreviousVersion();
  }

  /// Check if user had the paid version before
  Future<void> _checkPreviousVersion() async {
    try {
      // IMPORTANT: This assumes the app is currently paid and this update will be released
      // while the app is still paid. Only users who downloaded the paid version will have
      // a last_seen_version. After changing the app to free, new users won't have this set.
      final lastSeenVersion = core.settings.getLastSeenVersion();
      if (lastSeenVersion != null && lastSeenVersion.isNotEmpty) {
        Version lastVersion = Version.parse(lastSeenVersion);
        // If they had a previous version, they're an existing paid user
        _isPurchased = lastVersion < Version(4, 2, 0);
        if (_isPurchased) {
          await _prefs.write(key: _purchaseStatusKey, value: "true");
        }
        debugPrint('Existing Android user detected - granting full access');
      }
    } catch (e) {
      debugPrint('Error checking Windows previous version: $e');
    }
  }

  /// Purchase the full version
  /// TODO: Implement actual Windows Store purchase flow
  Future<bool> purchaseFullVersion() async {
    try {
      debugPrint('Windows Store purchase would be triggered here');
      // This would call the Windows Store IAP APIs through a platform channel
      return false;
    } catch (e) {
      debugPrint('Error purchasing on Windows: $e');
      return false;
    }
  }

  /// Get remaining trial days from Windows Store
  /// TODO: Implement Windows Store trial API
  Future<int> getRemainingTrialDays() async {
    try {
      // This would call Windows Store APIs to get trial information
      // For now, use local calculation
      return trialDaysRemaining;
    } catch (e) {
      debugPrint('Error getting trial days from Windows Store: $e');
      return trialDaysRemaining;
    }
  }

  /// Check if the user has purchased the full version
  bool get isPurchased => _isPurchased;

  /// Check if the trial period has started
  bool get hasTrialStarted => _trialStartDate != null;

  /// Start the trial period
  Future<void> startTrial() async {
    if (!hasTrialStarted) {
      await _prefs.write(key: _trialStartDateKey, value: DateTime.now().toIso8601String());
    }
  }

  /// Get the number of days remaining in the trial
  int get trialDaysRemaining {
    if (_isPurchased) return 0;

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
    return !_isPurchased && hasTrialStarted && trialDaysRemaining <= 0;
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
    if (_isPurchased) return true;
    if (!isTrialExpired) return true;
    return dailyCommandCount < dailyCommandLimit;
  }

  /// Get the number of commands remaining today (for free tier after trial)
  int get commandsRemainingToday {
    if (_isPurchased || !isTrialExpired) return -1; // Unlimited
    final remaining = dailyCommandLimit - dailyCommandCount;
    return remaining > 0 ? remaining : 0; // Never return negative
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
    // Nothing to dispose for Windows
  }
}
