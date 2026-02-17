import 'package:bike_control/services/entitlements_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:windows_iap/windows_iap.dart';

class WindowsSubscriptionService {
  static const String createSyncTokenFunction = 'windows/create-sync-token';
  static const String syncLicenseFunction = 'windows/sync-license';

  final SupabaseClient _supabase;
  final WindowsIap _windowsIap;
  final EntitlementsService _entitlements;

  WindowsSubscriptionService({
    required SupabaseClient supabase,
    required WindowsIap windowsIap,
    required EntitlementsService entitlements,
  }) : _supabase = supabase,
       _windowsIap = windowsIap,
       _entitlements = entitlements;

  Future<void> restoreOrSyncSubscription({
    required String productStoreId,
  }) async {
    final session = _supabase.auth.currentSession;
    if (session == null) {
      throw StateError('No active Supabase session');
    }

    final token = await _createSyncToken(session);
    final b2bKey = await getB2BKey();

    await _supabase.functions.invoke(
      syncLicenseFunction,
      method: HttpMethod.post,
      headers: {'Authorization': 'Bearer ${session.accessToken}'},
      body: {
        'token': token,
        'b2bKey': b2bKey,
        'product_store_id': productStoreId,
      },
    );

    await _entitlements.refresh(force: true);
  }

  Future<String> getB2BKey() async {
    final value = await _windowsIap.getCustomerPurchaseIdKey();
    if (value.isEmpty) {
      throw StateError('Empty B2B key from Microsoft Store bridge');
    }
    return value;
  }

  Future<String> _createSyncToken(Session session) async {
    final response = await _supabase.functions.invoke(
      createSyncTokenFunction,
      method: HttpMethod.post,
      headers: {'Authorization': 'Bearer ${session.accessToken}'},
    );
    final payload = response.data;
    if (payload is! Map) {
      throw StateError('Unexpected sync token response: $payload');
    }
    final token = payload['token'] as String?;
    if (token == null || token.isEmpty) {
      throw StateError('Missing sync token in response: $payload');
    }
    return token;
  }
}
