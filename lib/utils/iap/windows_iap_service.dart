import 'package:bike_control/bluetooth/messages/notification.dart';
import 'package:bike_control/main.dart';
import 'package:bike_control/pages/subscriptions/login.dart';
import 'package:bike_control/services/entitlements_service.dart';
import 'package:bike_control/utils/core.dart';
import 'package:bike_control/utils/iap/iap_manager.dart';
import 'package:bike_control/utils/iap/windows_stripe_service.dart';
import 'package:bike_control/utils/windows_store_environment.dart';
import 'package:bike_control/widgets/ui/toast.dart';
import 'package:flutter/material.dart' show BackButton;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:windows_iap/windows_iap.dart';

/// Windows-specific IAP service for Microsoft Store purchases and server-side sync.
class WindowsIAPService {
  static const String productId = '9NP42GS03Z26';
  static const int trialDays = 7;
  static const int dailyCommandLimit = 15;

  static const String _purchaseStatusKey = 'iap_purchase_status_2';
  static const String _dailyCommandCountKey = 'iap_daily_command_count';
  static const String _lastCommandDateKey = 'iap_last_command_date';

  final FlutterSecureStorage _prefs;
  final EntitlementsService _entitlementsService;
  final WindowsStripeService _stripeService;

  bool _isInitialized = false;

  String? _lastCommandDate;
  int? _dailyCommandCount;

  final _windowsIapPlugin = WindowsIap();

  WindowsIAPService(
    this._prefs, {
    required EntitlementsService entitlementsService,
  }) : _entitlementsService = entitlementsService,
       _stripeService = WindowsStripeService(core.supabase);

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
    if (_entitlementsService.hasActive(IAPManager.fullVersionProductKey) &&
        IAPManager.instance.isOutsideStoreWindowsBuild) {
      IAPManager.instance.isPurchased.value = true;
      return;
    }

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

    final boughtProducts = await _windowsIapPlugin.getAddonLicenses();
    if (boughtProducts.containsKey(IAPManager.premiumMonthlyProductKey) &&
        boughtProducts[IAPManager.premiumMonthlyProductKey]!.isActive == true) {
      IAPManager.instance.isLocalPro.value = true;
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
        IAPManager.instance.isPurchased.value = true;
        buildToast(
          title: 'Purchase Successful',
          subtitle: 'Purchase complete. Sync may take a moment.',
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

  /// Check if the trial has expired
  bool get isTrialExpired {
    if (IAPManager.instance.isProEnabled) {
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
    if (IAPManager.instance.isProEnabled || IAPManager.instance.isPurchased.value) return true;
    if (!isTrialExpired) return true;
    return dailyCommandCount < dailyCommandLimit;
  }

  /// Get the number of commands remaining today (for free tier after trial)
  int get commandsRemainingToday {
    if (IAPManager.instance.isProEnabled || IAPManager.instance.isPurchased.value || !isTrialExpired) {
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

  /// Check if user is logged in (required for Stripe on Windows)
  bool get isLoggedIn => _stripeService.isLoggedIn;

  /// Start Stripe Checkout to purchase a subscription
  /// Shows a dialog if user is not logged in
  Future<void> purchaseSubscription(BuildContext context, {bool yearly = false}) async {
    if (!isLoggedIn) {
      await _showLoginRequiredDialog(context);
      return;
    }

    try {
      final storeId = await _windowsIapPlugin.getStoreId();
      await _stripeService.startCheckout(
        priceId: yearly ? 'yearly' : 'monthly',
        storeId: storeId,
        successUrl: 'bikecontrol://stripe-success',
        cancelUrl: 'bikecontrol://stripe-cancel',
      );
    } on StripeException catch (e) {
      if (context.mounted) {
        buildToast(
          title: 'Checkout Error',
          subtitle: e.message,
        );
      }
    } catch (e, s) {
      recordError(e, s, context: 'Starting Stripe checkout');
      if (context.mounted) {
        buildToast(
          title: 'Checkout Error',
          subtitle: 'Failed to start checkout. Please try again.',
        );
      }
    }
  }

  /// Start Stripe Checkout to purchase the full version (one-time payment)
  /// Shows a dialog if user is not logged in
  Future<void> purchaseFullVersionViaStripe(BuildContext context) async {
    if (!isLoggedIn) {
      await _showLoginRequiredDialog(context);
      return;
    }

    try {
      final storeId = await _windowsIapPlugin.getStoreId();
      await _stripeService.startCheckout(
        priceId: 'full',
        storeId: storeId,
        successUrl: 'bikecontrol://stripe-success',
        cancelUrl: 'bikecontrol://stripe-cancel',
      );
    } on StripeException catch (e) {
      if (context.mounted) {
        buildToast(
          title: 'Checkout Error',
          subtitle: e.message,
        );
      }
    } catch (e, s) {
      recordError(e, s, context: 'Starting Stripe full version checkout');
      if (context.mounted) {
        buildToast(
          title: 'Checkout Error',
          subtitle: 'Failed to start checkout. Please try again.',
        );
      }
    }
  }

  /// Open Stripe Billing Portal to manage subscription
  /// Returns false if user has no Stripe customer (should hide button in this case)
  Future<bool> openBillingPortal(BuildContext context) async {
    if (!isLoggedIn) {
      await _showLoginRequiredDialog(context);
      return true; // Return true to keep the button visible (user might log in)
    }

    try {
      await _stripeService.openPortal(returnUrl: 'bikecontrol://stripe-portal-return');
      return true;
    } on StripeException catch (e) {
      if (e.statusCode == 404) {
        // No Stripe customer found - should hide the portal button
        return false;
      }
      if (context.mounted) {
        buildToast(
          title: 'Portal Error',
          subtitle: e.message,
        );
      }
      return true;
    } catch (e, s) {
      recordError(e, s, context: 'Opening Stripe portal');
      if (context.mounted) {
        buildToast(
          title: 'Portal Error',
          subtitle: 'Failed to open billing portal. Please try again.',
        );
      }
      return true;
    }
  }

  /// Check if user has a Stripe customer record
  Future<bool> hasStripeCustomer() async {
    return _stripeService.hasStripeCustomer();
  }

  /// Show dialog informing user that login is required for Windows subscriptions
  Future<void> _showLoginRequiredDialog(BuildContext context) async {
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.lock, color: Colors.orange),
            const SizedBox(width: 8),
            Text('Login Required'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'A subscription on Windows requires you to be logged in. This allows us to manage your subscription across devices and provide you with secure payment processing through Stripe.',
            ),
            const SizedBox(height: 16),
            Text(
              'Please log in or create an account to continue.',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        actions: [
          SecondaryButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('Cancel'),
          ),
          PrimaryButton(
            onPressed: () async {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (c) => Scaffold(
                    headers: [
                      AppBar(
                        leading: [BackButton()],
                      ),
                    ],
                    child: LoginPage(pushed: true),
                  ),
                ),
              );
              // Navigate to login page - this would need to be handled by the caller
            },
            child: Text('Go to Login'),
          ),
        ],
      ),
    );
  }
}
