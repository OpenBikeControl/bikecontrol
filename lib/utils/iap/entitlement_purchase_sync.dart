import 'package:flutter/foundation.dart';

/// Keeps [isPurchased] in step with the account's entitlements. Only a
/// purchase the entitlements granted is taken back when they stop being
/// active; [recheckOtherSources] then re-reads the store, licence and
/// grandfathered state so a purchase from elsewhere is restored.
class EntitlementPurchaseSync {
  EntitlementPurchaseSync({required this.isPurchased, required this.recheckOtherSources});

  final ValueNotifier<bool> isPurchased;
  final Future<void> Function() recheckOtherSources;

  bool _granted = false;

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
