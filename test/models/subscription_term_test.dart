// What the Plan & account page may say about a subscription's end: it only
// claims a renewal when the store says the subscription will renew.
import 'package:bike_control/models/entitlement.dart';
import 'package:bike_control/models/subscription_term.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

EntitlementInfo _info({
  bool willRenew = true,
  String productIdentifier = 'premium_monthly',
  String? expirationDate = '2026-11-04T10:00:00Z',
  PeriodType periodType = PeriodType.normal,
  String? unsubscribeDetectedAt,
  String? billingIssueDetectedAt,
  Store store = Store.appStore,
}) => EntitlementInfo(
  'pro',
  true,
  willRenew,
  '2026-10-04T10:00:00Z',
  '2026-01-04T10:00:00Z',
  productIdentifier,
  false,
  store: store,
  periodType: periodType,
  expirationDate: expirationDate,
  unsubscribeDetectedAt: unsubscribeDetectedAt,
  billingIssueDetectedAt: billingIssueDetectedAt,
);

void main() {
  group('from the store (RevenueCat)', () {
    test('a subscription that will renew renews on its expiration date', () {
      final term = SubscriptionTerm.fromRevenueCat(_info());
      expect(term.renewal, SubscriptionRenewal.renews);
      expect(term.until, DateTime.utc(2026, 11, 4, 10));
      expect(term.period, SubscriptionPeriod.monthly);
      expect(term.store, SubscriptionStore.appStore);
    });

    test('a cancelled subscription is only active until its date', () {
      final term = SubscriptionTerm.fromRevenueCat(
        _info(willRenew: false, unsubscribeDetectedAt: '2026-10-01T00:00:00Z'),
      );
      expect(term.renewal, SubscriptionRenewal.ends);
    });

    test('an unsubscribe is believed even when willRenew still says true', () {
      final term = SubscriptionTerm.fromRevenueCat(_info(unsubscribeDetectedAt: '2026-10-01T00:00:00Z'));
      expect(term.renewal, SubscriptionRenewal.ends);
    });

    test('a billing issue wins over everything else', () {
      final term = SubscriptionTerm.fromRevenueCat(
        _info(billingIssueDetectedAt: '2026-10-02T00:00:00Z', periodType: PeriodType.trial),
      );
      expect(term.renewal, SubscriptionRenewal.billingIssue);
    });

    test('a store trial runs until its date', () {
      final term = SubscriptionTerm.fromRevenueCat(_info(periodType: PeriodType.trial));
      expect(term.renewal, SubscriptionRenewal.trial);
    });

    test('no expiration date: no renewal claim', () {
      final term = SubscriptionTerm.fromRevenueCat(_info(expirationDate: null));
      expect(term.renewal, SubscriptionRenewal.unknown);
      expect(term.until, isNull);
    });

    test('yearly products and the store are recognised', () {
      final term = SubscriptionTerm.fromRevenueCat(
        _info(productIdentifier: 'bikecontrol_pro_yearly:p1y', store: Store.playStore),
      );
      expect(term.period, SubscriptionPeriod.yearly);
      expect(term.store, SubscriptionStore.playStore);
      expect(SubscriptionTerm.fromRevenueCat(_info(store: Store.macAppStore)).store, SubscriptionStore.macAppStore);
      expect(SubscriptionTerm.fromRevenueCat(_info(store: Store.promotional)).store, SubscriptionStore.other);
    });
  });

  group('from the account (server entitlements)', () {
    test('only the date is known, so the page says "active until", never "renews"', () {
      final term = SubscriptionTerm.fromEntitlement(
        Entitlement(
          productKey: 'premium_yearly',
          status: 'active',
          activeUntil: DateTime.utc(2027, 2, 1),
          source: 'stripe',
        ),
      );
      expect(term.renewal, SubscriptionRenewal.unknown);
      expect(term.until, DateTime.utc(2027, 2, 1));
      expect(term.period, SubscriptionPeriod.yearly);
      expect(term.store, SubscriptionStore.billingPortal);
    });

    test('a store-sourced entitlement names no store it can be managed in here', () {
      final term = SubscriptionTerm.fromEntitlement(
        Entitlement(productKey: 'premium_monthly', status: 'active', activeUntil: null, source: 'revenuecat'),
      );
      expect(term.store, SubscriptionStore.other);
      expect(term.period, SubscriptionPeriod.monthly);
    });
  });
}
