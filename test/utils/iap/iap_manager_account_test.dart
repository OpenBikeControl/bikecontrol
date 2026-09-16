// Opening the support chat without an account creates an anonymous Supabase
// session. That session is not an account: a rider who bought Pro in the
// store (RevenueCat, never signed in) must keep Pro, and the anonymous user
// id must never become their RevenueCat identity.
import 'dart:convert';

import 'package:bike_control/utils/iap/iap_manager.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

Map<String, dynamic> _sessionJson({required bool anonymous, String? email, String id = 'user-id'}) => {
  'access_token': 'test-access-token',
  'token_type': 'bearer',
  'expires_in': 3600,
  'refresh_token': 'test-refresh-token',
  'user': {
    'id': id,
    'aud': 'authenticated',
    'created_at': '2026-08-24T00:00:00Z',
    'app_metadata': <String, dynamic>{},
    'user_metadata': <String, dynamic>{},
    'is_anonymous': anonymous,
    if (email != null) 'email': email,
  },
};

User _user({required bool anonymous, String? email, String id = 'user-id'}) =>
    User.fromJson(_sessionJson(anonymous: anonymous, email: email, id: id)['user'] as Map<String, dynamic>)!;

IAPManager get iap => IAPManager.instance;
GoTrueClient get auth => Supabase.instance.client.auth;

Future<void> main() async {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await Supabase.initialize(
      url: 'http://127.0.0.1:9',
      anonKey: 'iap-manager-test-anon-key',
      debug: false,
      authOptions: const FlutterAuthClientOptions(
        localStorage: EmptyLocalStorage(),
        detectSessionInUri: false,
        autoRefreshToken: false,
      ),
    );
  });

  group('store-bought Pro with an anonymous support-chat session', () {
    setUp(() => iap.setProForTesting(enabled: true));
    tearDown(() => iap.setProForTesting(enabled: false));

    test('is not logged in', () async {
      await auth.recoverSession(jsonEncode(_sessionJson(anonymous: true, email: '')));

      expect(iap.isLoggedIn, isFalse);
    });

    test('keeps Pro', () async {
      await auth.recoverSession(jsonEncode(_sessionJson(anonymous: true, email: '')));

      expect(iap.hasActiveSubscription, isTrue);
      expect(iap.isProEnabled, isTrue);
      expect(iap.isProEnabledForCurrentDevice, isTrue);
    });

    test('a real account is logged in and no longer uses the local store entitlement', () async {
      await auth.recoverSession(jsonEncode(_sessionJson(anonymous: false, email: 'rider@example.com')));

      expect(iap.isLoggedIn, isTrue);
      // No server entitlement cached for this account in the test.
      expect(iap.isProEnabledForCurrentDevice, isFalse);
    });
  });

  group('revenueCatLogin', () {
    test('never logs RevenueCat in as an anonymous user', () {
      for (final event in AuthChangeEvent.values) {
        expect(
          IAPManager.revenueCatLogin(
            event: event,
            user: _user(anonymous: true, email: ''),
            previousUserId: null,
          ),
          isNull,
          reason: '$event',
        );
      }
    });

    test('does nothing without a user', () {
      expect(
        IAPManager.revenueCatLogin(event: AuthChangeEvent.signedIn, user: null, previousUserId: null),
        isNull,
      );
    });

    test('logs an account in and syncs on a fresh sign-in or launch', () {
      final user = _user(anonymous: false, email: 'rider@example.com');
      for (final event in [AuthChangeEvent.signedIn, AuthChangeEvent.initialSession]) {
        expect(
          IAPManager.revenueCatLogin(event: event, user: user, previousUserId: 'user-id'),
          (userId: 'user-id', performSync: true),
        );
      }
    });

    test('a token refresh for the same account logs in without syncing', () {
      expect(
        IAPManager.revenueCatLogin(
          event: AuthChangeEvent.tokenRefreshed,
          user: _user(anonymous: false, email: 'rider@example.com'),
          previousUserId: 'user-id',
        ),
        (userId: 'user-id', performSync: false),
      );
    });

    test('an anonymous session that just became an account (email linked) syncs', () {
      // Linking keeps the user id but fires userUpdated, not signedIn, and the
      // anonymous phase never logged RevenueCat in.
      expect(
        IAPManager.revenueCatLogin(
          event: AuthChangeEvent.userUpdated,
          user: _user(anonymous: false, email: 'rider@example.com'),
          previousUserId: null,
        ),
        (userId: 'user-id', performSync: true),
      );
    });
  });
}
