// The Account page must not mistake the support chat's on-demand anonymous
// session for a signed-in account: that used to show the green "signed in"
// card with a blank label and a Logout button, hiding every way to sign in.
import 'dart:convert';

import 'package:bike_control/gen/l10n.dart';
import 'package:bike_control/main.dart' show OtherLocalizationsDelegate;
import 'package:bike_control/pages/subscriptions/email_login_form.dart';
import 'package:bike_control/pages/subscriptions/login.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:sign_in_button/sign_in_button.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../widget_snapshot.dart';

/// Only the OTP endpoints are reachable from this page in these tests.
class _FakeAuthHttp extends http.BaseClient {
  final List<http.Request> otpRequests = [];
  final List<http.Request> verifyRequests = [];

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final req = request as http.Request;
    final path = request.url.path;
    if (path.endsWith('/auth/v1/otp')) {
      otpRequests.add(req);
      return _json(<String, dynamic>{});
    }
    if (path.endsWith('/auth/v1/verify')) {
      verifyRequests.add(req);
      // A different user id: signing in replaces the anonymous session.
      return _json(_sessionJson(id: 'account-id', anonymous: false, email: 'rider@example.com'));
    }
    return _json(<String, dynamic>{}, status: 404);
  }

  http.StreamedResponse _json(Map<String, dynamic> body, {int status = 200}) => http.StreamedResponse(
    Stream.value(utf8.encode(jsonEncode(body))),
    status,
    headers: const {'content-type': 'application/json'},
  );
}

Map<String, dynamic> _sessionJson({
  String id = 'user-id',
  required bool anonymous,
  String? email,
  List<Map<String, dynamic>> identities = const [],
  Map<String, dynamic> userMetadata = const {},
}) {
  return {
    'access_token': 'test-access-token',
    'token_type': 'bearer',
    'expires_in': 3600,
    'refresh_token': 'test-refresh-token',
    'user': {
      'id': id,
      'aud': 'authenticated',
      'created_at': '2026-08-24T00:00:00Z',
      'app_metadata': <String, dynamic>{},
      'user_metadata': userMetadata,
      'is_anonymous': anonymous,
      if (email != null) 'email': email,
      'identities': identities,
    },
  };
}

/// signInWithOtp runs the PKCE flow, which stashes a code verifier first.
class _InMemoryAsyncStorage extends GotrueAsyncStorage {
  final _store = <String, String>{};

  @override
  Future<String?> getItem({required String key}) async => _store[key];

  @override
  Future<void> setItem({required String key, required String value}) async => _store[key] = value;

  @override
  Future<void> removeItem({required String key}) async => _store.remove(key);
}

Map<String, dynamic> _identity(String provider) => {
  'id': 'identity-$provider',
  'user_id': 'user-id',
  'identity_id': 'identity-$provider',
  'identity_data': <String, dynamic>{},
  'provider': provider,
  'created_at': '2026-08-24T00:00:00Z',
  'last_sign_in_at': '2026-08-24T00:00:00Z',
  'updated_at': '2026-08-24T00:00:00Z',
};

Future<void> main() async {
  await ensureSnapshotHarness();

  late _FakeAuthHttp fakeHttp;
  late SupabaseClient client;
  late AppLocalizations l10n;

  setUpAll(() async {
    l10n = await AppLocalizations.load(const Locale('en'));
  });

  setUp(() {
    fakeHttp = _FakeAuthHttp();
    client = SupabaseClient(
      'https://example.test',
      'test-anon-key',
      httpClient: fakeHttp,
      authOptions: AuthClientOptions(autoRefreshToken: false, pkceAsyncStorage: _InMemoryAsyncStorage()),
    );
  });

  tearDown(() => client.dispose());

  Future<void> pumpLoginPage(WidgetTester tester) async {
    await tester.pumpWidget(
      ShadcnApp(
        debugShowCheckedModeBanner: false,
        localizationsDelegates: [
          ...ShadcnLocalizations.localizationsDelegates,
          const OtherLocalizationsDelegate(),
          AppLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.delegate.supportedLocales,
        theme: ThemeData(colorScheme: ColorSchemes.lightSlate, radius: 0.7),
        home: Scaffold(child: LoginPage(pushed: false, client: client)),
      ),
    );
    await tester.pumpAndSettle();
  }

  Finder logoutButton() => find.text(l10n.logout);

  testWidgets('an anonymous support-chat session shows the sign-in options, not a blank signed-in card', (
    tester,
  ) async {
    // GoTrue reports an anonymous user's email as "", not null.
    await client.auth.recoverSession(jsonEncode(_sessionJson(anonymous: true, email: '')));

    await pumpLoginPage(tester);

    expect(find.byType(EmailLoginForm), findsOneWidget);
    expect(find.byType(SignInButton), findsNWidgets(4));
    expect(logoutButton(), findsNothing);
  });

  testWidgets('signing in with an email code from the anonymous state replaces the anonymous session', (
    tester,
  ) async {
    await client.auth.recoverSession(jsonEncode(_sessionJson(anonymous: true, email: '')));
    await pumpLoginPage(tester);

    await tester.enterText(find.byKey(EmailLoginForm.emailFieldKey), 'rider@example.com');
    await tester.ensureVisible(find.byKey(EmailLoginForm.sendButtonKey));
    await tester.tap(find.byKey(EmailLoginForm.sendButtonKey));
    await tester.pumpAndSettle();
    expect(fakeHttp.otpRequests, hasLength(1));

    final boxes = find.descendant(of: find.byKey(EmailLoginForm.codeFieldKey), matching: find.byType(TextField));
    await tester.ensureVisible(boxes.first);
    for (var i = 0; i < 6; i++) {
      await tester.enterText(boxes.at(i), '${i + 1}');
      await tester.pump();
    }
    await tester.pumpAndSettle();

    expect(fakeHttp.verifyRequests, hasLength(1));
    final user = client.auth.currentSession!.user;
    expect(user.id, 'account-id');
    expect(user.isAnonymous, isFalse);
    expect(user.email, 'rider@example.com');
    expect(find.text('rider@example.com'), findsOneWidget);
    expect(logoutButton(), findsOneWidget);
  });

  testWidgets('a real account shows its email and a logout button', (tester) async {
    await client.auth.recoverSession(
      jsonEncode(_sessionJson(anonymous: false, email: 'rider@example.com', identities: [_identity('email')])),
    );

    await pumpLoginPage(tester);

    expect(find.text('rider@example.com'), findsOneWidget);
    expect(logoutButton(), findsOneWidget);
    expect(find.byType(EmailLoginForm), findsNothing);
  });

  testWidgets('an account without an email still gets a readable label', (tester) async {
    await client.auth.recoverSession(
      jsonEncode(
        _sessionJson(
          anonymous: false,
          email: '',
          identities: [_identity('github')],
          userMetadata: {'user_name': 'rider1'},
        ),
      ),
    );

    await pumpLoginPage(tester);

    expect(find.text('rider1'), findsOneWidget);
    expect(logoutButton(), findsOneWidget);
  });
}
