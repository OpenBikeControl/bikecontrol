import 'package:bike_control/main.dart';
import 'package:bike_control/utils/core.dart';
import 'package:bike_control/utils/iap/iap_manager.dart';
import 'package:bike_control/utils/iap/stripe_checkout_flow.dart';
import 'package:bike_control/utils/iap/windows_stripe_service.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

/// Linux: Base is free for everyone, so there is no trial and no daily command
/// limit. Pro is sold through Stripe behind a sign-in, like the Windows
/// download.
class LinuxIAPService {
  /// How long to watch for Pro after the checkout opened in the browser. Stripe
  /// sends the rider to the website afterwards, not back into the app.
  static const proPollInterval = Duration(seconds: 5);
  static const proPollTimeout = Duration(minutes: 10);

  late final StripeCheckoutFlow _checkout = StripeCheckoutFlow(
    stripe: WindowsStripeService(core.supabase),
    platform: 'linux',
    returnUrls: StripeReturnUrls.website,
    loginRequiredBody: (l10n) => l10n.loginRequiredLinuxBody,
    onCheckoutOpened: _watchForPro,
  );

  bool _watchingForPro = false;

  Future<void> initialize() async {
    IAPManager.instance.isPurchased.value = true;
  }

  bool get isLoggedIn => _checkout.isLoggedIn;

  Future<void> resumePendingPurchaseAfterLogin({required bool isAlreadyPro}) =>
      _checkout.resumePendingPurchaseAfterLogin(isAlreadyPro: isAlreadyPro);

  Future<void> purchaseSubscription(BuildContext context, {bool yearly = false}) =>
      _checkout.purchase(context, yearly ? 'yearly' : 'monthly');

  Future<bool> openBillingPortal(BuildContext context) => _checkout.openBillingPortal(context);

  Future<bool> hasStripeCustomer() => _checkout.hasStripeCustomer();

  void _watchForPro() {
    if (_watchingForPro) return;
    _watchingForPro = true;
    pollUntil(
      refresh: IAPManager.instance.refreshEntitlementsOnAppStart,
      done: () => IAPManager.instance.isProEnabled,
      interval: proPollInterval,
      timeout: proPollTimeout,
      onError: (e, s) => recordError(e, s, context: 'Linux: watching for Pro after checkout'),
    ).whenComplete(() => _watchingForPro = false);
  }
}
