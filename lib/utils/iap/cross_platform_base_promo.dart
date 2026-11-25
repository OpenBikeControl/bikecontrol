import 'package:bike_control/utils/iap/iap_manager.dart';
import 'package:flutter/foundation.dart';

/// A window in which a Base purchase unlocks Base on every platform. The
/// backend decides who qualifies (`get-entitlements`, by the store's purchase
/// time); this copy only decides when the paywall says so, and must match
/// `CROSS_PLATFORM_BASE_PROMOS` there.
class CrossPlatformBasePromo {
  const CrossPlatformBasePromo._();

  /// Black Friday 2026: Friday 27 November anywhere on Earth.
  static final DateTime startsAt = DateTime.utc(2026, 11, 26, 10);
  static final DateTime endsAt = DateTime.utc(2026, 11, 28, 12);

  @visibleForTesting
  static DateTime Function() now = DateTime.now;

  static bool get isRunning {
    final at = now();
    return !at.isBefore(startsAt) && at.isBefore(endsAt);
  }

  /// Where a Base bought now reaches the account, so the backend can carry it
  /// to other platforms (the Microsoft Store through MsStoreCollectionsSync).
  /// Linux has no Base to buy.
  static bool appliesTo(PurchaseChannel channel) => switch (channel) {
    PurchaseChannel.appStore ||
    PurchaseChannel.macAppStore ||
    PurchaseChannel.playStore ||
    PurchaseChannel.windowsDirect ||
    PurchaseChannel.microsoftStore => true,
    PurchaseChannel.linuxDirect || PurchaseChannel.none => false,
  };

  static bool isOfferedOn(PurchaseChannel channel) => isRunning && appliesTo(channel);
}
