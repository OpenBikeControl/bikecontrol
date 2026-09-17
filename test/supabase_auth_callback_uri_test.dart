import 'package:bike_control/main.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('isSupabaseAuthCallbackUri', () {
    // Mirrors supabase_flutter's private `_isAuthCallbackDeeplink`: the OAuth
    // callback the browser hands back after "Sign in with Apple" (and Google /
    // GitHub / Facebook) carries either a PKCE `code` query param, an implicit
    // `access_token` fragment, or an `error_description` fragment. On desktop
    // cold start supabase_flutter drops this link (its `_handleInitialUri` is
    // gated to `kIsWeb`), so the app has to recognise and exchange it itself.
    test('true for a PKCE code query param', () {
      expect(isSupabaseAuthCallbackUri(Uri.parse('bikecontrol://login/?code=abc')), isTrue);
    });

    test('true for an implicit access_token fragment', () {
      expect(
        isSupabaseAuthCallbackUri(
          Uri.parse('bikecontrol://login/#access_token=xyz&refresh_token=rrr'),
        ),
        isTrue,
      );
    });

    test('true for an error_description fragment', () {
      expect(
        isSupabaseAuthCallbackUri(Uri.parse('bikecontrol://login/#error_description=denied')),
        isTrue,
      );
    });

    test('false for a non-auth bikecontrol deep link (stripe-success)', () {
      expect(isSupabaseAuthCallbackUri(Uri.parse('bikecontrol://stripe-success')), isFalse);
    });

    test('false for the bare redirect with no code/token/error', () {
      expect(isSupabaseAuthCallbackUri(Uri.parse('bikecontrol://login/')), isFalse);
    });

    test('false for an unrelated https url', () {
      expect(isSupabaseAuthCallbackUri(Uri.parse('https://bikecontrol.app/')), isFalse);
    });
  });

  group('handleDesktopColdStartAuthCallback', () {
    test('exchanges the session and refreshes entitlements for an auth callback', () async {
      Uri? exchanged;
      var refreshed = false;
      Object? recorded;

      await handleDesktopColdStartAuthCallback(
        getInitialLink: () async => Uri.parse('bikecontrol://login/?code=abc'),
        exchangeSession: (uri) async => exchanged = uri,
        onSessionEstablished: () async => refreshed = true,
        onError: (e, s) async => recorded = e,
      );

      expect(exchanged, Uri.parse('bikecontrol://login/?code=abc'));
      expect(refreshed, isTrue);
      expect(recorded, isNull);
    });

    test('does NOT exchange a non-auth deep link (avoids double-exchange)', () async {
      var exchangeCalled = false;
      var refreshed = false;

      await handleDesktopColdStartAuthCallback(
        getInitialLink: () async => Uri.parse('bikecontrol://stripe-success'),
        exchangeSession: (uri) async => exchangeCalled = true,
        onSessionEstablished: () async => refreshed = true,
      );

      expect(exchangeCalled, isFalse);
      expect(refreshed, isFalse);
    });

    test('does NOT exchange an auth-shaped link on a foreign scheme', () async {
      var exchangeCalled = false;

      await handleDesktopColdStartAuthCallback(
        getInitialLink: () async => Uri.parse('https://evil.example/?code=abc'),
        exchangeSession: (uri) async => exchangeCalled = true,
        onSessionEstablished: () async {},
      );

      expect(exchangeCalled, isFalse);
    });

    test('does nothing when there is no initial link', () async {
      var exchangeCalled = false;

      await handleDesktopColdStartAuthCallback(
        getInitialLink: () async => null,
        exchangeSession: (uri) async => exchangeCalled = true,
        onSessionEstablished: () async {},
      );

      expect(exchangeCalled, isFalse);
    });

    test('forwards exchange failures to onError and skips the entitlements refresh', () async {
      final failure = StateError('already consumed');
      Object? recorded;
      var refreshed = false;

      await handleDesktopColdStartAuthCallback(
        getInitialLink: () async => Uri.parse('bikecontrol://login/?code=abc'),
        exchangeSession: (uri) async => throw failure,
        onSessionEstablished: () async => refreshed = true,
        onError: (e, s) async => recorded = e,
      );

      expect(recorded, same(failure));
      expect(refreshed, isFalse);
    });

    test('forwards getInitialLink failures to onError', () async {
      final failure = StateError('no plugin');
      Object? recorded;
      var exchangeCalled = false;

      await handleDesktopColdStartAuthCallback(
        getInitialLink: () async => throw failure,
        exchangeSession: (uri) async => exchangeCalled = true,
        onSessionEstablished: () async {},
        onError: (e, s) async => recorded = e,
      );

      expect(recorded, same(failure));
      expect(exchangeCalled, isFalse);
    });
  });
}
