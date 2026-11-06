import 'dart:convert';

import 'package:bike_control/models/entitlement.dart';
import 'package:bike_control/services/device_identity_service.dart';
import 'package:bike_control/services/entitlements_service.dart';
import 'package:bike_control/utils/iap/entitlement_purchase_sync.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ValueNotifier<bool> isPurchased;
  late int rechecks;
  late bool storeOwnsBase;
  late EntitlementPurchaseSync sync;

  setUp(() {
    isPurchased = ValueNotifier(false);
    rechecks = 0;
    storeOwnsBase = false;
    sync = EntitlementPurchaseSync(
      isPurchased: isPurchased,
      recheckOtherSources: () async {
        rechecks++;
        if (storeOwnsBase) isPurchased.value = true;
      },
    );
  });

  test('a purchase granted by entitlements reverts once they are no longer active', () async {
    await sync.sync(entitled: true);
    expect(isPurchased.value, isTrue);

    await sync.sync(entitled: false);
    expect(isPurchased.value, isFalse);
    expect(rechecks, 1);
  });

  test('a store purchase is never cleared by entitlements', () async {
    isPurchased.value = true;

    await sync.sync(entitled: false);
    expect(isPurchased.value, isTrue);
    expect(rechecks, 0);
  });

  test('a store purchase survives the expiry of entitlements that also granted it', () async {
    isPurchased.value = true;
    storeOwnsBase = true;
    await sync.sync(entitled: true);

    await sync.sync(entitled: false);
    expect(isPurchased.value, isTrue);
  });

  test('a manual full_version grant without an end date keeps the purchase', () async {
    final now = DateTime.utc(2026, 11, 6);
    SharedPreferences.setMockInitialValues({
      'entitlements_cache_items': jsonEncode([
        const Entitlement(productKey: 'full_version', status: 'active', activeUntil: null, source: 'manual').toJson(),
      ]),
    });
    final client = SupabaseClient('https://example.test', 'test-anon-key');
    addTearDown(client.dispose);
    var clock = now;
    final entitlements = EntitlementsService(client, deviceIdentityService: DeviceIdentityService(), now: () => clock);
    await entitlements.initialize();

    await sync.sync(entitled: entitlements.hasActive('full_version'));
    clock = now.add(const Duration(days: 365));
    await sync.sync(entitled: entitlements.hasActive('full_version'));

    expect(isPurchased.value, isTrue);
    expect(rechecks, 0);
  });
}
