import 'package:bike_control/models/entitlement.dart';
import 'package:purchases_flutter/purchases_flutter.dart' show EntitlementInfo, PeriodType, Store;

/// What happens at the end of the current subscription period, as far as the
/// source knows. The page claims a renewal only for [renews].
enum SubscriptionRenewal {
  /// The store says it will renew on [SubscriptionTerm.until].
  renews,

  /// Cancelled (or not renewing): Pro stays until [SubscriptionTerm.until].
  ends,

  /// The store could not charge the last renewal.
  billingIssue,

  /// A store trial, running until [SubscriptionTerm.until].
  trial,

  /// The source does not say (the account's server entitlements carry only a
  /// date). Shown like [ends]: "active until".
  unknown,
}

enum SubscriptionPeriod { monthly, yearly }

/// Where the subscription can be managed from this app.
enum SubscriptionStore { appStore, macAppStore, playStore, billingPortal, other }

/// The current Pro subscription period: until when, whether it renews, and
/// where it was bought.
class SubscriptionTerm {
  const SubscriptionTerm({required this.renewal, this.until, this.period, this.store = SubscriptionStore.other});

  final SubscriptionRenewal renewal;
  final DateTime? until;
  final SubscriptionPeriod? period;
  final SubscriptionStore store;

  /// From the store's own record of the `pro` entitlement (iOS, Android,
  /// macOS), which knows whether the subscription renews.
  factory SubscriptionTerm.fromRevenueCat(EntitlementInfo info) {
    final until = DateTime.tryParse(info.expirationDate ?? '');
    final renewal = info.billingIssueDetectedAt != null
        ? SubscriptionRenewal.billingIssue
        : until == null
        ? SubscriptionRenewal.unknown
        : info.periodType == PeriodType.trial
        ? SubscriptionRenewal.trial
        : info.willRenew && info.unsubscribeDetectedAt == null
        ? SubscriptionRenewal.renews
        : SubscriptionRenewal.ends;
    return SubscriptionTerm(
      renewal: renewal,
      until: until,
      period: _periodOf(info.productIdentifier),
      store: switch (info.store) {
        Store.appStore => SubscriptionStore.appStore,
        Store.macAppStore => SubscriptionStore.macAppStore,
        Store.playStore => SubscriptionStore.playStore,
        _ => SubscriptionStore.other,
      },
    );
  }

  /// From the account's entitlement row. The server returns only the date
  /// (not whether the subscription renews), so this never claims a renewal.
  factory SubscriptionTerm.fromEntitlement(Entitlement entitlement) {
    return SubscriptionTerm(
      renewal: SubscriptionRenewal.unknown,
      until: entitlement.activeUntil,
      period: _periodOf(entitlement.productKey),
      store: entitlement.source == 'stripe' ? SubscriptionStore.billingPortal : SubscriptionStore.other,
    );
  }

  static SubscriptionPeriod? _periodOf(String product) {
    final id = product.toLowerCase();
    if (id.contains('year') || id.contains('annual') || id.contains('p1y')) return SubscriptionPeriod.yearly;
    if (id.contains('month') || id.contains('p1m')) return SubscriptionPeriod.monthly;
    return null;
  }
}
