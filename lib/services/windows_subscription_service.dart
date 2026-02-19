import 'package:bike_control/services/entitlements_service.dart';
import 'package:bike_control/services/device_identity_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:windows_iap/windows_iap.dart';

class WindowsSubscriptionService {
  static const String createSyncTokenFunction = 'windows/create-sync-token';
  static const String syncLicenseFunction = 'windows/sync-license';

  final SupabaseClient _supabase;
  final WindowsIap _windowsIap;
  final EntitlementsService _entitlements;
  final DeviceIdentityService _deviceIdentityService;

  WindowsSubscriptionService({
    required SupabaseClient supabase,
    required WindowsIap windowsIap,
    required EntitlementsService entitlements,
    required DeviceIdentityService deviceIdentityService,
  }) : _supabase = supabase,
       _windowsIap = windowsIap,
       _entitlements = entitlements,
       _deviceIdentityService = deviceIdentityService;

  Future<void> restoreOrSyncSubscription({
    required String productStoreId,
  }) async {
    final session = _supabase.auth.currentSession;
    if (session == null) {
      throw StateError('No active Supabase session');
    }
    final platform = await _deviceIdentityService.currentPlatform();
    if (platform == null || platform.isEmpty) {
      throw StateError('Unsupported platform for Windows subscription sync');
    }
    final deviceId = await _deviceIdentityService.getOrCreateDeviceId();

    final token = await _createSyncToken(session);
    final b2bKey = await getB2BKey(
      serviceTicket: token,
      publisherUserId: session.user.id,
    );

    await _supabase.functions.invoke(
      syncLicenseFunction,
      method: HttpMethod.post,
      headers: {
        'Authorization': 'Bearer ${session.accessToken}',
        'X-Device-Platform': platform,
        'X-Device-Id': deviceId,
      },
      body: {
        'token': token,
        'b2bKey': b2bKey,
        'product_store_id': productStoreId,
      },
    );

    await _entitlements.refresh(force: true);
  }

  Future<String> getB2BKey({
    required String serviceTicket,
    required String publisherUserId,
  }) async {
    final value = await _windowsIap.getCustomerPurchaseIdKey(
      serviceTicket: serviceTicket,
      publisherUserId: publisherUserId,
    );
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
