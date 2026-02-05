import 'dart:async';
import 'dart:io';

import 'package:bike_control/bluetooth/messages/notification.dart';
import 'package:bike_control/gen/l10n.dart';
import 'package:bike_control/main.dart';
import 'package:bike_control/utils/core.dart';
import 'package:bike_control/widgets/ui/toast.dart';
import 'package:dartx/dartx.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:prop/prop.dart' as zp;
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:purchases_ui_flutter/purchases_ui_flutter.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:version/version.dart';

/// RevenueCat-based IAP service for iOS, macOS, and Android
class RevenueCatService {
  static const int trialDays = 5;

  static const String _trialStartDateKey = 'iap_trial_start_date';
  static const String _purchaseStatusKey = 'iap_purchase_status';
  static const String _dailyCommandCountKey = 'iap_daily_command_count';
  static const String _lastCommandDateKey = 'iap_last_command_date';
  static const String _syncedPurchasesKey = 'iap_synced_purchases';

  // RevenueCat entitlement identifier
  static const String fullVersionEntitlement = 'Full Version';

  final FlutterSecureStorage _prefs;
  final ValueNotifier<bool> isPurchasedNotifier;
  final int Function() getDailyCommandLimit;
  final void Function(int limit) setDailyCommandLimit;

  static const _isAndroidWorking = false;
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
      final String apiKey;

      if (Platform.isAndroid) {
        apiKey =
            Platform.environment['REVENUECAT_API_KEY_ANDROID'] ??
            const String.fromEnvironment('REVENUECAT_API_KEY_ANDROID', defaultValue: '');
      } else if (Platform.isIOS || Platform.isMacOS) {
        apiKey =
            Platform.environment['REVENUECAT_API_KEY_IOS'] ??
            const String.fromEnvironment('REVENUECAT_API_KEY_IOS', defaultValue: '');
      } else {
        apiKey = '';
      }

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
        await Purchases.setLogLevel(LogLevel.debug);
      }

      await Purchases.configure(configuration);

      debugPrint('RevenueCat initialized successfully');
      core.connection.signalNotification(
        LogNotification('RevenueCat initialized'),
      );

      // Listen for customer info updates
      Purchases.addCustomerInfoUpdateListener((customerInfo) {
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

      if (Platform.isAndroid && !isPurchasedNotifier.value && !_isAndroidWorking) {
        setDailyCommandLimit(10000);
      } else if (!isTrialExpired && Platform.isAndroid) {
        setDailyCommandLimit(80);
      }
    } catch (e, s) {
      recordError(e, s, context: 'Initializing RevenueCat Service');
      core.connection.signalNotification(
        AlertNotification(
          zp.LogLevel.LOGLEVEL_ERROR,
          'There was an error initializing RevenueCat. Please check your configuration.',
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
      final storedStatus = await _prefs.read(key: _syncedPurchasesKey);
      if (storedStatus != "true") {
        await _prefs.write(key: _syncedPurchasesKey, value: "true");
        await Purchases.syncPurchases();
      }
      // Check current entitlement status from RevenueCat
      final customerInfo = await Purchases.getCustomerInfo();
      await _handleCustomerInfoUpdate(customerInfo);
    } catch (e, s) {
      debugPrint('Error checking existing purchase: $e');
      recordError(e, s, context: 'Checking existing purchase');
    }
  }

  /// Handle customer info updates from RevenueCat
  Future<bool> _handleCustomerInfoUpdate(CustomerInfo customerInfo) async {
    final hasEntitlement = customerInfo.entitlements.active.containsKey(fullVersionEntitlement);

    final userId = await Purchases.appUserID;
    core.connection.signalNotification(LogNotification('User ID: $userId at ${customerInfo.requestDate}'));
    core.connection.signalNotification(LogNotification('Full Version entitlement: $hasEntitlement'));

    if (!hasEntitlement) {
      // purchased before IAP migration
      if (Platform.isAndroid) {
        final storedStatus = await _prefs.read(key: _purchaseStatusKey);
        if (storedStatus == "true") {
          core.connection.signalNotification(LogNotification('Setting full version based on stored status'));
          await Purchases.setAttributes({_purchaseStatusKey: "true"});
          isPurchasedNotifier.value = true;
        }
      } else {
        final purchasedVersion = customerInfo.originalApplicationVersion;
        core.connection.signalNotification(LogNotification('Apple receipt validated for version: $purchasedVersion'));
        if (purchasedVersion != null && purchasedVersion.contains(".")) {
          final parsedVersion = Version.parse(purchasedVersion);
          isPurchasedNotifier.value = parsedVersion < Version(4, 2, 0) || parsedVersion >= Version(4, 4, 0);
        } else {
          final purchasedVersionAsInt = int.tryParse(purchasedVersion.toString()) ?? 1337;
          isPurchasedNotifier.value =
              purchasedVersionAsInt < (Platform.isMacOS ? 61 : 58) || purchasedVersionAsInt >= 77;
        }
      }
    } else {
      isPurchasedNotifier.value = hasEntitlement;
    }
    return isPurchasedNotifier.value;
  }

  /// Present the RevenueCat paywall
  Future<void> presentPaywall() async {
    try {
      if (!_isInitialized) {
        await initialize();
      }

      final paywallResult = await RevenueCatUI.presentPaywall(displayCloseButton: true);

      debugPrint('Paywall result: $paywallResult');

      // The customer info listener will handle the purchase update
    } catch (e, s) {
      debugPrint('Error presenting paywall: $e');
      recordError(e, s, context: 'Presenting paywall');
      core.connection.signalNotification(
        AlertNotification(
          zp.LogLevel.LOGLEVEL_ERROR,
          'There was an error displaying the paywall. Please try again.',
        ),
      );
    }
  }

  /// Restore previous purchases
  Future<void> restorePurchases() async {
    try {
      final customerInfo = await Purchases.restorePurchases();
      final result = await _handleCustomerInfoUpdate(customerInfo);

      if (result) {
        core.connection.signalNotification(
          AlertNotification(zp.LogLevel.LOGLEVEL_INFO, 'Purchase restored'),
        );
      }
    } catch (e, s) {
      core.connection.signalNotification(
        AlertNotification(
          zp.LogLevel.LOGLEVEL_ERROR,
          'There was an error restoring purchases. Please try again.',
        ),
      );
      recordError(e, s, context: 'Restore Purchases');
      debugPrint('Error restoring purchases: $e');
    }
  }

  /// Purchase the full version (use paywall instead)
  Future<void> purchaseFullVersion(BuildContext context) async {
    // Direct the user to the paywall for a better experience
    if (Platform.isAndroid && !_isAndroidWorking) {
      _trialStartDate = null;
      await startTrial();
      buildToast(
        navigatorKey.currentContext!,
        title: AppLocalizations.of(context).unlockingNotPossible,
        duration: Duration(seconds: 5),
      );
      setDailyCommandLimit(10000);
    } else if (Platform.isMacOS) {
      try {
        final offerings = await Purchases.getOfferings();
        final purchaseParams = PurchaseParams.package(offerings.current!.availablePackages.first);
        PurchaseResult result = await Purchases.purchase(purchaseParams);
        core.connection.signalNotification(
          LogNotification('Purchase result: $result'),
        );
      } on PlatformException catch (e) {
        var errorCode = PurchasesErrorHelper.getErrorCode(e);
        if (errorCode != PurchasesErrorCode.purchaseCancelledError) {
          buildToast(context, title: e.message);
        }
      }
    } else {
      await presentPaywall();
    }
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
    if (isPurchasedNotifier.value) {
      return; // No need to track for purchased users
    }
    try {
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
    } catch (e, s) {
      final count = _dailyCommandCount ?? 0;
      _dailyCommandCount = count + 1;
      // e.g. https://github.com/OpenBikeControl/bikecontrol/issues/279
      debugPrint('Error incrementing command count: $e');
      recordError(e, s, context: 'Incrementing command count');
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

  Future<void> reset(bool fullReset) async {
    if (fullReset) {
      await _prefs.deleteAll();
    } else {
      await _prefs.delete(key: _purchaseStatusKey);
      _isInitialized = false;
      Purchases.invalidateCustomerInfoCache();
      await initialize();
      _checkExistingPurchase();
    }
  }

  Future<void> redeem(String purchaseId) async {
    await Purchases.setAttributes({"purchase_id": purchaseId});
    core.connection.signalNotification(LogNotification('Redeemed purchase ID: $purchaseId'));
    Purchases.invalidateCustomerInfoCache();
    _checkExistingPurchase();
    isPurchasedNotifier.value = true;
  }

  Future<void> setAttributes() async {
    // attributes are fully anonymous
    await Purchases.setAttributes({
      "bikecontrol_trainer": core.settings.getTrainerApp()?.name ?? '-',
      "bikecontrol_target": core.settings.getLastTarget()?.name ?? '-',
      if (core.connection.controllerDevices.isNotEmpty)
        'bikecontrol_controllers': core.connection.controllerDevices.joinToString(
          transform: (d) => d.toString(),
          separator: ',',
        ),
      'bikecontrol_keymap': core.settings.getKeyMap()?.name ?? '-',
    });
  }
}
