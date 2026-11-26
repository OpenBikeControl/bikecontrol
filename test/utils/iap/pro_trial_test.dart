import 'package:bike_control/utils/iap/iap_manager.dart';
import 'package:bike_control/utils/iap/pro_trial.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

StoreProduct _product({IntroductoryPrice? intro, SubscriptionOption? defaultOption}) => StoreProduct(
  'pro_yearly',
  'Pro yearly',
  'Pro',
  22.99,
  '22,99 €',
  'EUR',
  introductoryPrice: intro,
  defaultOption: defaultOption,
);

IntroductoryPrice _intro(PeriodUnit unit, int units, {double price = 0, int cycles = 1}) =>
    IntroductoryPrice(price, price == 0 ? '0,00 €' : '$price €', 'P$units', cycles, unit, units);

SubscriptionOption _option({PricingPhase? freePhase}) => SubscriptionOption(
  'base:trial',
  'pro_yearly:base',
  'pro_yearly',
  [?freePhase],
  const [],
  false,
  const Period(PeriodUnit.year, 1, 'P1Y'),
  false,
  null,
  freePhase,
  null,
  null,
  null,
);

PricingPhase _free(PeriodUnit unit, int value, {int? cycles = 1}) => PricingPhase(
  Period(unit, value, 'P$value'),
  RecurrenceMode.finiteRecurring,
  cycles,
  const Price('Free', 0, 'EUR'),
  OfferPaymentMode.freeTrial,
);

void main() {
  group('App Store intro offer', () {
    test('a free intro price is the trial, in months, weeks or days', () {
      expect(
        ProTrial.fromStoreProduct(_product(intro: _intro(PeriodUnit.month, 2)), android: false),
        const ProTrial(ProTrialUnit.month, 2),
      );
      expect(
        ProTrial.fromStoreProduct(_product(intro: _intro(PeriodUnit.week, 1)), android: false),
        const ProTrial(ProTrialUnit.week, 1),
      );
      expect(
        ProTrial.fromStoreProduct(_product(intro: _intro(PeriodUnit.day, 14)), android: false),
        const ProTrial(ProTrialUnit.day, 14),
      );
    });

    test('counts every free cycle', () {
      expect(
        ProTrial.fromStoreProduct(_product(intro: _intro(PeriodUnit.month, 1, cycles: 2)), android: false),
        const ProTrial(ProTrialUnit.month, 2),
      );
    });

    test('a paid intro price is not a free trial', () {
      expect(
        ProTrial.fromStoreProduct(_product(intro: _intro(PeriodUnit.month, 2, price: 9.99)), android: false),
        isNull,
      );
    });

    test('no intro price, no trial', () {
      expect(ProTrial.fromStoreProduct(_product(), android: false), isNull);
    });

    test('an ineligible rider (a past subscriber) sees no trial', () {
      final product = _product(intro: _intro(PeriodUnit.month, 2));
      expect(
        ProTrial.fromStoreProduct(
          product,
          android: false,
          eligibility: IntroEligibilityStatus.introEligibilityStatusIneligible,
        ),
        isNull,
      );
      expect(
        ProTrial.fromStoreProduct(
          product,
          android: false,
          eligibility: IntroEligibilityStatus.introEligibilityStatusNoIntroOfferExists,
        ),
        isNull,
      );
      expect(
        ProTrial.fromStoreProduct(
          product,
          android: false,
          eligibility: IntroEligibilityStatus.introEligibilityStatusEligible,
        ),
        const ProTrial(ProTrialUnit.month, 2),
      );
    });
  });

  group('Google Play default option', () {
    test('the free phase of the default option is the trial', () {
      expect(
        ProTrial.fromStoreProduct(
          _product(defaultOption: _option(freePhase: _free(PeriodUnit.month, 2))),
          android: true,
        ),
        const ProTrial(ProTrialUnit.month, 2),
      );
      expect(
        ProTrial.fromStoreProduct(
          _product(defaultOption: _option(freePhase: _free(PeriodUnit.day, 7, cycles: null))),
          android: true,
        ),
        const ProTrial(ProTrialUnit.day, 7),
      );
    });

    test('a default option without a free phase has no trial', () {
      expect(ProTrial.fromStoreProduct(_product(defaultOption: _option()), android: true), isNull);
      expect(ProTrial.fromStoreProduct(_product(), android: true), isNull);
    });

    test('ignores the App Store intro price', () {
      expect(
        ProTrial.fromStoreProduct(_product(intro: _intro(PeriodUnit.month, 2)), android: true),
        isNull,
      );
    });
  });

  group('Stripe yearly trial window', () {
    tearDown(() => StripeYearlyTrialPromo.now = DateTime.now);
    void at(DateTime t) => StripeYearlyTrialPromo.now = () => t;

    test('runs on Friday 27 November anywhere on Earth, same window as the backend', () {
      at(DateTime.utc(2026, 11, 26, 9, 59, 59));
      expect(StripeYearlyTrialPromo.isRunning, isFalse);
      at(DateTime.utc(2026, 11, 26, 10));
      expect(StripeYearlyTrialPromo.isRunning, isTrue);
      at(DateTime.utc(2026, 11, 28, 11, 59, 59));
      expect(StripeYearlyTrialPromo.isRunning, isTrue);
      at(DateTime.utc(2026, 11, 28, 12));
      expect(StripeYearlyTrialPromo.isRunning, isFalse);
    });

    test('offers two months on the Stripe builds only', () {
      at(DateTime.utc(2026, 11, 27, 12));
      const twoMonths = ProTrial(ProTrialUnit.month, 2);
      expect(StripeYearlyTrialPromo.trialOn(PurchaseChannel.windowsDirect), twoMonths);
      expect(StripeYearlyTrialPromo.trialOn(PurchaseChannel.microsoftStore), twoMonths);
      expect(StripeYearlyTrialPromo.trialOn(PurchaseChannel.linuxDirect), twoMonths);
      // The stores carry their own trial on the product.
      expect(StripeYearlyTrialPromo.trialOn(PurchaseChannel.appStore), isNull);
      expect(StripeYearlyTrialPromo.trialOn(PurchaseChannel.macAppStore), isNull);
      expect(StripeYearlyTrialPromo.trialOn(PurchaseChannel.playStore), isNull);
      expect(StripeYearlyTrialPromo.trialOn(PurchaseChannel.none), isNull);
    });

    test('offers nothing outside the window', () {
      at(DateTime.utc(2026, 11, 28, 12));
      expect(StripeYearlyTrialPromo.trialOn(PurchaseChannel.windowsDirect), isNull);
      at(DateTime.utc(2026, 11, 25, 12));
      expect(StripeYearlyTrialPromo.trialOn(PurchaseChannel.linuxDirect), isNull);
    });
  });
}
