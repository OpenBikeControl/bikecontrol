import 'dart:convert';

import 'package:bike_control/models/entitlement.dart';
import 'package:bike_control/services/device_identity_service.dart';
import 'package:bike_control/services/entitlements_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final DateTime _now = DateTime.utc(2026, 11, 6, 12);
final DateTime _past = _now.subtract(const Duration(days: 1));
final DateTime _future = _now.add(const Duration(days: 1));

Entitlement _entitlement({required String source, DateTime? activeUntil, String status = 'active'}) => Entitlement(
  productKey: 'premium_monthly',
  status: status,
  activeUntil: activeUntil,
  source: source,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Entitlement.isActiveAt', () {
    test('manual grant past its end date is inactive', () {
      expect(_entitlement(source: 'manual', activeUntil: _past).isActiveAt(_now), isFalse);
    });

    test('manual grant before its end date is active', () {
      expect(_entitlement(source: 'manual', activeUntil: _future).isActiveAt(_now), isTrue);
    });

    test('manual grant without an end date stays active', () {
      expect(_entitlement(source: 'manual').isActiveAt(_now), isTrue);
    });

    for (final source in ['stripe', 'revenuecat']) {
      test('$source row past its end date follows status only', () {
        expect(_entitlement(source: source, activeUntil: _past).isActiveAt(_now), isTrue);
      });
    }

    test('expired status is inactive', () {
      expect(_entitlement(source: 'manual', status: 'expired', activeUntil: _future).isActiveAt(_now), isFalse);
      expect(_entitlement(source: 'stripe', status: 'expired', activeUntil: _future).isActiveAt(_now), isFalse);
    });
  });

  group('EntitlementsService.hasActive', () {
    test('drops a manual grant once its end date passes', () async {
      SharedPreferences.setMockInitialValues({
        'entitlements_cache_items': jsonEncode([
          _entitlement(source: 'manual', activeUntil: _past).toJson(),
          const Entitlement(productKey: 'beta_access', status: 'active', activeUntil: null, source: 'manual').toJson(),
        ]),
      });
      final client = SupabaseClient('https://example.test', 'test-anon-key');
      addTearDown(client.dispose);

      final service = EntitlementsService(client, deviceIdentityService: DeviceIdentityService(), now: () => _now);
      await service.initialize();

      expect(service.hasActive('premium_monthly'), isFalse);
      expect(service.hasActive('beta_access'), isTrue);
    });
  });

  group('Pro entitlements', () {
    Entitlement row(String key, {String source = 'revenuecat', DateTime? activeUntil, String status = 'active'}) =>
        Entitlement(productKey: key, status: status, activeUntil: activeUntil, source: source);

    test('subscriptions and RevenueCat promotional Pro grants are Pro', () {
      for (final key in ['premium_monthly', 'premium_yearly', 'rc_promo_pro_weekly', 'rc_promo_pro_lifetime']) {
        expect(row(key).isPro, isTrue, reason: key);
      }
    });

    test('Base, beta and promotional Base grants are not Pro', () {
      for (final key in ['full_version', 'full_access_unlock', 'beta_access', 'rc_promo_Full Version_lifetime']) {
        expect(row(key).isPro, isFalse, reason: key);
      }
    });

    test('a promotional grant ends at its end date even before RevenueCat expires the row', () {
      expect(row('rc_promo_pro_weekly', activeUntil: _past).isActiveAt(_now), isFalse);
      expect(row('rc_promo_pro_weekly', activeUntil: _future).isActiveAt(_now), isTrue);
      expect(row('rc_promo_pro_lifetime').isActiveAt(_now), isTrue);
    });

    Future<EntitlementsService> serviceWith(List<Entitlement> rows) async {
      SharedPreferences.setMockInitialValues({
        'entitlements_cache_items': jsonEncode([for (final r in rows) r.toJson()]),
      });
      final client = SupabaseClient('https://example.test', 'test-anon-key');
      addTearDown(client.dispose);
      final service = EntitlementsService(client, deviceIdentityService: DeviceIdentityService(), now: () => _now);
      await service.initialize();
      return service;
    }

    test('hasActivePro counts a promotional Pro week', () async {
      final service = await serviceWith([row('rc_promo_pro_weekly', activeUntil: _future)]);

      expect(service.hasActivePro, isTrue);
      expect(service.proActiveUntil, _future);
    });

    test('hasActivePro is false with only Base or an expired promo', () async {
      final service = await serviceWith([
        row('full_version'),
        row('rc_promo_pro_weekly', status: 'expired', activeUntil: _past),
      ]);

      expect(service.hasActivePro, isFalse);
    });
  });
}
