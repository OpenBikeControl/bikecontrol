// The Stripe checkout shared by the Windows download and the Linux app. Linux
// cannot count on a bikecontrol:// handler, so Stripe sends it back to the
// website, and the app watches for Pro itself.
import 'package:bike_control/utils/iap/stripe_checkout_flow.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('return links', () {
    test('Windows returns through the app link', () {
      expect(StripeReturnUrls.appLink.success, 'bikecontrol://stripe-success');
      expect(StripeReturnUrls.appLink.cancel, 'bikecontrol://stripe-cancel');
      expect(StripeReturnUrls.appLink.portalReturn, 'bikecontrol://stripe-portal-return');
    });

    test('Linux returns to the website', () {
      expect(StripeReturnUrls.website.success, 'https://bikecontrol.app/checkout/success');
      expect(StripeReturnUrls.website.cancel, 'https://bikecontrol.app/checkout/cancel');
      expect(StripeReturnUrls.website.portalReturn, 'https://bikecontrol.app/checkout/return');
    });
  });

  group('pollUntil', () {
    test('refreshes until the condition holds, then stops', () async {
      var refreshes = 0;
      final slept = <Duration>[];
      final result = await pollUntil(
        refresh: () async => refreshes++,
        done: () => refreshes >= 3,
        interval: const Duration(seconds: 5),
        timeout: const Duration(minutes: 10),
        sleep: (d) async => slept.add(d),
      );
      expect(result, isTrue);
      expect(refreshes, 3);
      expect(slept, List.filled(3, const Duration(seconds: 5)));
    });

    test('gives up after the timeout', () async {
      var refreshes = 0;
      final result = await pollUntil(
        refresh: () async => refreshes++,
        done: () => false,
        interval: const Duration(seconds: 5),
        timeout: const Duration(seconds: 20),
        sleep: (d) async {},
      );
      expect(result, isFalse);
      expect(refreshes, 4);
    });

    test('a failing refresh does not end the wait', () async {
      var calls = 0;
      final errors = <Object>[];
      final result = await pollUntil(
        refresh: () async {
          calls++;
          if (calls == 1) throw StateError('offline');
        },
        done: () => calls >= 2,
        interval: const Duration(seconds: 5),
        timeout: const Duration(minutes: 1),
        sleep: (d) async {},
        onError: (e, s) => errors.add(e),
      );
      expect(result, isTrue);
      expect(errors, hasLength(1));
    });
  });

  group('checkoutToResume', () {
    test('resumes the plan started before logging in', () {
      expect(StripeCheckoutFlow.checkoutToResume(pending: 'yearly', isLoggedIn: true, isAlreadyPro: false), 'yearly');
    });

    test('nothing when already Pro, logged out, or nothing pending', () {
      expect(StripeCheckoutFlow.checkoutToResume(pending: 'yearly', isLoggedIn: true, isAlreadyPro: true), isNull);
      expect(StripeCheckoutFlow.checkoutToResume(pending: 'yearly', isLoggedIn: false, isAlreadyPro: false), isNull);
      expect(StripeCheckoutFlow.checkoutToResume(pending: null, isLoggedIn: true, isAlreadyPro: false), isNull);
    });
  });
}
