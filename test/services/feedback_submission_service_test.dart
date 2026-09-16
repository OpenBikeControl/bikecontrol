// FeedbackSubmissionService talks to a real SupabaseClient (auth + edge
// functions), so rather than inventing a bespoke interface for it, these
// tests wire that real client to a fake HTTP transport — the same "swap the
// transport, keep the real types" approach package:http's testing.dart
// documents. That lets the service exercise its actual session logic
// (currentSession / signInAnonymously / recoverSession) without a network.
import 'dart:convert';

import 'package:bike_control/services/feedback_submission_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher_platform_interface/link.dart';
import 'package:url_launcher_platform_interface/url_launcher_platform_interface.dart';

/// Fake transport standing in for Supabase's Auth + Functions REST APIs.
/// Records every request it sees and replays canned responses, keyed by URL
/// path, for the handful of endpoints [FeedbackSubmissionService] can reach.
class _FakeSupabaseHttp extends http.BaseClient {
  final List<http.Request> signupRequests = [];
  final List<http.Request> functionRequests = [];
  final List<http.Request> userRequests = [];
  final List<http.Request> verifyRequests = [];
  final List<http.Request> idTokenRequests = [];
  final List<http.Request> authorizeRequests = [];

  Object? signInAnonymouslyError;
  int functionStatus = 200;
  Map<String, dynamic> functionResponseBody = {'id': 'feedback-1'};
  bool idTokenLinkError = false;
  bool authorizeError = false;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final req = request as http.Request;
    final path = request.url.path;

    if (path.contains('/functions/v1/')) {
      functionRequests.add(req);
      return _json(functionResponseBody, status: functionStatus);
    }
    if (path.endsWith('/auth/v1/signup')) {
      signupRequests.add(req);
      if (signInAnonymouslyError != null) {
        return _json({'msg': 'Anonymous sign-ins are disabled'}, status: 422);
      }
      return _json(_sessionJson(anonymous: true));
    }
    // Must come before the plain '/auth/v1/user' check below — this is the
    // identity-*linking* authorize endpoint (GoTrue's `getLinkIdentityUrl`),
    // a different path from both '/auth/v1/user' and the plain sign-in
    // '/auth/v1/authorize'.
    if (path.contains('/user/identities/authorize')) {
      authorizeRequests.add(req);
      if (authorizeError) {
        return _json({'msg': 'Unable to start the OAuth flow'}, status: 400);
      }
      return _json({'url': 'https://example.test/oauth-redirect'});
    }
    if (path.endsWith('/auth/v1/user')) {
      userRequests.add(req);
      return _json(_sessionJson(anonymous: false, email: 'rider@example.com')['user'] as Map<String, dynamic>);
    }
    if (path.endsWith('/auth/v1/verify')) {
      verifyRequests.add(req);
      return _json(_sessionJson(anonymous: false, email: 'rider@example.com'));
    }
    if (path.endsWith('/auth/v1/token') && request.url.queryParameters['grant_type'] == 'id_token') {
      idTokenRequests.add(req);
      if (idTokenLinkError) {
        return _json({
          'code': 422,
          'error_code': 'identity_already_exists',
          'msg': 'Identity is already linked to another user',
        }, status: 422);
      }
      // Same user id as every other fixture here — a real link response
      // keeps the id unchanged; only `is_anonymous`/`email` flip.
      return _json(_sessionJson(anonymous: false, email: 'rider@gmail.com'));
    }
    return _json(<String, dynamic>{}, status: 404);
  }

  http.StreamedResponse _json(Map<String, dynamic> body, {int status = 200}) {
    return http.StreamedResponse(
      Stream.value(utf8.encode(jsonEncode(body))),
      status,
      headers: const {'content-type': 'application/json'},
    );
  }
}

/// Minimal in-memory PKCE code-verifier store. GoTrue's browser-redirect
/// OAuth calls (`linkIdentity`/`signInWithOAuth`) need *some*
/// `GotrueAsyncStorage` to stash the code verifier before the authorize
/// round trip — real app code gets one from `Supabase.initialize`'s Flutter
/// bootstrap; a bare `SupabaseClient` in a test needs its own.
class _InMemoryAsyncStorage extends GotrueAsyncStorage {
  final _store = <String, String>{};

  @override
  Future<String?> getItem({required String key}) async => _store[key];

  @override
  Future<void> setItem({required String key, required String value}) async {
    _store[key] = value;
  }

  @override
  Future<void> removeItem({required String key}) async {
    _store.remove(key);
  }
}

/// Records every URL passed to `launchUrl` instead of hitting a real
/// platform channel, so `linkOAuthIdentity`'s browser hand-off is
/// assertable — same fake as help_center_sections_test.dart's
/// `_FakeUrlLauncher`, redefined locally since that one is private to its
/// own file.
class _FakeUrlLauncher extends UrlLauncherPlatform {
  final List<String> launchedUrls = [];

  @override
  LinkDelegate? get linkDelegate => null;

  @override
  Future<bool> canLaunch(String url) async => true;

  @override
  Future<bool> launchUrl(String url, LaunchOptions options) async {
    launchedUrls.add(url);
    return true;
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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  PackageInfo.setMockInitialValues(
    appName: 'BikeControl',
    packageName: 'de.jonasbark.swiftcontrol',
    version: '6.4.0',
    buildNumber: '1',
    buildSignature: '',
  );

  late _FakeSupabaseHttp fakeHttp;
  late SupabaseClient client;
  late FeedbackSubmissionService service;

  setUp(() {
    fakeHttp = _FakeSupabaseHttp();
    client = SupabaseClient(
      'https://example.test',
      'test-anon-key',
      httpClient: fakeHttp,
      // pkceAsyncStorage: only the OAuth-redirect linking tests below ever
      // touch the PKCE code-verifier path, but every other test's fixture
      // session already has a non-expiring access_token, so it's inert for
      // them — simplest to supply once here rather than per-group.
      authOptions: AuthClientOptions(autoRefreshToken: false, pkceAsyncStorage: _InMemoryAsyncStorage()),
    );
    service = FeedbackSubmissionService(client: client);
  });

  tearDown(() => client.dispose());

  group('submit', () {
    test('with an existing session invokes submit-feedback with the full payload, no anonymous sign-in', () async {
      await client.auth.recoverSession(jsonEncode(_sessionJson(anonymous: false, email: 'rider@example.com')));

      await service.submit(sentiment: FeedbackSentiment.up, kind: FeedbackKind.suggestion, body: 'Love the app!');

      expect(fakeHttp.signupRequests, isEmpty);
      expect(fakeHttp.functionRequests, hasLength(1));

      final request = fakeHttp.functionRequests.single;
      expect(request.url.path, endsWith('/functions/v1/submit-feedback'));
      final payload = jsonDecode(request.body) as Map<String, dynamic>;
      expect(payload['sentiment'], 'up');
      expect(payload['kind'], 'suggestion');
      expect(payload['body'], 'Love the app!');
      expect(payload['platform'], isNotEmpty);
      expect(payload['locale'], isNotEmpty);
      expect(payload['app_version'], '6.4.0');
    });

    test('without a session signs in anonymously first, then submits', () async {
      expect(client.auth.currentSession, isNull);

      await service.submit(sentiment: FeedbackSentiment.down, kind: FeedbackKind.complaint, body: 'Bug report');

      expect(fakeHttp.signupRequests, hasLength(1));
      expect(fakeHttp.functionRequests, hasLength(1));
      expect(client.auth.currentSession, isNotNull);
      expect(client.auth.currentSession!.user.isAnonymous, isTrue);
    });

    test('a disabled anonymous sign-in is wrapped in FeedbackSubmissionException', () async {
      fakeHttp.signInAnonymouslyError = 'disabled';

      await expectLater(
        service.submit(sentiment: FeedbackSentiment.up, kind: FeedbackKind.suggestion, body: 'test'),
        throwsA(isA<FeedbackSubmissionException>()),
      );
      expect(fakeHttp.functionRequests, isEmpty, reason: 'never reaches the edge function without a session');
    });

    test('an edge-function error is wrapped in FeedbackSubmissionException', () async {
      await client.auth.recoverSession(jsonEncode(_sessionJson(anonymous: false, email: 'rider@example.com')));
      fakeHttp.functionStatus = 500;
      fakeHttp.functionResponseBody = {'error': 'boom'};

      await expectLater(
        service.submit(sentiment: FeedbackSentiment.up, kind: FeedbackKind.suggestion, body: 'test'),
        throwsA(isA<FeedbackSubmissionException>()),
      );
    });
  });

  group('isAnonymous', () {
    test('is true with no session at all', () {
      expect(client.auth.currentSession, isNull);
      expect(service.isAnonymous, isTrue);
    });

    test('is true for a session whose user is anonymous', () async {
      await client.auth.recoverSession(jsonEncode(_sessionJson(anonymous: true)));

      expect(service.isAnonymous, isTrue);
    });

    test('is false for a session with a confirmed email', () async {
      await client.auth.recoverSession(jsonEncode(_sessionJson(anonymous: false, email: 'rider@example.com')));

      expect(service.isAnonymous, isFalse);
    });
  });

  group('email link-up', () {
    setUp(() async {
      await client.auth.recoverSession(jsonEncode(_sessionJson(anonymous: true)));
    });

    test('beginEmailLink asks Supabase to start an email-change OTP', () async {
      await service.beginEmailLink('rider@example.com');

      expect(fakeHttp.userRequests, hasLength(1));
      final payload = jsonDecode(fakeHttp.userRequests.single.body) as Map<String, dynamic>;
      expect(payload['email'], 'rider@example.com');
    });

    test('confirmEmailLink verifies the OTP against the emailChange type', () async {
      await service.confirmEmailLink(email: 'rider@example.com', token: '123456');

      expect(fakeHttp.verifyRequests, hasLength(1));
      final payload = jsonDecode(fakeHttp.verifyRequests.single.body) as Map<String, dynamic>;
      expect(payload['email'], 'rider@example.com');
      expect(payload['token'], '123456');
      expect(payload['type'], 'email_change');
    });

    test('a rejected code is wrapped in FeedbackSubmissionException', () async {
      final erroringClient = SupabaseClient(
        'https://example.test',
        'test-anon-key',
        httpClient: _ErroringVerifyHttp(),
        authOptions: const AuthClientOptions(autoRefreshToken: false),
      );
      await erroringClient.auth.recoverSession(jsonEncode(_sessionJson(anonymous: true)));
      final erroringService = FeedbackSubmissionService(client: erroringClient);

      await expectLater(
        erroringService.confirmEmailLink(email: 'rider@example.com', token: '000000'),
        throwsA(isA<FeedbackSubmissionException>()),
      );

      await erroringClient.dispose();
    });
  });

  group('email link-up with no prior session', () {
    test('beginEmailLink creates an anonymous session first', () async {
      // Covers the chat's header "Sign In" button, which can be tapped
      // before any message — and therefore any session — exists yet.
      // Without this, `updateUser` would have no session to act on.
      expect(client.auth.currentSession, isNull);

      await service.beginEmailLink('rider@example.com');

      expect(fakeHttp.signupRequests, hasLength(1));
      expect(fakeHttp.userRequests, hasLength(1));
      expect(client.auth.currentSession, isNotNull);
    });
  });

  group('social identity linking', () {
    setUp(() async {
      await client.auth.recoverSession(jsonEncode(_sessionJson(anonymous: true)));
    });

    test('linkGoogleIdentity calls the id-token grant with link_identity — same user id preserved', () async {
      final userIdBeforeLink = client.auth.currentSession!.user.id;

      await service.linkGoogleIdentity(idToken: 'fake-google-id-token', accessToken: 'fake-access-token');

      expect(fakeHttp.idTokenRequests, hasLength(1));
      final request = fakeHttp.idTokenRequests.single;
      expect(request.url.queryParameters['grant_type'], 'id_token');
      final payload = jsonDecode(request.body) as Map<String, dynamic>;
      expect(payload['provider'], 'google');
      expect(payload['id_token'], 'fake-google-id-token');
      expect(payload['access_token'], 'fake-access-token');
      expect(payload['link_identity'], isTrue, reason: 'must link onto the current user, not sign in as a new one');
      expect(
        client.auth.currentSession!.user.id,
        userIdBeforeLink,
        reason: 'linking preserves the session/user id so anything already written under it stays attached',
      );
      expect(client.auth.currentSession!.user.isAnonymous, isFalse);
    });

    test('linkAppleIdentity calls the id-token grant with the Apple provider and nonce', () async {
      final userIdBeforeLink = client.auth.currentSession!.user.id;

      await service.linkAppleIdentity(idToken: 'fake-apple-id-token', nonce: 'raw-nonce');

      expect(fakeHttp.idTokenRequests, hasLength(1));
      final payload = jsonDecode(fakeHttp.idTokenRequests.single.body) as Map<String, dynamic>;
      expect(payload['provider'], 'apple');
      expect(payload['id_token'], 'fake-apple-id-token');
      expect(payload['nonce'], 'raw-nonce');
      expect(payload['link_identity'], isTrue);
      expect(client.auth.currentSession!.user.id, userIdBeforeLink);
    });

    test('linkGoogleIdentity with no prior session creates an anonymous one first', () async {
      final noSessionClient = SupabaseClient(
        'https://example.test',
        'test-anon-key',
        httpClient: fakeHttp,
        authOptions: const AuthClientOptions(autoRefreshToken: false),
      );
      final noSessionService = FeedbackSubmissionService(client: noSessionClient);
      expect(noSessionClient.auth.currentSession, isNull);

      await noSessionService.linkGoogleIdentity(idToken: 'fake-google-id-token');

      expect(fakeHttp.signupRequests, hasLength(1));
      expect(fakeHttp.idTokenRequests, hasLength(1));

      await noSessionClient.dispose();
    });

    test('a rejected link is wrapped in FeedbackSubmissionException, not swallowed', () async {
      fakeHttp.idTokenLinkError = true;

      await expectLater(
        service.linkGoogleIdentity(idToken: 'fake-google-id-token'),
        throwsA(isA<FeedbackSubmissionException>()),
      );
    });

    test('an identity owned by another user surfaces as IdentityAlreadyLinkedException', () async {
      fakeHttp.idTokenLinkError = true;

      await expectLater(
        service.linkAppleIdentity(idToken: 'fake-apple-id-token', nonce: 'raw-nonce'),
        throwsA(isA<IdentityAlreadyLinkedException>()),
      );
      await expectLater(
        service.linkGoogleIdentity(idToken: 'fake-google-id-token'),
        throwsA(isA<IdentityAlreadyLinkedException>()),
      );
    });
  });

  group('linkOAuthIdentity (browser-redirect linking — GitHub/Facebook, and Google/Apple with no native path)', () {
    late _FakeUrlLauncher fakeLauncher;

    setUp(() {
      fakeLauncher = _FakeUrlLauncher();
      final previous = UrlLauncherPlatform.instance;
      UrlLauncherPlatform.instance = fakeLauncher;
      addTearDown(() => UrlLauncherPlatform.instance = previous);
    });

    test(
      'hits the identity-linking authorize endpoint — not the plain sign-in one — carrying the session JWT, '
      'then opens the browser',
      () async {
        await client.auth.recoverSession(jsonEncode(_sessionJson(anonymous: true)));
        final userIdBeforeLink = client.auth.currentSession!.user.id;

        await service.linkOAuthIdentity(OAuthProvider.github);

        expect(fakeHttp.authorizeRequests, hasLength(1));
        final request = fakeHttp.authorizeRequests.single;
        expect(
          request.url.path,
          endsWith('/user/identities/authorize'),
          reason: 'the identity-linking endpoint, not /authorize — that one would sign in as a new user instead',
        );
        expect(request.url.queryParameters['provider'], 'github');
        expect(
          request.headers['Authorization'],
          'Bearer test-access-token',
          reason: 'the request is authenticated as the current session, not anonymous/unauthenticated',
        );
        expect(fakeHttp.idTokenRequests, isEmpty, reason: 'GitHub has no native id-token path');
        expect(fakeLauncher.launchedUrls, ['https://example.test/oauth-redirect']);
        expect(
          client.auth.currentSession!.user.id,
          userIdBeforeLink,
          reason: 'linkIdentity never swaps the session — the id only ever changes if a *different* flow signs in',
        );
      },
    );

    test('with no prior session, creates an anonymous one first', () async {
      final noSessionClient = SupabaseClient(
        'https://example.test',
        'test-anon-key',
        httpClient: fakeHttp,
        authOptions: AuthClientOptions(autoRefreshToken: false, pkceAsyncStorage: _InMemoryAsyncStorage()),
      );
      final noSessionService = FeedbackSubmissionService(client: noSessionClient);
      expect(noSessionClient.auth.currentSession, isNull);

      await noSessionService.linkOAuthIdentity(OAuthProvider.facebook);

      expect(fakeHttp.signupRequests, hasLength(1));
      expect(fakeHttp.authorizeRequests, hasLength(1));
      expect(noSessionClient.auth.currentSession, isNotNull);

      await noSessionClient.dispose();
    });

    test('a rejected authorize request is wrapped in FeedbackSubmissionException, never reaching the browser', () async {
      await client.auth.recoverSession(jsonEncode(_sessionJson(anonymous: true)));
      fakeHttp.authorizeError = true;

      await expectLater(
        service.linkOAuthIdentity(OAuthProvider.github),
        throwsA(isA<FeedbackSubmissionException>()),
      );
      expect(fakeLauncher.launchedUrls, isEmpty);
    });
  });
}

/// Minimal transport used only to exercise the verifyOTP failure path.
class _ErroringVerifyHttp extends http.BaseClient {
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    return http.StreamedResponse(
      Stream.value(utf8.encode(jsonEncode({'msg': 'Token has expired or is invalid'}))),
      403,
      headers: const {'content-type': 'application/json'},
    );
  }
}
