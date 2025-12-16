import 'dart:io';

import 'package:bike_control/gen/l10n.dart';
import 'package:bike_control/utils/iap/iap_service.dart';
import 'package:bike_control/utils/iap/windows_iap_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Unified IAP manager that handles platform-specific IAP services
class IAPManager {
  static IAPManager? _instance;
  static IAPManager get instance {
    _instance ??= IAPManager._();
    return _instance!;
  }

  static const int dailyCommandLimit = 15;
  IAPService? _iapService;
  WindowsIAPService? _windowsIapService;
  ValueNotifier<bool> isPurchased = ValueNotifier<bool>(false);

  IAPManager._();

  /// Initialize the IAP manager
  Future<void> initialize() async {
    final prefs = FlutterSecureStorage(aOptions: AndroidOptions());

    if (kIsWeb) {
      // Web doesn't support IAP
      return;
    }

    try {
      if (Platform.isWindows) {
        _windowsIapService = WindowsIAPService(prefs);
        await _windowsIapService!.initialize();
      } else if (Platform.isIOS || Platform.isMacOS || Platform.isAndroid) {
        _iapService = IAPService(prefs);
        await _iapService!.initialize();
      }
    } catch (e) {
      debugPrint('Error initializing IAP manager: $e');
    }
  }

  /// Check if the trial period has started
  bool get hasTrialStarted {
    if (_iapService != null) {
      return _iapService!.hasTrialStarted;
    } else if (_windowsIapService != null) {
      return _windowsIapService!.hasTrialStarted;
    }
    return false;
  }

  /// Start the trial period
  Future<void> startTrial() async {
    if (_iapService != null) {
      await _iapService!.startTrial();
    }
  }

  /// Get the number of days remaining in the trial
  int get trialDaysRemaining {
    if (_iapService != null) {
      return _iapService!.trialDaysRemaining;
    } else if (_windowsIapService != null) {
      return _windowsIapService!.trialDaysRemaining;
    }
    return 0;
  }

  /// Check if the trial has expired
  bool get isTrialExpired {
    if (_iapService != null) {
      return _iapService!.isTrialExpired;
    } else if (_windowsIapService != null) {
      return _windowsIapService!.isTrialExpired;
    }
    return false;
  }

  /// Check if the user can execute a command
  bool get canExecuteCommand {
    // If IAP is not initialized or not available, allow commands
    if (_iapService == null && _windowsIapService == null) return true;

    if (_iapService != null) {
      return _iapService!.canExecuteCommand;
    } else if (_windowsIapService != null) {
      return _windowsIapService!.canExecuteCommand;
    }
    return true; // Default to true for platforms without IAP
  }

  /// Get the number of commands remaining today (for free tier after trial)
  int get commandsRemainingToday {
    if (_iapService != null) {
      return _iapService!.commandsRemainingToday;
    } else if (_windowsIapService != null) {
      return _windowsIapService!.commandsRemainingToday;
    }
    return -1; // Unlimited
  }

  /// Get the daily command count
  int get dailyCommandCount {
    if (_iapService != null) {
      return _iapService!.dailyCommandCount;
    } else if (_windowsIapService != null) {
      return _windowsIapService!.dailyCommandCount;
    }
    return 0;
  }

  /// Increment the daily command count
  Future<void> incrementCommandCount() async {
    if (_iapService != null) {
      await _iapService!.incrementCommandCount();
    } else if (_windowsIapService != null) {
      await _windowsIapService!.incrementCommandCount();
    }
  }

  /// Get a status message for the user
  String getStatusMessage() {
    /// Get a status message for the user
    if (IAPManager.instance.isPurchased.value) {
      return AppLocalizations.current.fullVersion;
    } else if (!hasTrialStarted) {
      return '${_iapService?.trialDaysRemaining ?? _windowsIapService?.trialDaysRemaining} day trial available';
    } else if (!isTrialExpired) {
      return AppLocalizations.current.trialDaysRemaining(trialDaysRemaining);
    } else {
      return AppLocalizations.current.commandsRemainingToday(commandsRemainingToday, dailyCommandLimit);
    }
  }

  /// Purchase the full version
  Future<bool> purchaseFullVersion() async {
    if (_iapService != null) {
      return await _iapService!.purchaseFullVersion();
    } else if (_windowsIapService != null) {
      return await _windowsIapService!.purchaseFullVersion();
    }
    return false;
  }

  /// Restore previous purchases
  Future<void> restorePurchases() async {
    if (_iapService != null) {
      await _iapService!.restorePurchases();
    }
    // Windows doesn't have a separate restore mechanism in the stub
  }

  /// Dispose the manager
  void dispose() {
    _iapService?.dispose();
    _windowsIapService?.dispose();
  }

  void reset() {
    _windowsIapService?.reset();
    _iapService?.reset();
  }
}
