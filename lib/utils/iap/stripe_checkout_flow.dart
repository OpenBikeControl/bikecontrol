import 'package:bike_control/gen/l10n.dart';
import 'package:bike_control/main.dart';
import 'package:bike_control/pages/plan/plan_account_page.dart';
import 'package:bike_control/utils/iap/windows_stripe_service.dart';
import 'package:bike_control/widgets/ui/toast.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

/// Where Stripe Checkout and the billing portal send the rider afterwards.
class StripeReturnUrls {
  const StripeReturnUrls({required this.success, required this.cancel, required this.portalReturn});

  final String success;
  final String cancel;
  final String portalReturn;

  /// Back into the app. The Windows download registers the scheme itself.
  static const appLink = StripeReturnUrls(
    success: 'bikecontrol://stripe-success',
    cancel: 'bikecontrol://stripe-cancel',
    portalReturn: 'bikecontrol://stripe-portal-return',
  );

  /// To pages on the website that send the rider back to the app. Linux has no
  /// handler for the app link unless a package registered one, so the app
  /// watches for the purchase itself (see [StripeCheckoutFlow.onCheckoutOpened]).
  static const website = StripeReturnUrls(
    success: 'https://bikecontrol.app/checkout/success',
    cancel: 'https://bikecontrol.app/checkout/cancel',
    portalReturn: 'https://bikecontrol.app/checkout/return',
  );
}

/// Calls [refresh] every [interval] until [done] holds or [timeout] passes.
/// Resolves to whether [done] came to hold. A failing refresh is reported and
/// the wait goes on.
Future<bool> pollUntil({
  required Future<void> Function() refresh,
  required bool Function() done,
  required Duration interval,
  required Duration timeout,
  Future<void> Function(Duration duration)? sleep,
  void Function(Object error, StackTrace stack)? onError,
}) async {
  final wait = sleep ?? Future<void>.delayed;
  var waited = Duration.zero;
  while (waited < timeout) {
    await wait(interval);
    waited += interval;
    try {
      await refresh();
    } catch (e, s) {
      onError?.call(e, s);
    }
    if (done()) return true;
  }
  return false;
}

/// Buying Pro through Stripe, behind a sign-in: the Windows download and the
/// Linux app. The checkout and the billing portal open in the browser.
class StripeCheckoutFlow {
  StripeCheckoutFlow({
    required WindowsStripeService stripe,
    required this.platform,
    required this.returnUrls,
    required this.loginRequiredBody,
    Future<String?> Function()? storeId,
    this.onCheckoutOpened,
  }) : _stripe = stripe,
       _storeId = storeId ?? (() async => null);

  final WindowsStripeService _stripe;
  final Future<String?> Function() _storeId;

  /// Sent along with the checkout so the purchase can be told apart by
  /// platform (`windows`, `linux`).
  final String platform;

  final StripeReturnUrls returnUrls;

  /// The login-required dialog's explanation.
  final String Function(AppLocalizations l10n) loginRequiredBody;

  /// Runs once the checkout page is open in the browser.
  final void Function()? onCheckoutOpened;

  /// Signed into a real account. An anonymous support-chat session doesn't
  /// count: a checkout must never be tied to it.
  bool get isLoggedIn => _stripe.isLoggedIn;

  /// The Stripe checkout the rider asked for before we sent them to log in via
  /// the "Login Required" gate. Resumed by [resumePendingPurchaseAfterLogin]
  /// once auth reports `signedIn` — that is the one signal that fires for both
  /// the in-app email code and the external browser OAuth redirect. In-memory
  /// only: a full app restart during the OAuth round-trip drops it, which is
  /// acceptable (the rider just taps Buy again).
  String? _pendingCheckoutPriceId;

  /// Resume a checkout deferred by the login gate, now that login has finished.
  /// [isAlreadyPro] short-circuits the rider who logs into an account that is
  /// already entitled, so we never open a second checkout for them.
  Future<void> resumePendingPurchaseAfterLogin({required bool isAlreadyPro}) async {
    final priceId = checkoutToResume(
      pending: _pendingCheckoutPriceId,
      isLoggedIn: isLoggedIn,
      isAlreadyPro: isAlreadyPro,
    );
    _pendingCheckoutPriceId = null;
    if (priceId == null) return;
    await _startCheckout(priceId);
  }

  /// Pure decision behind [resumePendingPurchaseAfterLogin]: the Stripe price id
  /// to check out after a login completes, or null to do nothing.
  static String? checkoutToResume({
    required String? pending,
    required bool isLoggedIn,
    required bool isAlreadyPro,
  }) {
    if (pending == null || !isLoggedIn || isAlreadyPro) return null;
    return pending;
  }

  /// Check out [priceId] ('monthly' | 'yearly' | 'full'), asking the rider to
  /// log in first when they are not.
  Future<void> purchase(BuildContext context, String priceId) async {
    if (!isLoggedIn) {
      await _gateBehindLogin(context, priceId);
      return;
    }
    await _startCheckout(priceId);
  }

  /// Stash [priceId] as the checkout to resume, then ask the rider to log in.
  /// If they back out of the login dialog we drop the intent so a later,
  /// unrelated sign-in never launches a checkout they abandoned.
  Future<void> _gateBehindLogin(BuildContext context, String priceId) async {
    _pendingCheckoutPriceId = priceId;
    final proceeding = await _showLoginRequiredDialog(context);
    if (!proceeding) {
      _pendingCheckoutPriceId = null;
    }
  }

  /// Context-free on purpose: besides the direct purchase it also runs from the
  /// post-login resume, which fires from the auth-state listener with no widget
  /// in scope. `buildToast` already routes through the global navigator.
  Future<void> _startCheckout(String priceId) async {
    try {
      await _stripe.startCheckout(
        priceId: priceId,
        storeId: await _storeId(),
        platform: platform,
        successUrl: returnUrls.success,
        cancelUrl: returnUrls.cancel,
      );
      onCheckoutOpened?.call();
    } on StripeException catch (e, s) {
      recordError(e, s, context: 'Starting Stripe checkout');
      buildToast(
        title: AppLocalizations.current.checkoutErrorTitle,
        subtitle: e.message,
      );
    } catch (e, s) {
      recordError(e, s, context: 'Starting Stripe checkout');
      buildToast(
        title: AppLocalizations.current.checkoutErrorTitle,
        subtitle: AppLocalizations.current.checkoutErrorBody,
      );
    }
  }

  /// Open the Stripe billing portal to manage the subscription.
  /// Returns false if the user has no Stripe customer (the button should hide).
  Future<bool> openBillingPortal(BuildContext context) async {
    if (!isLoggedIn) {
      await _showLoginRequiredDialog(context);
      return true; // Keep the button visible: the user might log in.
    }

    try {
      await _stripe.openPortal(returnUrl: returnUrls.portalReturn);
      return true;
    } on StripeException catch (e, s) {
      if (e.statusCode == 404) {
        // No Stripe customer found - should hide the portal button
        return false;
      }
      recordError(e, s, context: 'Opening Stripe portal');
      if (context.mounted) {
        buildToast(
          title: AppLocalizations.current.billingPortalErrorTitle,
          subtitle: e.message,
        );
      }
      return true;
    } catch (e, s) {
      recordError(e, s, context: 'Opening Stripe portal');
      if (context.mounted) {
        buildToast(
          title: AppLocalizations.current.billingPortalErrorTitle,
          subtitle: AppLocalizations.current.billingPortalErrorBody,
        );
      }
      return true;
    }
  }

  Future<bool> hasStripeCustomer() => _stripe.hasStripeCustomer();

  /// Tell the rider that Pro here needs an account. Resolves to true when they
  /// chose "Go to Login", false if they backed out (Cancel or dismiss) — the
  /// caller uses this to drop a deferred checkout.
  Future<bool> _showLoginRequiredDialog(BuildContext context) async {
    final proceeding = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(LucideIcons.lock, color: Colors.orange),
            const SizedBox(width: 8),
            Text(AppLocalizations.of(context).loginRequiredTitle),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(loginRequiredBody(AppLocalizations.of(context))),
            const SizedBox(height: 16),
            Text(
              AppLocalizations.of(context).loginRequiredCta,
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        actions: [
          SecondaryButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(AppLocalizations.of(context).cancel),
          ),
          PrimaryButton(
            onPressed: () async {
              Navigator.pop(context, true);
              Navigator.push(context, MaterialPageRoute(builder: (c) => const PlanAccountPage()));
              // Login completing emits Supabase `signedIn`, which
              // IAPManager resumes the deferred checkout from.
            },
            child: Text(AppLocalizations.of(context).goToLogin),
          ),
        ],
      ),
    );
    // Barrier dismiss returns null — treat it as "did not proceed to login".
    return proceeding ?? false;
  }
}
