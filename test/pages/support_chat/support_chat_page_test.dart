// "Write first, sign in afterwards": SupportChatPage no longer gates writing
// on a session (no more _signInGate/LoginPage push). These tests wire a real
// SupabaseClient to a fake HTTP transport — the same "swap the transport,
// keep the real types" approach test/services/feedback_submission_service_test.dart
// uses — so the page's actual anonymous-sign-in-on-demand and email-link-up
// logic runs end to end with no network and no dependency on the ambient
// core.supabase singleton. SupportChatPage's `service`/`accountService`
// constructor params are the test seam that makes this possible.
import 'dart:convert';

import 'package:bike_control/gen/l10n.dart';
import 'package:bike_control/pages/support_chat/support_chat_page.dart';
import 'package:bike_control/services/feedback_submission_service.dart';
import 'package:bike_control/services/support_chat_service.dart';
import 'package:bike_control/services/telemetry_snapshot.dart';
import 'package:bike_control/utils/actions/base_actions.dart';
import 'package:bike_control/utils/core.dart';
import 'package:bike_control/utils/support/intake_options.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:yet_another_json_isolate/yet_another_json_isolate.dart';

/// `SupabaseClient` normally does its JSON encode/decode on a real
/// background `Isolate` (`YAJsonIsolate`). That isolate's message-passing
/// runs on the real event loop, which `testWidgets`' fake-async pump loop
/// does not drive — every `functions.invoke()`/postgrest call would hang
/// forever waiting on a response that never arrives, timing out
/// `pumpAndSettle` with the loading spinner stuck on screen. Encoding/
/// decoding in-process instead sidesteps the mismatch entirely.
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

/// Fake transport standing in for the subset of Supabase's Auth, Functions
/// and REST APIs that SupportChatPage + FeedbackSubmissionService can reach.
class _FakeSupportChatHttp extends http.BaseClient {
  final List<http.Request> signupRequests = [];
  final List<http.Request> userRequests = [];
  final List<http.Request> verifyRequests = [];
  final List<http.Request> openChatRequests = [];
  final List<http.Request> getChatRequests = [];
  final List<http.Request> sendMessageRequests = [];
  final List<http.Request> deleteRequests = [];

  /// Whether a chat already exists server-side. Defaults to `true` so every
  /// existing test (which never cared about this distinction) keeps seeing a
  /// chat back from get-support-chat immediately, same as before. Tests for
  /// the lazy-create behaviour flip this to `false` first to model a
  /// signed-in rider who has never sent a message — get-support-chat must
  /// then report `chat: null`, exactly like the real get-only edge function.
  bool chatAlreadyExists = true;

  Object? signInAnonymouslyError;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final req = request as http.Request;
    final path = request.url.path;

    if (path.endsWith('/functions/v1/create-or-get-support-chat')) {
      openChatRequests.add(req);
      chatAlreadyExists = true;
      return _json({'chat': _chatJson()});
    }
    if (path.endsWith('/functions/v1/get-support-chat')) {
      getChatRequests.add(req);
      return _json({'chat': chatAlreadyExists ? _chatJson() : null, 'messages': <dynamic>[]});
    }
    if (path.endsWith('/functions/v1/send-support-message')) {
      sendMessageRequests.add(req);
      final sentBody = jsonDecode(req.body) as Map<String, dynamic>;
      return _json({
        'message': {
          'id': 'msg-${sendMessageRequests.length}',
          'chat_id': sentBody['chat_id'],
          'sender_id': 'user-id',
          'sender_role': 'user',
          'body': sentBody['body'],
          'parent_message_id': null,
          'created_at': '2026-08-24T00:00:00Z',
          'attachments': <dynamic>[],
        },
      });
    }
    if (path.endsWith('/functions/v1/delete-support-data')) {
      deleteRequests.add(req);
      return _json({'ok': true});
    }
    if (path.endsWith('/rest/v1/issues')) {
      return _json(<dynamic>[]);
    }
    // Local sign-out clears the session without a network call, but keep this
    // as a safety net so an accidental global sign-out never 404s the test.
    if (path.endsWith('/auth/v1/logout')) {
      return _json(<String, dynamic>{}, status: 204);
    }
    if (path.endsWith('/auth/v1/signup')) {
      signupRequests.add(req);
      if (signInAnonymouslyError != null) {
        return _json({'msg': 'Anonymous sign-ins are disabled'}, status: 422);
      }
      return _json(_sessionJson(anonymous: true));
    }
    if (path.endsWith('/auth/v1/user')) {
      userRequests.add(req);
      // beginEmailLink's updateUser(email:) call lands here to set a
      // *pending* email — is_anonymous doesn't flip to false until the OTP
      // is actually confirmed below, matching real GoTrue behaviour. Now
      // that SupportAccountLinkCard reacts to onAuthStateChange directly
      // (review round 4, browser-redirect providers), returning
      // anonymous: false here too would make it jump straight to "linked"
      // before the rider ever sees the code field.
      return _json(_sessionJson(anonymous: true, email: 'rider@example.com')['user'] as Map<String, dynamic>);
    }
    if (path.endsWith('/auth/v1/verify')) {
      verifyRequests.add(req);
      return _json(_sessionJson(anonymous: false, email: 'rider@example.com'));
    }
    return _json(<String, dynamic>{}, status: 404);
  }

  Map<String, dynamic> _chatJson() => {
    'id': 'chat-1',
    'user_id': 'user-id',
    'created_at': '2026-08-24T00:00:00Z',
    'last_message_at': null,
    'last_seen_at': null,
  };

  http.StreamedResponse _json(dynamic body, {int status = 200}) {
    return http.StreamedResponse(
      Stream.value(utf8.encode(jsonEncode(body))),
      status,
      headers: const {'content-type': 'application/json'},
    );
  }
}

/// A Supabase auth session/user payload. `access_token` is not a real JWT, so
/// gotrue's expiry check (which parses the JWT `exp` claim) falls back to
/// "never expires" — exactly what a short-lived test needs.
Map<String, dynamic> _sessionJson({required bool anonymous, String? email}) {
  return {
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
      'is_anonymous': anonymous,
      if (email != null) 'email': email,
    },
  };
}

Future<void> main() async {
  TestWidgetsFlutterBinding.ensureInitialized();
  final l10n = await AppLocalizations.load(const Locale('en'));

  late _FakeSupportChatHttp fakeHttp;
  late SupabaseClient client;
  late SupportChatService chatService;
  late FeedbackSubmissionService accountService;

  Widget app({String? pinnedContext, String? pinnedContextLabel}) {
    return ShadcnApp(
      debugShowCheckedModeBanner: false,
      localizationsDelegates: const [AppLocalizations.delegate],
      supportedLocales: AppLocalizations.delegate.supportedLocales,
      home: Scaffold(
        child: SupportChatPage(
          telemetryBuilder: () async => const TelemetrySnapshot(freetext: 'test'),
          service: chatService,
          accountService: accountService,
          pinnedContext: pinnedContext,
          pinnedContextLabel: pinnedContextLabel,
        ),
      ),
    );
  }

  Future<void> selectSomethingElseAndContinue(WidgetTester tester) async {
    await tester.tap(find.byType(Select<IntakeCategory>));
    await tester.pumpAndSettle();
    await tester.tap(find.text(l10n.supportIntakeCategorySomethingElse).last);
    await tester.pumpAndSettle();
    await tester.tap(find.text(l10n.supportIntakeContinue));
    await tester.pumpAndSettle();
  }

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    core.settings.prefs = await SharedPreferences.getInstance();
    core.actionHandler = StubActions();

    fakeHttp = _FakeSupportChatHttp();
    client = SupabaseClient(
      'https://example.test',
      'test-anon-key',
      httpClient: fakeHttp,
      authOptions: const AuthClientOptions(autoRefreshToken: false),
      isolate: _SynchronousJsonIsolate(),
    );
    chatService = SupportChatService(supabase: client, httpClient: fakeHttp);
    accountService = FeedbackSubmissionService(client: client);
  });

  tearDown(() => client.dispose());

  group('no sign-in gate', () {
    testWidgets('the intake form is usable immediately with no session', (tester) async {
      expect(client.auth.currentSession, isNull);

      await tester.pumpWidget(app());
      await tester.pump();

      // The old gate's copy is gone entirely...
      expect(find.text('Sign in to chat with support'), findsNothing);
      // ...and the real intake form is right there instead, no gate in the way.
      expect(find.text(l10n.supportIntakeTitle), findsOneWidget);
    });
  });

  group('sending with no session', () {
    testWidgets('signs in anonymously first, then opens the chat and sends', (tester) async {
      expect(client.auth.currentSession, isNull);
      await tester.pumpWidget(app());
      await tester.pump();

      await selectSomethingElseAndContinue(tester);
      await tester.enterText(find.byType(TextArea), 'Virtual shifting stops after ten minutes');
      await tester.pump();
      await tester.tap(find.byIcon(LucideIcons.send));
      await tester.pumpAndSettle();

      expect(fakeHttp.signupRequests, hasLength(1));
      expect(fakeHttp.openChatRequests, hasLength(1));
      expect(fakeHttp.sendMessageRequests, hasLength(1));
      expect(client.auth.currentSession, isNotNull);
      expect(client.auth.currentSession!.user.isAnonymous, isTrue);
      expect(find.text('Virtual shifting stops after ten minutes'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('a disabled anonymous sign-in surfaces a retryable error and keeps the typed text', (tester) async {
      fakeHttp.signInAnonymouslyError = 'disabled';
      await tester.pumpWidget(app());
      await tester.pump();

      await selectSomethingElseAndContinue(tester);
      await tester.enterText(find.byType(TextArea), 'please help');
      await tester.pump();
      await tester.tap(find.byIcon(LucideIcons.send));
      await tester.pumpAndSettle();

      expect(fakeHttp.openChatRequests, isEmpty, reason: 'never reaches the backend without a session');
      final field = tester.widget<TextArea>(find.byType(TextArea));
      expect(field.controller!.text, 'please help', reason: 'composer keeps the typed text so the rider can retry');
      expect(tester.takeException(), isNull);

      // The recorded sign-in failure is persisted with a debug text whose
      // diagnostics gather never completes under the test clock. Let its one
      // 6 s timeout fire so no timer is still pending when the test ends.
      await tester.pump(const Duration(seconds: 7));
    });
  });

  // The fix for the 135-of-444-empty-rows problem: opening the page must
  // never create a chat by itself. Only a rider who actually sends a message
  // should get a row in support_chats.
  group('lazy chat creation', () {
    testWidgets('a session with no existing chat is not enough to create one; only sending a message does', (
      tester,
    ) async {
      fakeHttp.chatAlreadyExists = false;
      await client.auth.recoverSession(jsonEncode(_sessionJson(anonymous: false, email: 'rider@example.com')));

      await tester.pumpWidget(app());
      await tester.pumpAndSettle();

      // Bootstrap used the get-only function and found nothing to load — it
      // must not have fallen back to creating a chat just to view the page.
      expect(fakeHttp.getChatRequests, hasLength(1));
      expect(fakeHttp.openChatRequests, isEmpty, reason: 'opening the page alone must never create a chat row');
      expect(core.settings.getSupportChatActive(), isFalse);

      await selectSomethingElseAndContinue(tester);
      await tester.enterText(find.byType(TextArea), 'trainer will not pair');
      await tester.pump();
      await tester.tap(find.byIcon(LucideIcons.send));
      await tester.pumpAndSettle();

      // The first message is what finally creates the chat — exactly once.
      expect(fakeHttp.openChatRequests, hasLength(1));
      expect(fakeHttp.sendMessageRequests, hasLength(1));
      expect(core.settings.getSupportChatActive(), isTrue);
      expect(tester.takeException(), isNull);
    });

    testWidgets('a session with an existing chat loads it via the get function alone', (tester) async {
      await client.auth.recoverSession(jsonEncode(_sessionJson(anonymous: false, email: 'rider@example.com')));

      await tester.pumpWidget(app());
      await tester.pumpAndSettle();

      expect(fakeHttp.getChatRequests, hasLength(1));
      expect(fakeHttp.openChatRequests, isEmpty, reason: 'a chat that already exists is loaded, never re-created');
      expect(find.byKey(const ValueKey('support-overflow-menu')), findsOneWidget);
      expect(core.settings.getSupportChatActive(), isTrue);
    });
  });

  group('post-send account-link prompt', () {
    testWidgets('appears after a successful send while anonymous', (tester) async {
      await tester.pumpWidget(app());
      await tester.pump();
      await selectSomethingElseAndContinue(tester);

      expect(find.byKey(const ValueKey('support-account-link-card')), findsNothing);

      await tester.enterText(find.byType(TextArea), 'help please');
      await tester.pump();
      await tester.tap(find.byIcon(LucideIcons.send));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('support-account-link-card')), findsOneWidget);
      expect(find.text(l10n.supportAccountLinkTitle), findsOneWidget);
    });

    testWidgets('does not appear when the sender is already fully signed in', (tester) async {
      await client.auth.recoverSession(jsonEncode(_sessionJson(anonymous: false, email: 'rider@example.com')));
      await tester.pumpWidget(app());
      // Already-signed-in riders bootstrap eagerly (openChat + fetchChat).
      await tester.pumpAndSettle();

      await selectSomethingElseAndContinue(tester);
      await tester.enterText(find.byType(TextArea), 'hello');
      await tester.pump();
      await tester.tap(find.byIcon(LucideIcons.send));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('support-account-link-card')), findsNothing);
      expect(fakeHttp.signupRequests, isEmpty);
    });

    testWidgets('email -> code -> linked updates the header to Signed in', (tester) async {
      await tester.pumpWidget(app());
      await tester.pump();
      await selectSomethingElseAndContinue(tester);
      await tester.enterText(find.byType(TextArea), 'help please');
      await tester.pump();
      await tester.tap(find.byIcon(LucideIcons.send));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('support-account-link-card')), findsOneWidget);

      await tester.enterText(find.byKey(const ValueKey('support-account-email-field')), 'rider@example.com');
      await tester.tap(find.byKey(const ValueKey('support-account-email-send')));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('support-account-code-field')), findsOneWidget);

      await tester.enterText(find.byKey(const ValueKey('support-account-code-field')), '123456');
      await tester.tap(find.byKey(const ValueKey('support-account-code-verify')));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('support-account-linked')), findsOneWidget);
      expect(find.text(l10n.supportAccountStatusSignedIn), findsOneWidget);
      expect(find.byKey(const ValueKey('support-header-sign-in')), findsNothing);
    });
  });

  // The self-test pages hand their result to the chat as `pinnedContext`
  // rather than `initialText`: it rides along with the first message, but the
  // rider has to say what is wrong before they can send it.
  group('pinnedContext', () {
    testWidgets('is forwarded to the composer and sent below the description', (tester) async {
      await tester.pumpWidget(
        app(pinnedContext: 'Network self-test: NETWORK PASS', pinnedContextLabel: l10n.supportPinnedNetworkTest),
      );
      await tester.pump();
      await selectSomethingElseAndContinue(tester);

      expect(find.text(l10n.supportPinnedContextChip(l10n.supportPinnedNetworkTest)), findsOneWidget);
      // Not prefilled: the composer starts empty, with the describe-the-problem placeholder.
      expect(tester.widget<TextArea>(find.byType(TextArea)).controller!.text, isEmpty);
      expect(find.text(l10n.supportDescribeProblemPlaceholder), findsOneWidget);

      await tester.enterText(find.byType(TextArea), 'MyWhoosh does not find BikeControl');
      await tester.pump();
      await tester.tap(find.byIcon(LucideIcons.send));
      await tester.pumpAndSettle();

      expect(fakeHttp.sendMessageRequests, hasLength(1));
      final sentBody = jsonDecode(fakeHttp.sendMessageRequests.single.body) as Map<String, dynamic>;
      expect(sentBody['body'], 'MyWhoosh does not find BikeControl\n\nNetwork self-test: NETWORK PASS');
      expect(tester.takeException(), isNull);
    });
  });

  group('header account status', () {
    testWidgets('shows Anonymous - not signed in and a Sign In button with no session', (tester) async {
      await tester.pumpWidget(app());
      await tester.pump();

      expect(find.text(l10n.supportAccountStatusAnonymous), findsOneWidget);
      expect(find.byKey(const ValueKey('support-header-sign-in')), findsOneWidget);
    });

    testWidgets('shows Signed in with no button for an already-linked session', (tester) async {
      await client.auth.recoverSession(jsonEncode(_sessionJson(anonymous: false, email: 'rider@example.com')));
      await tester.pumpWidget(app());
      await tester.pumpAndSettle();

      expect(find.text(l10n.supportAccountStatusSignedIn), findsOneWidget);
      expect(find.byKey(const ValueKey('support-header-sign-in')), findsNothing);
    });

    testWidgets('the header Sign In button reveals the same account-link card', (tester) async {
      await tester.pumpWidget(app());
      await tester.pump();

      expect(find.byKey(const ValueKey('support-account-link-card')), findsNothing);

      await tester.tap(find.byKey(const ValueKey('support-header-sign-in')));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('support-account-link-card')), findsOneWidget);
    });
  });

  // GDPR self-serve erasure: the rider can delete their support data (and,
  // signed in, their whole account) from the chat itself. Ties to the "I never
  // agreed to this / I want it gone" support ticket.
  group('data deletion', () {
    testWidgets('no overflow menu until a chat exists', (tester) async {
      await tester.pumpWidget(app());
      await tester.pump();

      expect(find.byKey(const ValueKey('support-overflow-menu')), findsNothing);
    });

    testWidgets('delete conversation: menu -> confirm -> calls delete with scope=conversation', (tester) async {
      await client.auth.recoverSession(jsonEncode(_sessionJson(anonymous: false, email: 'rider@example.com')));
      await tester.pumpWidget(app());
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('support-overflow-menu')));
      await tester.pumpAndSettle();
      await tester.tap(find.text(l10n.supportDeleteConversation));
      await tester.pumpAndSettle();

      // A destructive confirm must stand between the tap and the deletion.
      expect(find.text(l10n.supportDeleteConversationTitle), findsOneWidget);
      await tester.tap(find.text(l10n.delete));
      await tester.pumpAndSettle();

      expect(fakeHttp.deleteRequests, hasLength(1));
      expect(jsonDecode(fakeHttp.deleteRequests.single.body)['scope'], 'conversation');
      expect(tester.takeException(), isNull);
    });

    testWidgets('cancelling the confirm deletes nothing', (tester) async {
      await client.auth.recoverSession(jsonEncode(_sessionJson(anonymous: false, email: 'rider@example.com')));
      await tester.pumpWidget(app());
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('support-overflow-menu')));
      await tester.pumpAndSettle();
      await tester.tap(find.text(l10n.supportDeleteConversation));
      await tester.pumpAndSettle();
      await tester.tap(find.text(l10n.cancel));
      await tester.pumpAndSettle();

      expect(fakeHttp.deleteRequests, isEmpty);
    });

    testWidgets('delete account: menu -> confirm -> scope=account and the session is cleared', (tester) async {
      await client.auth.recoverSession(jsonEncode(_sessionJson(anonymous: false, email: 'rider@example.com')));
      await tester.pumpWidget(app());
      await tester.pumpAndSettle();
      expect(client.auth.currentSession, isNotNull);

      await tester.tap(find.byKey(const ValueKey('support-overflow-menu')));
      await tester.pumpAndSettle();
      await tester.tap(find.text(l10n.supportDeleteAccount));
      await tester.pumpAndSettle();

      expect(find.text(l10n.supportDeleteAccountTitle), findsOneWidget);
      await tester.tap(find.text(l10n.delete));
      await tester.pumpAndSettle();

      expect(jsonDecode(fakeHttp.deleteRequests.single.body)['scope'], 'account');
      expect(client.auth.currentSession, isNull, reason: 'account deletion signs the device out');
      expect(tester.takeException(), isNull);
    });
  });
}
