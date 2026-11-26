import 'package:bike_control/gen/l10n.dart';
import 'package:bike_control/utils/iap/iap_manager.dart';
import 'package:flutter/foundation.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

enum ProTrialUnit { day, week, month, year }

/// A free trial on a Pro subscription: how long it lasts before the first
/// charge. Read from the store product, never assumed, so the paywall says
/// exactly what the store sheet will.
@immutable
class ProTrial {
  const ProTrial(this.unit, this.count);

  final ProTrialUnit unit;
  final int count;

  /// The free trial [product] starts with for this rider, or null.
  ///
  /// App Store (iOS/macOS): a free introductory price (price 0) over
  /// `periodNumberOfUnits` × `cycles`. [eligibility] comes from
  /// `Purchases.checkTrialOrIntroductoryPriceEligibility`: a rider who already
  /// had one (a past subscriber) gets none. Unknown still shows the offer the
  /// product carries.
  ///
  /// Google Play: the free phase of the default option, which is what
  /// RevenueCat buys. Play only returns offers the rider is eligible for.
  static ProTrial? fromStoreProduct(
    StoreProduct product, {
    required bool android,
    IntroEligibilityStatus? eligibility,
  }) {
    if (android) {
      final phase = product.defaultOption?.freePhase;
      final period = phase?.billingPeriod;
      if (phase == null || period == null) return null;
      return _of(period.unit, period.value * (phase.billingCycleCount ?? 1));
    }
    if (eligibility == IntroEligibilityStatus.introEligibilityStatusIneligible ||
        eligibility == IntroEligibilityStatus.introEligibilityStatusNoIntroOfferExists) {
      return null;
    }
    final intro = product.introductoryPrice;
    if (intro == null || intro.price != 0) return null;
    return _of(intro.periodUnit, intro.periodNumberOfUnits * (intro.cycles < 1 ? 1 : intro.cycles));
  }

  static ProTrial? _of(PeriodUnit unit, int count) {
    if (count <= 0) return null;
    return switch (unit) {
      PeriodUnit.day => ProTrial(ProTrialUnit.day, count),
      PeriodUnit.week => ProTrial(ProTrialUnit.week, count),
      PeriodUnit.month => ProTrial(ProTrialUnit.month, count),
      PeriodUnit.year => ProTrial(ProTrialUnit.year, count),
      PeriodUnit.unknown => null,
    };
  }

  /// "2 months", "1 week", "14 days" in the rider's language.
  String label(AppLocalizations l10n) => switch (unit) {
    ProTrialUnit.day => l10n.paywall_trialDays(count),
    ProTrialUnit.week => l10n.paywall_trialWeeks(count),
    ProTrialUnit.month => l10n.paywall_trialMonths(count),
    ProTrialUnit.year => l10n.paywall_trialYears(count),
  };

  @override
  bool operator ==(Object other) => other is ProTrial && other.unit == unit && other.count == count;

  @override
  int get hashCode => Object.hash(unit, count);

  @override
  String toString() => 'ProTrial($count ${unit.name})';
}

/// The Stripe builds (Windows outside the store, Microsoft Store Pro, Linux)
/// have no product to read a trial from. During this window the backend's
/// `stripe-checkout` adds a 60-day trial to yearly checkouts; this copy only
/// decides when the paywall says so, and must match the backend.
class StripeYearlyTrialPromo {
  const StripeYearlyTrialPromo._();

  /// Black Friday 2026: Friday 27 November anywhere on Earth.
  static final DateTime startsAt = DateTime.utc(2026, 11, 26, 10);
  static final DateTime endsAt = DateTime.utc(2026, 11, 28, 12);

  static const ProTrial trial = ProTrial(ProTrialUnit.month, 2);

  @visibleForTesting
  static DateTime Function() now = DateTime.now;

  static bool get isRunning {
    final at = now();
    return !at.isBefore(startsAt) && at.isBefore(endsAt);
  }

  static bool appliesTo(PurchaseChannel channel) => switch (channel) {
    PurchaseChannel.windowsDirect || PurchaseChannel.microsoftStore || PurchaseChannel.linuxDirect => true,
    PurchaseChannel.appStore ||
    PurchaseChannel.macAppStore ||
    PurchaseChannel.playStore ||
    PurchaseChannel.none => false,
  };

  /// The yearly trial a Stripe checkout on [channel] starts with now, or null.
  static ProTrial? trialOn(PurchaseChannel channel) => isRunning && appliesTo(channel) ? trial : null;
}
