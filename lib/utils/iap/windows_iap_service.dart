import 'dart:async';

import 'package:bike_control/bluetooth/messages/notification.dart';
import 'package:bike_control/main.dart';
import 'package:bike_control/utils/core.dart';
import 'package:bike_control/utils/iap/iap_manager.dart';
import 'package:bike_control/utils/windows_store_environment.dart';
import 'package:bike_control/widgets/ui/toast.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:gotrue/src/types/auth_state.dart';
import 'package:prop/prop.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:windows_iap/windows_iap.dart';

/// Windows-specific IAP service
/// Note: This is a stub implementation. For actual Windows Store integration,
/// you would need to use the Windows Store APIs through platform channels.
class WindowsIAPService {
  static const String productId = '9NP42GS03Z26';
  static const int trialDays = 7;
  static const int dailyCommandLimit = 15;

  static const String _purchaseStatusKey = 'iap_purchase_status_2';
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

      
      _authSubscription = core.supabase.auth.onAuthStateChange.listen((data) {
        final AuthChangeEvent event = data.event;
        final Session? session = data.session;

        Logger.info('event: $event, session: ${session?.user.id} via ${session?.user.email}');

        switch (event) {
          case AuthChangeEvent.initialSession:
          case AuthChangeEvent.signedIn:
          // handle signed in
          case AuthChangeEvent.signedOut:
          // handle signed out
          case AuthChangeEvent.passwordRecovery:
          // handle password recovery
          case AuthChangeEvent.tokenRefreshed:
          // handle token refreshed
          case AuthChangeEvent.userUpdated:
          // handle user updated
          case AuthChangeEvent.userDeleted:
          // handle user deleted
          case AuthChangeEvent.mfaChallengeVerified:
          // handle mfa challenge verified
        }
      });
    } catch (e, s) {
      recordError(e, s, context: 'Initializing');
      debugPrint('Failed to initialize Windows IAP: $e');
      _isInitialized = true;
    }
  }

  /// Check if the user has already purchased the app
  Future<void> _checkExistingPurchase() async {
    // First check if we have a stored purchase status
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

  /// Purchase the full version
  /// TODO: Implement actual Windows Store purchase flow
  Future<void> purchaseFullVersion() async {
    try {
      final status = await _windowsIapPlugin.makePurchase(productId);
      if (status == StorePurchaseStatus.succeeded || status == StorePurchaseStatus.alreadyPurchased) {
        IAPManager.instance.isPurchased.value = true;
        buildToast(
          title: 'Purchase Successful',
          subtitle: 'Thank you for your purchase! You now have unlimited access.',
        );
      }
    } catch (e, s) {
      recordError(e, s, context: 'Purchasing on Windows');
      debugPrint('Error purchasing on Windows: $e');
    }
  }

  /// Check if the trial period has started
  bool get hasTrialStarted => trialDaysRemaining >= 0;

  /// Get the number of days remaining in the trial
  int trialDaysRemaining = 0;

  late final StreamSubscription<AuthState> _authSubscription;

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

  /// Dispose the service
  void dispose() {
    // Nothing to dispose for Windows
  }

  void reset() {
    _prefs.deleteAll();
  }
}
