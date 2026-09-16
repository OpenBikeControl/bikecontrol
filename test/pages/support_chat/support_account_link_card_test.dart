// Usage-fix round 3 (Jonas): the chat's account-link card offered only
// email + OTP; then Google/Apple, native-id-token only, gated to the
// platforms with a native SDK. This round (review round 4): no more
// gating — all four of LoginPage's providers (Google, Apple, GitHub,
// Facebook) render on every platform, each one picking the native id-token
// path where it exists here and the browser-redirect link everywhere else.
// `SupportAccountLinkCard` talks to a real `SupabaseClient` through
// `FeedbackSubmissionService` — same "swap the transport, keep the real
// types" approach test/services/feedback_submission_service_test.dart
// already uses — so these tests exercise the actual request shapes, not a
// mock: the id-token grant for the native path, and the real
// `getLinkIdentityUrl` + `launchUrl` round trip (launchUrl intercepted via
// `UrlLauncherPlatform`, never a real platform channel) for the redirect
// path.
//
// The critical thing every "linking" test pins, on every path: linking (not
// signing in) keeps the session's user id unchanged, so a chat already
// written under the anonymous session doesn't get orphaned by adding an
// identity to it. See support_account_link_card.dart's file header for the
// full investigation.
//
// Platform gating for which *mechanism* a provider uses (native vs.
// browser-redirect) is driven by `defaultTargetPlatform` rather than
// `dart:io`'s `Platform`, specifically so `debugDefaultTargetPlatformOverride`
// can force it here regardless of which OS actually runs the test — see
// social_sign_in.dart. It no longer gates which *buttons* render at all.
import 'dart:convert';

import 'package:bike_control/gen/l10n.dart';
import 'package:bike_control/main.dart' show installLoggerErrorListener;
import 'package:bike_control/pages/support_chat/widgets/support_account_link_card.dart';
import 'package:bike_control/services/feedback_submission_service.dart';
import 'package:bike_control/utils/auth/social_sign_in.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:prop/utils/shared.dart' show Logger;
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:sign_in_button/sign_in_button.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher_platform_interface/link.dart';
import 'package:url_launcher_platform_interface/url_launcher_platform_interface.dart';

/// Fake transport for the subset of Supabase's Auth API
/// [FeedbackSubmissionService] can reach: the id-token grant
/// `linkIdentityWithIdToken`/`signInWithIdToken` both use
/// (`/auth/v1/token?grant_type=id_token`), the identity-*linking* authorize
/// endpoint `linkIdentity` uses (`/auth/v1/user/identities/authorize`), and
/// `/auth/v1/user`, used here only to simulate a browser-redirect link's
/// deep-link callback landing later (see `_simulateRedirectCompletion`).
class _FakeAuthHttp extends http.BaseClient {
  final List<http.Request> signupRequests = [];
  final List<http.Request> idTokenRequests = [];
  final List<http.Request> authorizeRequests = [];
  final List<http.Request> userUpdateRequests = [];

  bool authorizeError = false;
  bool idTokenAlreadyLinked = false;

  /// When true, `updateUser(email:)` fails the way GoTrue does for an address
  /// that already belongs to another account.
  bool emailTaken = false;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final req = request as http.Request;
    final path = request.url.path;

    if (path.endsWith('/auth/v1/signup')) {
      signupRequests.add(req);
      return _json(_sessionJson(anonymous: true));
    }
    if (path.endsWith('/auth/v1/token') && request.url.queryParameters['grant_type'] == 'id_token') {
      idTokenRequests.add(req);
      if (idTokenAlreadyLinked) {
        return _json({
          'code': 422,
          'error_code': 'identity_already_exists',
          'msg': 'Identity is already linked to another user',
        }, status: 422);
      }
      // Same user id as every other fixture here — linking must not swap it
      // out for a different one (that would be the orphaning bug).
      return _json(_sessionJson(anonymous: false, email: 'rider@gmail.com'));
    }
    // Must come before the plain '/auth/v1/user' branch below — the
    // identity-linking authorize endpoint, a different path from it.
    if (path.contains('/user/identities/authorize')) {
      authorizeRequests.add(req);
      if (authorizeError) {
        return _json({'msg': 'Unable to start the OAuth flow'}, status: 400);
      }
      return _json({'url': 'https://example.test/oauth-redirect'});
    }
    if (path.endsWith('/auth/v1/user')) {
      userUpdateRequests.add(req);
      // beginEmailLink's real updateUser(email:) call also lands here, and
      // in reality that alone doesn't flip is_anonymous (only confirming
      // the OTP code does) — so only the deep-link-completion simulation's
      // own marker (see simulateRedirectCompletion) flips it here too.
      // Same user id as every other fixture either way — this stands in
      // for the real exchangeCodeForSession the app's deep-link handler
      // would run once the browser-redirect flow's OAuth tab actually
      // completes; what matters for these tests is only that it flips
      // is_anonymous while keeping the id, and fires a real
      // onAuthStateChange event, both of which a real updateUser call does
      // too.
      final body = jsonDecode(req.body) as Map<String, dynamic>;
      if (emailTaken && body['email'] != null) {
        return http.StreamedResponse(
          Stream.value(
            utf8.encode(
              jsonEncode({'code': 'email_exists', 'message': 'Email address already registered by another user'}),
            ),
          ),
          422,
          headers: const {'content-type': 'application/json', 'x-supabase-api-version': '2024-01-01'},
        );
      }
      final isRedirectCompletion = (body['data'] as Map<String, dynamic>?)?['linked_via'] == 'oauth-redirect';
      return _json(
        _sessionJson(
              anonymous: !isRedirectCompletion,
              email: isRedirectCompletion ? 'rider@github.example' : null,
            )['user']
            as Map<String, dynamic>,
      );
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

/// Minimal in-memory PKCE code-verifier store — GoTrue's browser-redirect
/// `linkIdentity` needs *some* `GotrueAsyncStorage` to stash the code
/// verifier before its authorize round trip; a bare `SupabaseClient` in a
/// test needs its own rather than the one `Supabase.initialize` sets up in
/// the real app.
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
/// platform channel, so the browser-redirect link's hand-off is
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

/// Runs [body] with `debugDefaultTargetPlatformOverride` set to [platform],
/// resetting it synchronously before returning — even on failure — so
/// Flutter's post-test invariant check (`debugAssertAllFoundationVarsUnset`,
/// which runs *inside* `testWidgets`'s own body, before `tearDown`/
/// `addTearDown` hooks ever fire) sees it unset again. Mirrors the pattern
/// Flutter's own test suite uses for the same variable, e.g.
/// `flutter/test/material/expansion_tile_test.dart`.
Future<void> withPlatform(TargetPlatform platform, Future<void> Function() body) async {
  debugDefaultTargetPlatformOverride = platform;
  try {
    await body();
  } finally {
    debugDefaultTargetPlatformOverride = null;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppLocalizations l10n;
  late _FakeAuthHttp fakeHttp;
  late _FakeUrlLauncher fakeLauncher;
  late SupabaseClient client;
  late FeedbackSubmissionService accountService;
  late List<Object> recordedErrors;

  setUpAll(() async {
    l10n = await AppLocalizations.load(const Locale('en'));
  });

  setUp(() {
    fakeHttp = _FakeAuthHttp();
    client = SupabaseClient(
      'https://example.test',
      'test-anon-key',
      httpClient: fakeHttp,
      // pkceAsyncStorage: only the browser-redirect tests below touch the
      // PKCE code-verifier path, but it's inert for the id-token/email
      // tests, so it's simplest to supply it once here rather than per test.
      authOptions: AuthClientOptions(autoRefreshToken: false, pkceAsyncStorage: _InMemoryAsyncStorage()),
    );
    accountService = FeedbackSubmissionService(client: client);

    fakeLauncher = _FakeUrlLauncher();
    final previousLauncher = UrlLauncherPlatform.instance;
    UrlLauncherPlatform.instance = fakeLauncher;
    addTearDown(() => UrlLauncherPlatform.instance = previousLauncher);

    // The failure-path tests call recordError, whose real listener gathers
    // debug diagnostics on a 6s timeout that never completes under the test
    // clock and re-arms itself. Trip the install guard first (it only
    // assigns once per isolate), then swap in a listener that only collects.
    installLoggerErrorListener();
    recordedErrors = [];
    Logger.onRecordError = (_, error, _) => recordedErrors.add(error);
    addTearDown(() => Logger.onRecordError = null);
  });

  tearDown(() {
    client.dispose();
  });

  Future<void> pumpCard(
    WidgetTester tester, {
    Future<GoogleIdTokenResult> Function()? googleIdTokenFetcher,
    Future<AppleIdTokenResult> Function()? appleIdTokenFetcher,
  }) {
    return tester.pumpWidget(
      ShadcnApp(
        debugShowCheckedModeBanner: false,
        localizationsDelegates: const [AppLocalizations.delegate],
        supportedLocales: AppLocalizations.delegate.supportedLocales,
        home: Scaffold(
          child: SupportAccountLinkCard(
            accountService: accountService,
            googleIdTokenFetcher: googleIdTokenFetcher,
            appleIdTokenFetcher: appleIdTokenFetcher,
          ),
        ),
      ),
    );
  }

  /// Finds the one [SignInButton] wired to [button] — more robust than a
  /// positional index into `find.byType(SignInButton)` now that all four
  /// providers always render in a fixed order.
  Finder signInButtonFor(Buttons button) {
    return find.byWidgetPredicate((w) => w is SignInButton && w.button == button);
  }

  /// Simulates a browser-redirect link's deep-link callback landing well
  /// after `linkOAuthIdentity`'s own `Future` already resolved (browser
  /// opened) — driven through a real `updateUser` call so a real
  /// `AuthChangeEvent` fires on the real `onAuthStateChange` stream, the
  /// same stream [SupportAccountLinkCard] listens on. Keeps the session's
  /// user id, only flips `is_anonymous`, exactly like the real
  /// `exchangeCodeForSession` the app's deep-link handler would run.
  Future<void> simulateRedirectCompletion() {
    return client.auth.updateUser(UserAttributes(data: {'linked_via': 'oauth-redirect'}));
  }

  group('provider set — no platform gating', () {
    for (final platform in [TargetPlatform.android, TargetPlatform.iOS, TargetPlatform.macOS, TargetPlatform.windows]) {
      testWidgets('shows Google, Apple, GitHub and Facebook on $platform, matching LoginPage exactly', (tester) async {
        await withPlatform(platform, () async {
          await pumpCard(tester);
          await tester.pump();

          expect(find.byType(SignInButton), findsNWidgets(4));
          expect(signInButtonFor(Buttons.google), findsOneWidget);
          expect(signInButtonFor(Buttons.apple), findsOneWidget);
          expect(signInButtonFor(Buttons.gitHub), findsOneWidget);
          expect(signInButtonFor(Buttons.facebook), findsOneWidget);
        });
      });
    }

    testWidgets('hides all four once an email code is already in flight', (tester) async {
      await withPlatform(TargetPlatform.android, () async {
        await pumpCard(tester);
        await tester.pump();
        await tester.enterText(find.byKey(const ValueKey('support-account-email-field')), 'rider@example.com');
        await tester.tap(find.byKey(const ValueKey('support-account-email-send')));
        await tester.pumpAndSettle();

        expect(find.byKey(const ValueKey('support-account-code-field')), findsOneWidget);
        expect(find.byType(SignInButton), findsNothing);
      });
    });
  });

  group('native id-token linking (Google on Android/iOS, Apple on iOS/macOS)', () {
    testWidgets('Google on Android: links onto the existing anonymous session instead of switching users', (
      tester,
    ) async {
      await withPlatform(TargetPlatform.android, () async {
        // A message was already sent under this anonymous session before the
        // card ever appears — the scenario the orphaning risk is about.
        await client.auth.recoverSession(jsonEncode(_sessionJson(anonymous: true)));
        final userIdBeforeLink = client.auth.currentSession!.user.id;

        await pumpCard(
          tester,
          googleIdTokenFetcher: () async => const GoogleIdTokenResult(idToken: 'fake-google-id-token'),
        );
        await tester.pump();

        await tester.tap(signInButtonFor(Buttons.google));
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(find.byKey(const ValueKey('support-account-linked')), findsOneWidget);
        expect(fakeHttp.idTokenRequests, hasLength(1));
        expect(fakeHttp.authorizeRequests, isEmpty, reason: 'native path — never the browser-redirect one');
        expect(fakeHttp.signupRequests, isEmpty, reason: 'a session already existed — no new anonymous sign-in');
        expect(
          client.auth.currentSession!.user.id,
          userIdBeforeLink,
          reason: 'linking must not swap in a different user id — that would orphan the chat already written',
        );
        expect(client.auth.currentSession!.user.isAnonymous, isFalse);
      });
    });

    testWidgets('Apple on iOS: links onto the existing anonymous session', (tester) async {
      await withPlatform(TargetPlatform.iOS, () async {
        await client.auth.recoverSession(jsonEncode(_sessionJson(anonymous: true)));
        final userIdBeforeLink = client.auth.currentSession!.user.id;

        await pumpCard(
          tester,
          appleIdTokenFetcher: () async => const AppleIdTokenResult(idToken: 'fake-apple-id-token', rawNonce: 'nonce'),
        );
        await tester.pump();

        await tester.tap(signInButtonFor(Buttons.apple));
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(find.byKey(const ValueKey('support-account-linked')), findsOneWidget);
        expect(fakeHttp.authorizeRequests, isEmpty, reason: 'native path — never the browser-redirect one');
        expect(client.auth.currentSession!.user.id, userIdBeforeLink);
      });
    });

    testWidgets('Google with no prior session: creates one first (header Sign In tapped before any message)', (
      tester,
    ) async {
      await withPlatform(TargetPlatform.android, () async {
        expect(client.auth.currentSession, isNull);

        await pumpCard(
          tester,
          googleIdTokenFetcher: () async => const GoogleIdTokenResult(idToken: 'fake-google-id-token'),
        );
        await tester.pump();

        await tester.tap(signInButtonFor(Buttons.google));
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(find.byKey(const ValueKey('support-account-linked')), findsOneWidget);
        expect(fakeHttp.signupRequests, hasLength(1), reason: 'ensureSession creates the anonymous session first');
        expect(fakeHttp.idTokenRequests, hasLength(1));
      });
    });

    testWidgets('an Apple ID owned by another account shows the sign-in-instead hint', (tester) async {
      await withPlatform(TargetPlatform.iOS, () async {
        await client.auth.recoverSession(jsonEncode(_sessionJson(anonymous: true)));
        fakeHttp.idTokenAlreadyLinked = true;

        await pumpCard(
          tester,
          appleIdTokenFetcher: () async => const AppleIdTokenResult(idToken: 'fake-apple-id-token', rawNonce: 'nonce'),
        );
        await tester.pump();

        await tester.tap(signInButtonFor(Buttons.apple));
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(find.byKey(const ValueKey('support-account-linked')), findsNothing);
        expect(find.text(l10n.supportAccountAlreadyLinked), findsOneWidget);
        expect(find.text(l10n.supportAccountLinkFailed), findsNothing);
      });
    });

    testWidgets('a failed Google token fetch records the error and shows the generic failure message', (
      tester,
    ) async {
      await withPlatform(TargetPlatform.android, () async {
        await client.auth.recoverSession(jsonEncode(_sessionJson(anonymous: true)));

        await pumpCard(tester, googleIdTokenFetcher: () async => throw Exception('user cancelled'));
        await tester.pump();

        await tester.tap(signInButtonFor(Buttons.google));
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull, reason: 'never swallowed — recordError catches it, not a rethrow');
        expect(find.byKey(const ValueKey('support-account-linked')), findsNothing);
        expect(find.text(l10n.supportAccountLinkFailed), findsOneWidget);
        expect(fakeHttp.idTokenRequests, isEmpty, reason: 'the token fetch itself failed — never reaches Supabase');
      });
    });
  });

  group('browser-redirect linking (GitHub/Facebook always; Google/Apple with no native path)', () {
    testWidgets('GitHub always uses the redirect link, never the native id-token grant', (tester) async {
      await withPlatform(TargetPlatform.android, () async {
        await client.auth.recoverSession(jsonEncode(_sessionJson(anonymous: true)));

        await pumpCard(tester);
        await tester.pump();

        await tester.tap(signInButtonFor(Buttons.gitHub));
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(fakeHttp.idTokenRequests, isEmpty);
        expect(fakeHttp.authorizeRequests, hasLength(1));
        expect(fakeHttp.authorizeRequests.single.url.queryParameters['provider'], 'github');
        expect(fakeLauncher.launchedUrls, ['https://example.test/oauth-redirect']);
        // Only the browser tab opened so far — completion is still pending,
        // so the card must not have jumped to "linked" on its own.
        expect(find.byKey(const ValueKey('support-account-linked')), findsNothing);
      });
    });

    testWidgets('Facebook always uses the redirect link too', (tester) async {
      await withPlatform(TargetPlatform.iOS, () async {
        await client.auth.recoverSession(jsonEncode(_sessionJson(anonymous: true)));

        await pumpCard(tester);
        await tester.pump();

        await tester.tap(signInButtonFor(Buttons.facebook));
        await tester.pumpAndSettle();

        expect(fakeHttp.idTokenRequests, isEmpty);
        expect(fakeHttp.authorizeRequests.single.url.queryParameters['provider'], 'facebook');
      });
    });

    testWidgets('Google on macOS (no native path there) falls back to the redirect link', (tester) async {
      await withPlatform(TargetPlatform.macOS, () async {
        await client.auth.recoverSession(jsonEncode(_sessionJson(anonymous: true)));

        await pumpCard(tester);
        await tester.pump();

        await tester.tap(signInButtonFor(Buttons.google));
        await tester.pumpAndSettle();

        expect(fakeHttp.idTokenRequests, isEmpty, reason: 'macOS has no native Google Sign-In path');
        expect(fakeHttp.authorizeRequests.single.url.queryParameters['provider'], 'google');
      });
    });

    testWidgets('Apple on Android (no native path there) falls back to the redirect link', (tester) async {
      await withPlatform(TargetPlatform.android, () async {
        await client.auth.recoverSession(jsonEncode(_sessionJson(anonymous: true)));

        await pumpCard(tester);
        await tester.pump();

        await tester.tap(signInButtonFor(Buttons.apple));
        await tester.pumpAndSettle();

        expect(fakeHttp.idTokenRequests, isEmpty, reason: 'Android has no native Sign in with Apple path');
        expect(fakeHttp.authorizeRequests.single.url.queryParameters['provider'], 'apple');
      });
    });

    testWidgets(
      'the redirect flow completing later (deep link back) is detected once the session stops being anonymous',
      (tester) async {
        await withPlatform(TargetPlatform.android, () async {
          await client.auth.recoverSession(jsonEncode(_sessionJson(anonymous: true)));
          final userIdBeforeLink = client.auth.currentSession!.user.id;
          var onLinkedCalls = 0;

          await tester.pumpWidget(
            ShadcnApp(
              debugShowCheckedModeBanner: false,
              localizationsDelegates: const [AppLocalizations.delegate],
              supportedLocales: AppLocalizations.delegate.supportedLocales,
              home: Scaffold(
                child: SupportAccountLinkCard(accountService: accountService, onLinked: () => onLinkedCalls++),
              ),
            ),
          );
          await tester.pump();

          await tester.tap(signInButtonFor(Buttons.gitHub));
          await tester.pumpAndSettle();

          // Still pending — the browser tab is open but nothing has come
          // back yet.
          expect(find.byKey(const ValueKey('support-account-linked')), findsNothing);
          expect(onLinkedCalls, 0);

          // The deep link now brings the app back with a session that's no
          // longer anonymous, same user id.
          await simulateRedirectCompletion();
          await tester.pumpAndSettle();

          expect(find.byKey(const ValueKey('support-account-linked')), findsOneWidget);
          expect(onLinkedCalls, 1);
          expect(
            client.auth.currentSession!.user.id,
            userIdBeforeLink,
            reason: 'the chat already written under the anonymous session must not be orphaned',
          );
        });
      },
    );

    testWidgets('a rejected authorize request shows the generic failure message, never reaching the browser', (
      tester,
    ) async {
      await withPlatform(TargetPlatform.android, () async {
        await client.auth.recoverSession(jsonEncode(_sessionJson(anonymous: true)));
        fakeHttp.authorizeError = true;

        await pumpCard(tester);
        await tester.pump();

        await tester.tap(signInButtonFor(Buttons.facebook));
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull, reason: 'never swallowed — recordError catches it, not a rethrow');
        expect(find.text(l10n.supportAccountLinkFailed), findsOneWidget);
        expect(fakeLauncher.launchedUrls, isEmpty);
      });
    });
  });

  group('email already belongs to another account', () {
    Future<void> sendEmail(WidgetTester tester, String email) async {
      await tester.enterText(find.byKey(const ValueKey('support-account-email-field')), email);
      await tester.tap(find.byKey(const ValueKey('support-account-email-send')));
      await tester.pumpAndSettle();
    }

    testWidgets('explains that the address already has an account instead of a generic failure', (tester) async {
      await withPlatform(TargetPlatform.windows, () async {
        await client.auth.recoverSession(jsonEncode(_sessionJson(anonymous: true)));
        fakeHttp.emailTaken = true;

        await pumpCard(tester);
        await tester.pump();
        await sendEmail(tester, 'taken@example.com');

        expect(tester.takeException(), isNull);
        expect(find.byKey(const ValueKey('support-account-email-taken')), findsOneWidget);
        expect(find.text(l10n.supportAccountLinkFailed), findsNothing);
        // Still on the email step: no code was sent, so no code field.
        expect(find.byKey(const ValueKey('support-account-code-field')), findsNothing);
        expect(find.byKey(const ValueKey('support-account-email-field')), findsOneWidget);
        expect(recordedErrors, isNotEmpty, reason: 'the failure is still recorded, not swallowed');
        // The anonymous session, and with it the chat, is left untouched.
        expect(client.auth.currentSession!.user.isAnonymous, isTrue);
        expect(client.auth.currentSession!.user.id, 'user-id');
      });
    });

    testWidgets('a different address afterwards clears the message and moves on to the code step', (tester) async {
      await withPlatform(TargetPlatform.windows, () async {
        await client.auth.recoverSession(jsonEncode(_sessionJson(anonymous: true)));
        fakeHttp.emailTaken = true;

        await pumpCard(tester);
        await tester.pump();
        await sendEmail(tester, 'taken@example.com');
        expect(find.byKey(const ValueKey('support-account-email-taken')), findsOneWidget);

        fakeHttp.emailTaken = false;
        await sendEmail(tester, 'new@example.com');

        expect(find.byKey(const ValueKey('support-account-email-taken')), findsNothing);
        expect(find.byKey(const ValueKey('support-account-code-field')), findsOneWidget);
      });
    });
  });

  group('width cap', () {
    testWidgets('caps content width and centers it on a wide desktop window instead of stretching full width', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1400, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await withPlatform(TargetPlatform.windows, () async {
        await pumpCard(tester);
        await tester.pump();

        // Same idiom and value as ClickV2OnboardingPage's own fix — see
        // support_account_link_card.dart's `_capped`.
        final cap = find.byWidgetPredicate((w) => w is ConstrainedBox && w.constraints.maxWidth == 720);
        expect(cap, findsOneWidget);
        expect(tester.getSize(cap).width, 720);

        final capLeft = tester.getTopLeft(cap).dx;
        final capRight = tester.getTopRight(cap).dx;
        expect(capLeft, closeTo(1400 - capRight, 0.5), reason: 'centered, not pinned to an edge');
      });
    });
  });
}
