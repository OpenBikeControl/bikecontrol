// get-entitlements returned 401 for hundreds of users in production, every
// one carrying an expired JWT. At cold start the stored session's access token
// is often already expired. The services read `auth.currentSession` and passed
// `Authorization: Bearer <that token>` explicitly to `functions.invoke`, which
// overrides the header supabase's AuthHttpClient would attach after its own
// refresh (it uses `putIfAbsent`). These tests wire a real SupabaseClient to a
// fake HTTP transport, seed an expired session the way supabase_flutter does at
// start-up (`setInitialSession`), and assert the edge function only ever sees
// the refreshed token.
import 'dart:convert';
import 'dart:typed_data';

import 'package:bike_control/services/device_identity_service.dart';
import 'package:bike_control/services/device_management_service.dart';
import 'package:bike_control/services/entitlements_service.dart';
import 'package:bike_control/services/support_chat_service.dart';
import 'package:bike_control/utils/auth/fresh_access_token.dart';
import 'package:bike_control/utils/iap/windows_stripe_service.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:yet_another_json_isolate/yet_another_json_isolate.dart';

String _b64(Map<String, dynamic> json) => base64Url.encode(utf8.encode(jsonEncode(json))).replaceAll('=', '');

/// A JWT-shaped token: gotrue derives `Session.expiresAt` from the `exp` claim.
String _jwt(String label, DateTime exp) =>
    '${_b64({'alg': 'HS256', 'typ': 'JWT'})}.'
    '${_b64({'sub': 'user-id', 'label': label, 'exp': exp.millisecondsSinceEpoch ~/ 1000})}.sig';

final String _staleToken = _jwt('stale', DateTime.now().subtract(const Duration(minutes: 5)));
final String _freshToken = _jwt('fresh', DateTime.now().add(const Duration(hours: 1)));
final String _validButRejectedToken = _jwt('rejected', DateTime.now().add(const Duration(minutes: 30)));

Map<String, dynamic> _sessionJson(String accessToken) => {
  'access_token': accessToken,
  'token_type': 'bearer',
  'expires_in': 3600,
  'refresh_token': 'test-refresh-token',
  'user': {
    'id': 'user-id',
    'aud': 'authenticated',
    'created_at': '2026-08-24T00:00:00Z',
    'app_metadata': <String, dynamic>{},
    'user_metadata': <String, dynamic>{},
    'is_anonymous': false,
    'email': 'rider@example.com',
  },
};

class _FakeBackend extends http.BaseClient {
  final List<http.BaseRequest> functionRequests = [];
  int refreshCalls = 0;

  /// Status codes to answer function calls with, consumed in order; 200 after.
  final List<int> functionStatuses = [];

  Map<String, dynamic> Function(String path) functionBody = (_) => {
    'entitlements': <dynamic>[],
    'is_registered_device': true,
  };

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final path = request.url.path;
    if (path.endsWith('/auth/v1/token')) {
      refreshCalls++;
      return _json(request, _sessionJson(_freshToken));
    }
    if (path.contains('/functions/v1/')) {
      functionRequests.add(request);
      final status = functionStatuses.isEmpty ? 200 : functionStatuses.removeAt(0);
      if (status != 200) {
        return _json(request, {'error': 'Invalid JWT'}, status: status);
      }
      return _json(request, functionBody(path));
    }
    return _json(request, <String, dynamic>{}, status: 404);
  }

  http.StreamedResponse _json(http.BaseRequest request, dynamic body, {int status = 200}) {
    return http.StreamedResponse(
      Stream.value(utf8.encode(jsonEncode(body))),
      status,
      request: request,
      headers: const {'content-type': 'application/json'},
    );
  }
}

class _SynchronousJsonIsolate extends YAJsonIsolate {
  @override
  Future<void> initialize() async {}

  @override
  Future<String> encode(Object? json) async => jsonEncode(json);

  @override
  Future<dynamic> decode(String json) async => jsonDecode(json);

  @override
  Future<void> dispose() async {}
}

class _FakeDeviceIdentity extends DeviceIdentityService {
  @override
  Future<String?> currentPlatform() async => 'android';

  @override
  Future<String> getOrCreateDeviceId() async => 'device-1';
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _FakeBackend backend;
  late SupabaseClient client;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    backend = _FakeBackend();
    client = SupabaseClient(
      'https://example.test',
      'test-anon-key',
      httpClient: backend,
      authOptions: const AuthClientOptions(autoRefreshToken: false),
      isolate: _SynchronousJsonIsolate(),
    );
  });

  tearDown(() => client.dispose());

  Future<void> seedSession(String accessToken) async {
    // supabase_flutter restores the persisted session this way at start-up,
    // without checking expiry.
    await client.auth.setInitialSession(jsonEncode(_sessionJson(accessToken)));
  }

  List<String?> sentAuthHeaders() => backend.functionRequests.map((r) => r.headers['Authorization']).toList();

  group('EntitlementsService', () {
    test('an expired stored session is refreshed before get-entitlements, never sent as-is', () async {
      await seedSession(_staleToken);
      expect(client.auth.currentSession!.isExpired, isTrue, reason: 'sanity: seeded session is expired');

      final service = EntitlementsService(client, deviceIdentityService: _FakeDeviceIdentity());
      await service.refresh(force: true);

      expect(sentAuthHeaders(), ['Bearer $_freshToken']);
      expect(backend.functionRequests.single.headers['X-Device-Id'], 'device-1');
      expect(service.isRegisteredDevice, isTrue);
    });

    test('a 401 refreshes the session once and retries once with the new token', () async {
      await seedSession(_validButRejectedToken);
      backend.functionStatuses.add(401);

      final service = EntitlementsService(client, deviceIdentityService: _FakeDeviceIdentity());
      await service.refresh(force: true);

      expect(sentAuthHeaders(), ['Bearer $_validButRejectedToken', 'Bearer $_freshToken']);
      expect(backend.refreshCalls, 1);
      expect(service.isRegisteredDevice, isTrue);
    });

    test('a second 401 is not retried again', () async {
      await seedSession(_validButRejectedToken);
      backend.functionStatuses.addAll([401, 401]);

      final service = EntitlementsService(client, deviceIdentityService: _FakeDeviceIdentity());
      await service.refresh(force: true);

      expect(backend.functionRequests, hasLength(2));
      expect(service.isRegisteredDevice, isFalse);
    });
  });

  group('DeviceManagementService', () {
    test('getMyDevices sends the refreshed token, not the expired one', () async {
      await seedSession(_staleToken);
      backend.functionBody = (_) => {'devices': <dynamic>[]};

      final service = DeviceManagementService(supabase: client, deviceIdentityService: _FakeDeviceIdentity());
      await service.getMyDevices();

      expect(sentAuthHeaders(), ['Bearer $_freshToken']);
    });
  });

  group('WindowsStripeService', () {
    test('hasStripeCustomer sends the refreshed token, not the expired one', () async {
      await seedSession(_staleToken);
      backend.functionBody = (_) => {'url': 'https://example.test/portal'};

      await WindowsStripeService(client).hasStripeCustomer();

      expect(sentAuthHeaders(), ['Bearer $_freshToken']);
    });
  });

  group('SupportChatService', () {
    test('deleteSupportData sends the refreshed token, not the expired one', () async {
      await seedSession(_staleToken);
      backend.functionBody = (_) => {'ok': true};

      // setSupportChatActive on success needs core.settings prefs; the request
      // is what matters here, so a later failure is fine.
      try {
        await SupportChatService(supabase: client, httpClient: backend).deleteSupportData(SupportDeleteScope.conversation);
      } catch (_) {}

      expect(sentAuthHeaders(), ['Bearer $_freshToken']);
    });

    test('uploadAttachment (raw multipart, bypasses AuthHttpClient) sends the refreshed token', () async {
      await seedSession(_staleToken);
      backend.functionBody = (_) => {'storage_path': 'a/b.png', 'mime_type': 'image/png', 'size_bytes': 3};

      try {
        await SupportChatService(supabase: client, httpClient: backend).uploadAttachment(
          chatId: 'chat-1',
          file: PlatformFile(name: 'shot.png', size: 3, bytes: Uint8List.fromList([1, 2, 3])),
        );
      } catch (_) {}

      expect(sentAuthHeaders(), ['Bearer $_freshToken']);
    });
  });

  group('accessTokenNeedsRefresh', () {
    final now = DateTime(2026, 10, 4, 12);
    Session sessionExpiringAt(DateTime exp) => Session.fromJson(_sessionJson(_jwt('x', exp)))!;

    test('expired token needs refresh', () {
      expect(accessTokenNeedsRefresh(sessionExpiringAt(now.subtract(const Duration(seconds: 1))), now: now), isTrue);
    });

    test('token expiring within the margin needs refresh', () {
      expect(accessTokenNeedsRefresh(sessionExpiringAt(now.add(const Duration(seconds: 20))), now: now), isTrue);
    });

    test('token valid beyond the margin does not', () {
      expect(accessTokenNeedsRefresh(sessionExpiringAt(now.add(const Duration(minutes: 5))), now: now), isFalse);
    });
  });
}
