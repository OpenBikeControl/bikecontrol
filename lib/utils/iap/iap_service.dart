import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:prop/prop.dart';
import 'package:bike_control/bluetooth/messages/notification.dart';
import 'package:bike_control/main.dart';
import 'package:bike_control/utils/core.dart';
import 'package:bike_control/utils/iap/iap_manager.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:intl/intl.dart';
import 'package:ios_receipt/ios_receipt.dart';
import 'package:version/version.dart';

/// Service to handle in-app purchase functionality and trial period management
class IAPService {
  static const int trialDays = 5;

  static const String _trialStartDateKey = 'iap_trial_start_date';
  static const String _purchaseStatusKey = 'iap_purchase_status';
  static const String _dailyCommandCountKey = 'iap_daily_command_count';
  static const String _lastCommandDateKey = 'iap_last_command_date';
  static const String _lastPurchaseCheckKey = 'iap_last_purchase_check';
  static const String _hasPurchasedKey = 'iap_has_purchased';

  final InAppPurchase _inAppPurchase = InAppPurchase.instance;
  final FlutterSecureStorage _prefs;

  StreamSubscription<List<PurchaseDetails>>? _subscription;
  bool _isInitialized = false;
  String? _trialStartDate;
  String? _lastCommandDate;
  int? _dailyCommandCount;

  IAPService(this._prefs);

  /// Initialize the IAP service
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // Skip IAP initialization on web
      if (kIsWeb) {
        debugPrint('IAP not supported on web');
        _isInitialized = true;
        return;
      }

      // Check if IAP is available on this platform
      final available = await _inAppPurchase.isAvailable();
      if (!available) {
        debugPrint('IAP not available on this platform -');
        // Set as purchased to allow unlimited access when IAP is not available
        IAPManager.instance.isPurchased.value = false;
        _isInitialized = true;
        return;
      }

      // Listen for purchase updates
      _subscription = _inAppPurchase.purchaseStream.listen(
        _onPurchaseUpdate,
        onDone: () => _subscription?.cancel(),
        onError: (error) {
          debugPrint('IAP Error: $error');
          core.connection.signalNotification(
            LogNotification('There was an error with in-app purchases: ${error.toString()}'),
          );
          // On error, default to allowing access
          IAPManager.instance.isPurchased.value = false;
        },
      );

      _trialStartDate = await _prefs.read(key: _trialStartDateKey);
      core.connection.signalNotification(LogNotification('Trial start date: $_trialStartDate => $trialDaysRemaining'));

      _lastCommandDate = await _prefs.read(key: _lastCommandDateKey);

      final commandCount = await _prefs.read(key: _dailyCommandCountKey) ?? '0';
      _dailyCommandCount = int.tryParse(commandCount);
      // Check if already purchased
      await _checkExistingPurchase();

      _isInitialized = true;

      if (!isTrialExpired && Platform.isAndroid) {
        IAPManager.dailyCommandLimit = 80;
      }
    } catch (e, s) {
      recordError(e, s, context: 'Initializing IAP Service');
      core.connection.signalNotification(
        AlertNotification(LogLevel.LOGLEVEL_ERROR, 'There was an error checking purchase status: ${e.toString()}'),
      );
      debugPrint('Failed to initialize IAP: $e');
      // On initialization failure, default to allowing access
      IAPManager.instance.isPurchased.value = false;
      _isInitialized = true;
    }
  }

  /// Check if the user has already purchased the app
  Future<void> _checkExistingPurchase() async {
    // First check if we have a stored purchase status
    final storedStatus = await _prefs.read(key: _purchaseStatusKey);
    final lastPurchaseCheck = await _prefs.read(key: _lastPurchaseCheckKey);
    final hasPurchased = await _prefs.read(key: _hasPurchasedKey);

    String todayDate = DateFormat('yyyy-MM-dd').format(DateTime.now());

    if (storedStatus == "true") {
      if (Platform.isAndroid) {
        if (lastPurchaseCheck == todayDate || hasPurchased == null) {
          // hasPurchased means it was redeemed manually, so we skip the daily check
          IAPManager.instance.isPurchased.value = true;
        }
      } else {
        IAPManager.instance.isPurchased.value = true;
      }
      return;
    }

    await _prefs.write(key: _lastPurchaseCheckKey, value: todayDate);

    // Platform-specific checks for existing paid app purchases
    if (Platform.isIOS || Platform.isMacOS) {
      // On iOS/macOS, check if the app was previously purchased (has a receipt)
      await _checkAppleReceipt();
    } else if (Platform.isAndroid) {
      // On Android, check if user had the paid version before
      await _checkAndroidPreviousPurchase();
    }

    // Also check for IAP purchase
    if (!IAPManager.instance.isPurchased.value) {
      await restorePurchases();
    }
  }

  /// Check for Apple receipt (iOS/macOS)
  Future<void> _checkAppleReceipt() async {
    try {
      final receiptContent = await IosReceipt.getAppleReceipt();
      if (receiptContent != null) {
        debugPrint('Existing Apple user detected - validating receipt $receiptContent');
        var sharedSecret =
            Platform.environment['VERIFYING_SHARED_SECRET'] ?? const String.fromEnvironment("VERIFYING_SHARED_SECRET");

        if (sharedSecret.isEmpty) {
          core.connection.signalNotification(AlertNotification(LogLevel.LOGLEVEL_ERROR, 'Shared Secret is empty'));
        }
        core.connection.signalNotification(
          LogNotification('Using shared secret: ${sharedSecret.characters.take(10).join()}'),
        );
        await validateReceipt(
          base64Receipt: receiptContent,
          sharedSecret: sharedSecret,
        );
      } else {
        debugPrint('No Apple receipt found');
      }
    } catch (e) {
      core.connection.signalNotification(LogNotification('There was an error checking Apple receipt: ${e.toString()}'));
      debugPrint('Error checking Apple receipt: $e');
    }
  }

  Future<void> validateReceipt({
    required String base64Receipt,
    required String sharedSecret,
    bool isSandbox = false,
  }) async {
    final Uri url = Uri.parse(
      isSandbox ? 'https://sandbox.itunes.apple.com/verifyReceipt' : 'https://buy.itunes.apple.com/verifyReceipt',
    );

    final Map<String, dynamic> requestData = {
      'receipt-data': base64Receipt,
      'password': sharedSecret,
      'exclude-old-transactions': false,
    };

    final HttpClient client = HttpClient();

    try {
      final HttpClientRequest request = await client.postUrl(url);
      request.headers.set(
        HttpHeaders.contentTypeHeader,
        'application/json',
      );
      request.add(utf8.encode(jsonEncode(requestData)));

      final HttpClientResponse response = await request.close();
      final String responseBody = await response.transform(utf8.decoder).join();

      final Map<String, dynamic> json = jsonDecode(responseBody) as Map<String, dynamic>;

      if (json['status'] == 21007) {
        // Receipt is from sandbox, retry with sandbox URL
        debugPrint('Receipt is from sandbox, retrying with sandbox URL');
        return validateReceipt(
          base64Receipt: base64Receipt,
          sharedSecret: sharedSecret,
          isSandbox: true,
        );
      } else if (json['status'] != 0) {
        core.connection.signalNotification(
          LogNotification('Apple receipt validation failed with status: ${json['status']}'),
        );
        return;
      }

      final purchasedVersion = json['receipt']["original_application_version"];
      core.connection.signalNotification(
        LogNotification('Apple receipt validated for version: $purchasedVersion'),
      );

      final purchasedVersionAsInt = int.tryParse(purchasedVersion.toString()) ?? 0;

      IAPManager.instance.isPurchased.value = purchasedVersionAsInt < (Platform.isMacOS ? 61 : 58);
      if (IAPManager.instance.isPurchased.value) {
        debugPrint('Apple receipt validation successful - granting full access');
        await _prefs.write(key: _purchaseStatusKey, value: "true");
      } else {
        debugPrint('Apple receipt validation failed - no full access');
      }
    } catch (e) {
      rethrow;
    } finally {
      client.close();
    }
  }

  /// Check if Android user had the paid app before
  Future<void> _checkAndroidPreviousPurchase() async {
    try {
      // On Android, we use the last seen version to determine if they had the paid version
      // IMPORTANT: This assumes the app is currently paid and this update will be released
      // while the app is still paid. Only users who downloaded the paid version will have
      // a last_seen_version. After changing the app to free, new users won't have this set.
      final lastSeenVersion = core.settings.getLastSeenVersion();
      core.connection.signalNotification(LogNotification('Android last seen version: $lastSeenVersion'));
      if (lastSeenVersion != null && lastSeenVersion.isNotEmpty) {
        Version lastVersion = Version.parse(lastSeenVersion);
        // If they had a previous version, they're an existing paid user
        IAPManager.instance.isPurchased.value = lastVersion < Version(4, 2, 0);
        if (IAPManager.instance.isPurchased.value) {
          await _prefs.write(key: _purchaseStatusKey, value: "true");
        }
        debugPrint('Existing Android user detected - granting full access');
      }
    } catch (e, s) {
      debugPrint('Error checking Android previous purchase: $e');
      recordError(e, s, context: 'Checking Android previous purchase');
    }
  }

  /// Restore previous purchases
  Future<void> restorePurchases() async {
    try {
      await _inAppPurchase.restorePurchases();
      // The purchase stream will be called with restored purchases
    } catch (e, s) {
      core.connection.signalNotification(
        AlertNotification(LogLevel.LOGLEVEL_ERROR, 'There was an error restoring purchases: ${e.toString()}'),
      );
      recordError(e, s, context: 'Restore Purchases');
      debugPrint('Error restoring purchases: $e');
    }
  }

  /// Handle purchase updates
  Future<void> _onPurchaseUpdate(List<PurchaseDetails> purchaseDetailsList) async {
    for (final purchase in purchaseDetailsList) {
      core.connection.signalNotification(
        LogNotification('Purchase found: ${purchase.purchaseID} ${purchase.productID} - ${purchase.status}'),
      );
      if (purchase.status == PurchaseStatus.purchased || purchase.status == PurchaseStatus.restored) {
        IAPManager.instance.isPurchased.value = true;

        await _prefs.write(key: _hasPurchasedKey, value: "true");
        await _prefs.write(key: _purchaseStatusKey, value: IAPManager.instance.isPurchased.value.toString());
        debugPrint('Purchase successful or restored');
      }

      // Complete the purchase
      if (purchase.pendingCompletePurchase) {
        _inAppPurchase.completePurchase(purchase);
      }
    }
  }

  /// Purchase the full version
  Future<void> purchaseFullVersion() async {
    try {
      if (!_isInitialized) {
        await initialize();
      }

      final available = await _inAppPurchase.isAvailable();
      if (!available) {
        debugPrint('IAP not available');
        core.connection.signalNotification(
          AlertNotification(LogLevel.LOGLEVEL_INFO, 'IAP is not available on this platform.'),
        );
        return;
      }

      final productId = 'full_access_unlock';

      // Query product details
      final response = await _inAppPurchase.queryProductDetails({productId});
      if (response.error != null) {
        debugPrint('Error querying products: ${response.error}');
        if (response.error!.code == 'storekit_no_response') {
          _trialStartDate = DateTime.now().toIso8601String();
          core.connection.signalNotification(
            AlertNotification(
              LogLevel.LOGLEVEL_WARNING,
              'Unlock will be available, soon! Trial days have been extended.',
            ),
          );
        } else {
          core.connection.signalNotification(
            AlertNotification(LogLevel.LOGLEVEL_INFO, 'IAP issue: ${response.error!.toString()}'),
          );
        }
        return;
      }

      if (response.productDetails.isEmpty) {
        debugPrint('Product not found: $productId');
        core.connection.signalNotification(AlertNotification(LogLevel.LOGLEVEL_INFO, 'IAP issue: Product not found.'));
        return;
      }

      final product = response.productDetails.first;
      final purchaseParam = PurchaseParam(productDetails: product);

      await _inAppPurchase.buyNonConsumable(purchaseParam: purchaseParam);
      await restorePurchases();
    } catch (e, s) {
      debugPrint('Error purchasing: $e');
      recordError(e, s, context: 'Error purchasing');
      core.connection.signalNotification(
        AlertNotification(LogLevel.LOGLEVEL_ERROR, 'There was an error during purchasing: ${e.toString()}'),
      );
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
    if (IAPManager.instance.isPurchased.value) return 0;

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
    return (!IAPManager.instance.isPurchased.value && hasTrialStarted && trialDaysRemaining <= 0);
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
    if (IAPManager.instance.isPurchased.value) return true;
    if (!isTrialExpired && !Platform.isAndroid) return true;
    return dailyCommandCount < IAPManager.dailyCommandLimit;
  }

  /// Get the number of commands remaining today (for free tier after trial)
  int get commandsRemainingToday {
    if (IAPManager.instance.isPurchased.value || (!isTrialExpired && !Platform.isAndroid)) return -1; // Unlimited
    final remaining = IAPManager.dailyCommandLimit - dailyCommandCount;
    return remaining > 0 ? remaining : 0; // Never return negative
  }

  /// Dispose the service
  void dispose() {
    _subscription?.cancel();
  }

  Future<void> reset(bool fullReset) async {
    if (fullReset) {
      await _prefs.deleteAll();
    } else {
      await _prefs.delete(key: _purchaseStatusKey);
      _isInitialized = false;
      await initialize();
    }
  }

  Future<void> redeem() async {
    IAPManager.instance.isPurchased.value = true;
    await _prefs.write(key: _purchaseStatusKey, value: IAPManager.instance.isPurchased.value.toString());
  }
}
