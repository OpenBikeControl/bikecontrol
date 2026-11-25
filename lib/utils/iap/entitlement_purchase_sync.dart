import 'package:bike_control/models/entitlement.dart';
import 'package:flutter/foundation.dart';

/// Whether the account's entitlements unlock Base on this build (Pro is
/// checked separately). A store Base purchase stays bound to its store, with
/// two exceptions: the Windows download reads Base bought through Stripe
/// (`full_version`) from the account, and every build honours
/// [Entitlement.baseAnyPlatformProductKey], which the backend grants for a
/// Base bought during a cross-platform promotion.
bool entitlementsGrantBase({
  required Iterable<Entitlement> entitlements,
  required bool isLoggedIn,
  required bool isOutsideStoreWindowsBuild,
  DateTime? now,
}) {
  if (!isLoggedIn) return false;
  final at = now ?? DateTime.now();
  bool has(String key) => entitlements.any((e) => e.productKey == key && e.isActiveAt(at));
  return has(Entitlement.baseAnyPlatformProductKey) ||
      (isOutsideStoreWindowsBuild && has(Entitlement.fullVersionProductKey));
}

/// Keeps [isPurchased] in step with the account's entitlements. Only a
/// purchase the entitlements granted is taken back when they stop being
/// active; [recheckOtherSources] then re-reads the store, licence and
/// grandfathered state so a purchase from elsewhere is restored. While the
/// entitlements grant it, a store check that finds no purchase on this
/// device cannot clear it either.
class EntitlementPurchaseSync {
  EntitlementPurchaseSync({required this.isPurchased, required this.recheckOtherSources}) {
    isPurchased.addListener(_keepGrant);
  }

  final ValueNotifier<bool> isPurchased;
  final Future<void> Function() recheckOtherSources;

  bool _granted = false;

  void _keepGrant() {
    if (_granted && !isPurchased.value) isPurchased.value = true;
  }

  Future<void> sync({required bool entitled}) async {
    if (entitled) {
      _granted = true;
      isPurchased.value = true;
      return;
    }
    if (!_granted) return;
    _granted = false;
    isPurchased.value = false;
    await recheckOtherSources();
  }
}
