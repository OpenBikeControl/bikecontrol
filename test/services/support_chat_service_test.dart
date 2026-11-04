// Bug 1 (usage-fixes round): `fetchOpenIssues()` filtered `is_public = true`
// but never filtered by `status`, so issues already marked `solved` (website
// migration 20260515000000_add_issue_status_visibility.sql added
// `status text NOT NULL DEFAULT 'open' CHECK (status IN ('open','solved'))`)
// kept showing in the Known Issues section despite the method's own name.
// This pins the actual outgoing query — wiring a real SupabaseClient to a
// fake HTTP transport (the same "swap the transport, keep the real types"
// approach feedback_submission_service_test.dart and
// support_chat_page_test.dart use) so the real postgrest query-builder call
// is exercised, not a hand-rolled stand-in that could drift from it.
import 'dart:convert';

import 'package:bike_control/services/support_chat_service.dart';
import 'package:bike_control/utils/core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:yet_another_json_isolate/yet_another_json_isolate.dart';

class _FakeIssuesHttp extends http.BaseClient {
  final List<http.Request> issuesRequests = [];
  final List<http.Request> deleteRequests = [];
  final List<http.Request> sendRequests = [];
  int deleteStatus = 200;
  Map<String, dynamic> deleteBody = const {'ok': true};

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final req = request as http.Request;
    if (request.url.path.endsWith('/rest/v1/issues')) {
      issuesRequests.add(req);
      return _json(request, <dynamic>[]);
    }
    if (request.url.path.endsWith('/functions/v1/delete-support-data')) {
      deleteRequests.add(req);
      return _json(request, deleteBody, status: deleteStatus);
    }
    if (request.url.path.endsWith('/functions/v1/send-support-message')) {
      sendRequests.add(req);
      return _json(request, {
        'message': {
          'id': 'message-id',
          'chat_id': 'chat-id',
          'sender_id': 'user-id',
          'sender_role': 'user',
          'body': 'echo',
          'created_at': '2026-11-04T10:42:02Z',
        },
      });
    }
    return _json(request, <String, dynamic>{}, status: 404);
  }

  // postgrest's response parsing does `response.request!.method` — the
  // `StreamedResponse` must carry the original request back or that
  // null-check blows up before our query ever gets asserted on.
  http.StreamedResponse _json(http.BaseRequest request, dynamic body, {int status = 200}) {
    return http.StreamedResponse(
      Stream.value(utf8.encode(jsonEncode(body))),
      status,
      request: request,
      headers: const {'content-type': 'application/json'},
    );
  }
}

/// Decode/encode in-process — see the note in support_chat_page_test.dart.
/// functions.invoke() would otherwise wait on the real isolate the test loop
/// never drives.
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

Map<String, dynamic> _sessionJson() => {
  'access_token': 'test-access-token',
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

void main() {
  late _FakeIssuesHttp fakeHttp;
  late SupabaseClient client;
  late SupportChatService service;

  setUp(() async {
    // fetchOpenIssues() reads core.settings.getTrainerApp() directly (the
    // ambient singleton, not an injected Settings) — prefs must exist before
    // that call or it throws. Same setUp shape as help_center_sections_test.dart.
    SharedPreferences.setMockInitialValues({});
    core.settings.prefs = await SharedPreferences.getInstance();

    fakeHttp = _FakeIssuesHttp();
    client = SupabaseClient(
      'https://example.test',
      'test-anon-key',
      httpClient: fakeHttp,
      authOptions: const AuthClientOptions(autoRefreshToken: false),
      isolate: _SynchronousJsonIsolate(),
    );
    service = SupportChatService(supabase: client, httpClient: fakeHttp);
  });

  tearDown(() => client.dispose());

  group('fetchOpenIssues', () {
    test('filters to status=open, not just is_public — solved issues must not come back', () async {
      await service.fetchOpenIssues();

      expect(fakeHttp.issuesRequests, hasLength(1));
      final uri = fakeHttp.issuesRequests.single.url;
      expect(uri.queryParameters['is_public'], 'eq.true', reason: 'sanity: the existing filter is still there');
      expect(
        uri.queryParameters['status'],
        'eq.open',
        reason: 'fetchOpenIssues must exclude solved issues despite its own name — see Bug 1',
      );
    });
  });

  group('deleteSupportData', () {
    setUp(() async {
      await client.auth.recoverSession(jsonEncode(_sessionJson()));
      // openChat marks the chat active; a deletion must clear it so HelpButton
      // stops polling for replies to a thread that no longer exists.
      await core.settings.setSupportChatActive(true);
    });

    test('conversation scope calls delete-support-data with scope=conversation and the bearer token', () async {
      await service.deleteSupportData(SupportDeleteScope.conversation);

      expect(fakeHttp.deleteRequests, hasLength(1));
      final req = fakeHttp.deleteRequests.single;
      expect(jsonDecode(req.body)['scope'], 'conversation');
      expect(req.headers['Authorization'], 'Bearer test-access-token');
    });

    test('account scope calls delete-support-data with scope=account', () async {
      await service.deleteSupportData(SupportDeleteScope.account);

      expect(fakeHttp.deleteRequests, hasLength(1));
      expect(jsonDecode(fakeHttp.deleteRequests.single.body)['scope'], 'account');
    });

    test('clears the "support chat active" flag after a successful delete', () async {
      expect(core.settings.getSupportChatActive(), isTrue);

      await service.deleteSupportData(SupportDeleteScope.conversation);

      expect(core.settings.getSupportChatActive(), isFalse);
    });

    test('a non-2xx response surfaces a SupportChatException', () async {
      fakeHttp.deleteStatus = 500;
      fakeHttp.deleteBody = const {'error': 'boom'};

      await expectLater(
        service.deleteSupportData(SupportDeleteScope.conversation),
        throwsA(isA<SupportChatException>()),
      );
    });

    test('throws without a session instead of calling the backend', () async {
      await client.auth.signOut();

      await expectLater(
        service.deleteSupportData(SupportDeleteScope.conversation),
        throwsA(isA<SupportChatException>()),
      );
      expect(fakeHttp.deleteRequests, isEmpty);
    });
  });

  group('sendMessage', () {
    setUp(() async {
      await client.auth.recoverSession(jsonEncode(_sessionJson()));
    });

    // Postgres rejects U+0000 in text columns (22P05), so one NUL anywhere in
    // the attached diagnostics failed every send from that device.
    test('strips NUL characters from the body and every telemetry string', () async {
      await service.sendMessage(
        chatId: 'chat-id',
        body: 'brake lights\u0000 stay on',
        telemetry: {
          'firmware_version': '1.2.0\u0000',
          'freetext': 'Logs:\n10:42 - Found new device: HRM\u0000\u0000',
          'trainer_ftms_machine_features': ['cadence\u0000'],
          'self_test_result': {
            'stepLog': ['step\u0000 1'],
          },
          'grade_smoothing': true,
        },
      );

      expect(fakeHttp.sendRequests, hasLength(1));
      final rawBody = fakeHttp.sendRequests.single.body;
      expect(rawBody, isNot(contains(r'\u0000')));
      final payload = jsonDecode(rawBody) as Map<String, dynamic>;
      expect(payload['body'], 'brake lights stay on');
      expect(payload['firmware_version'], '1.2.0');
      expect(payload['freetext'], 'Logs:\n10:42 - Found new device: HRM');
      expect(payload['trainer_ftms_machine_features'], ['cadence']);
      expect(payload['self_test_result'], {
        'stepLog': ['step 1'],
      });
      expect(payload['grade_smoothing'], isTrue);
    });
  });
}
