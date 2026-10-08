// The Settings plan card offers "Sign in" beside "Go Pro" while no account is
// signed in: a rider who already bought Pro on another device would otherwise
// only see "Go Pro", and sign-in lives behind it in Plan & account.
import 'dart:convert';

import 'package:bike_control/gen/l10n.dart';
import 'package:bike_control/main.dart' show OtherLocalizationsDelegate;
import 'package:bike_control/pages/plan/plan_account_page.dart';
import 'package:bike_control/pages/settings/settings_page.dart';
import 'package:bike_control/utils/iap/iap_manager.dart';
import 'package:bike_control/widgets/ui/app_theme.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../widget_snapshot.dart';

class _NoHttp extends http.BaseClient {
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async =>
      http.StreamedResponse(Stream.value(utf8.encode('{}')), 404, headers: const {'content-type': 'application/json'});
}

class _MemoryStorage extends GotrueAsyncStorage {
  final _store = <String, String>{};

  @override
  Future<String?> getItem({required String key}) async => _store[key];

  @override
  Future<void> setItem({required String key, required String value}) async => _store[key] = value;

  @override
  Future<void> removeItem({required String key}) async => _store.remove(key);
}

Map<String, dynamic> _session() => {
  'access_token': 'token',
  'token_type': 'bearer',
  'expires_in': 3600,
  'refresh_token': 'refresh',
  'user': {
    'id': 'user-id',
    'aud': 'authenticated',
    'created_at': '2026-08-24T00:00:00Z',
    'app_metadata': {'provider': 'email'},
    'user_metadata': <String, dynamic>{},
    'is_anonymous': false,
    'email': 'anna.radler@example.com',
    'identities': <Map<String, dynamic>>[],
  },
};

Future<void> main() async {
  await ensureSnapshotHarness();
  late SupabaseClient client;
  late AppLocalizations l;

  setUpAll(() async {
    l = await AppLocalizations.load(const Locale('en'));
  });

  setUp(() {
    client = SupabaseClient(
      'https://example.test',
      'anon',
      httpClient: _NoHttp(),
      authOptions: AuthClientOptions(autoRefreshToken: false, pkceAsyncStorage: _MemoryStorage()),
    );
    IAPManager.instance.setProForTesting(enabled: false);
  });

  tearDown(() {
    client.dispose();
    IAPManager.instance.setProForTesting(enabled: false);
  });

  Future<void> pumpCard(WidgetTester tester) async {
    tester.view.physicalSize = const Size(430, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ShadcnApp(
        localizationsDelegates: [
          ...ShadcnLocalizations.localizationsDelegates,
          const OtherLocalizationsDelegate(),
          AppLocalizations.delegate,
        ],
        supportedLocales: const [Locale('en')],
        theme: BkTheme.build(Brightness.dark),
        home: Scaffold(child: SettingsPlanCard(client: client)),
      ),
    );
    await tester.pump();
  }

  Finder inCard(Finder finder) => find.descendant(of: find.byKey(const ValueKey('settings-plan')), matching: finder);

  testWidgets('signed out without Pro: Go Pro and Sign in', (tester) async {
    await pumpCard(tester);
    expect(inCard(find.text(l.goPro)), findsOneWidget);
    expect(inCard(find.text(l.signIn)), findsOneWidget);
  });

  testWidgets('Sign in opens Plan & account, where sign-in lives', (tester) async {
    await pumpCard(tester);
    await tester.tap(inCard(find.text(l.signIn)));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byType(PlanAccountPage), findsOneWidget);
  });

  testWidgets('signed in: Go Pro only', (tester) async {
    await client.auth.recoverSession(jsonEncode(_session()));
    await pumpCard(tester);
    expect(inCard(find.text(l.goPro)), findsOneWidget);
    expect(inCard(find.text(l.signIn)), findsNothing);
  });

  testWidgets('signing in hides it', (tester) async {
    await pumpCard(tester);
    expect(inCard(find.text(l.signIn)), findsOneWidget);
    await tester.runAsync(() => client.auth.recoverSession(jsonEncode(_session())));
    await tester.pump();
    expect(inCard(find.text(l.signIn)), findsNothing);
  });

  testWidgets('with Pro on this device: no Sign in', (tester) async {
    IAPManager.instance.setProForTesting(enabled: true, registeredDevice: true);
    await pumpCard(tester);
    expect(inCard(find.text(l.signIn)), findsNothing);
  });
}
