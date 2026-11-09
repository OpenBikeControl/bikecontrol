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
}
