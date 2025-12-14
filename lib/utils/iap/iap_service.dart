import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:bike_control/utils/core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:ios_receipt/ios_receipt.dart';
import 'package:version/version.dart';

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
  final FlutterSecureStorage _prefs;

  StreamSubscription<List<PurchaseDetails>>? _subscription;
  bool _isPurchased = false;
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
        _isPurchased = false;
        _isInitialized = true;
        return;
      }

      // Listen for purchase updates
      _subscription = _inAppPurchase.purchaseStream.listen(
        _onPurchaseUpdate,
        onDone: () => _subscription?.cancel(),
        onError: (error) {
          debugPrint('IAP Error: $error');
          // On error, default to allowing access
          _isPurchased = false;
        },
      );

      _trialStartDate = await _prefs.read(key: _trialStartDateKey);
      _lastCommandDate = await _prefs.read(key: _lastCommandDateKey);
      _dailyCommandCount = int.tryParse(await _prefs.read(key: _dailyCommandCountKey) ?? '0');

      // Check if already purchased
      await _checkExistingPurchase();

      _isInitialized = true;
    } catch (e) {
      debugPrint('Failed to initialize IAP: $e');
      // On initialization failure, default to allowing access
      _isPurchased = false;
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
      await restorePurchases();
    }
  }

  /// Check for Apple receipt (iOS/macOS)
  Future<void> _checkAppleReceipt() async {
    try {
      final receiptContent = await IosReceipt.getAppleReceipt();
      if (receiptContent != null) {
        debugPrint('Existing Apple user detected - granting full access $receiptContent');
        await validateReceipt(
          base64Receipt: receiptContent,
          sharedSecret:
              Platform.environment['VERIFYING_SHARED_SECRET'] ?? String.fromEnvironment("VERIFYING_SHARED_SECRET"),
        );
      } else {
        debugPrint('No Apple receipt found');
      }
    } catch (e) {
      debugPrint('Error checking Apple receipt: $e');
    }
  }

  Future<void> validateReceipt({
    required String base64Receipt,
    required String sharedSecret,
  }) async {
    final bool isDebug = kDebugMode;

    final Uri url = Uri.parse(
      isDebug ? 'https://sandbox.itunes.apple.com/verifyReceipt' : 'https://buy.itunes.apple.com/verifyReceipt',
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
      final purchasedVersion = json['receipt']["original_application_version"];
      _isPurchased = Version.parse(purchasedVersion) < Version(4, 2, 0);
      if (_isPurchased) {
        debugPrint('Apple receipt validation successful - granting full access');
        await _prefs.write(key: _purchaseStatusKey, value: "true");
      } else {
        debugPrint('Apple receipt validation failed - no full access');
      }
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
      debugPrint('Error checking Android previous purchase: $e');
    }
  }

  /// Restore previous purchases
  Future<void> restorePurchases() async {
    try {
      await _inAppPurchase.restorePurchases();
      // The purchase stream will be called with restored purchases
    } catch (e) {
      debugPrint('Error restoring purchases: $e');
    }
  }

  /// Handle purchase updates
  Future<void> _onPurchaseUpdate(List<PurchaseDetails> purchaseDetailsList) async {
    for (final purchase in purchaseDetailsList) {
      if (purchase.status == PurchaseStatus.purchased || purchase.status == PurchaseStatus.restored) {
        _isPurchased = true;
        await _prefs.write(key: _purchaseStatusKey, value: 'true');
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
    return (!_isPurchased && hasTrialStarted && trialDaysRemaining <= 0);
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
      await _prefs.write(key: _dailyCommandCountKey, value: _dailyCommandCountKey.toString());
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
      return 'Full Version';
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
