// Shared Google / Sign in with Apple token-fetch logic, extracted so both
// `LoginPage` (a normal `signInWithIdToken` sign-in) and
// `SupportAccountLinkCard` (a `linkIdentityWithIdToken` *link* onto the
// chat's existing anonymous session — see that file's header comment for why
// linking, not signing in, is required there) drive the exact same native
// SDK calls instead of each having their own copy. Only the native,
// id-token-producing platforms are covered here — the browser-redirect OAuth
// fallback `LoginPage` uses elsewhere for other platforms/providers stays
// inline there, since it signs in directly rather than producing a token
// this file's callers can act on differently.
import 'dart:convert';
import 'dart:io' show Platform;
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// True on platforms where Google Sign-In can hand back a native ID token
/// directly (matches [LoginPage]'s existing native-vs-browser-redirect
/// split). Backed by [defaultTargetPlatform] rather than `dart:io`'s
/// `Platform` so tests can force it with `debugDefaultTargetPlatformOverride`
/// regardless of which OS actually runs the test.
bool get supportsNativeGoogleSignIn =>
    defaultTargetPlatform == TargetPlatform.android || defaultTargetPlatform == TargetPlatform.iOS;

/// True on platforms where Sign in with Apple can hand back a native ID
/// token directly.
bool get supportsNativeAppleSignIn =>
    defaultTargetPlatform == TargetPlatform.iOS || defaultTargetPlatform == TargetPlatform.macOS;

/// A Google ID token plus the OAuth access token Supabase also wants for the
/// `signInWithIdToken`/`linkIdentityWithIdToken` request body.
class GoogleIdTokenResult {
  final String idToken;
  final String? accessToken;

  const GoogleIdTokenResult({required this.idToken, this.accessToken});
}

/// An Apple ID token plus the raw (unhashed) nonce Supabase re-hashes to
/// verify against the nonce claim baked into the token.
class AppleIdTokenResult {
  final String idToken;
  final String rawNonce;

  const AppleIdTokenResult({required this.idToken, required this.rawNonce});
}

/// Drives the native Google Sign-In SDK to produce an ID token. Only call
/// this when [supportsNativeGoogleSignIn] is true — it assumes Android/iOS
/// throughout (carried over unchanged from `LoginPage`'s original native
/// branch).
Future<GoogleIdTokenResult> fetchGoogleIdToken() async {
  const webClientId = '709945926587-bgk7j9qc86t7nuemu100ngvl9c7irv9k.apps.googleusercontent.com';
  final iosClientId = Platform.isAndroid
      ? (kDebugMode
            ? '709945926587-fr2uodlnea57jc3mr8qannt45hi0tjeq.apps.googleusercontent.com'
            : '709945926587-orkcqc71o6i3cf5lkd85k9n93lobfgae.apps.googleusercontent.com')
      : '709945926587-0iierajthibf4vhqf85fc7bbpgbdgua2.apps.googleusercontent.com';
  const scopes = ['email'];
  final googleSignIn = GoogleSignIn.instance;
  await googleSignIn.initialize(serverClientId: webClientId, clientId: iosClientId);
  GoogleSignInAccount? googleUser = await googleSignIn.attemptLightweightAuthentication(reportAllExceptions: true);
  googleUser ??= await googleSignIn.authenticate();

  final authorization =
      await googleUser.authorizationClient.authorizationForScopes(scopes) ??
      await googleUser.authorizationClient.authorizeScopes(scopes);
  final idToken = googleUser.authentication.idToken;
  if (idToken == null) {
    throw const AuthException('No ID Token found.');
  }
  return GoogleIdTokenResult(idToken: idToken, accessToken: authorization.accessToken);
}

/// Drives the native Sign in with Apple SDK to produce an ID token. Only
/// call this when [supportsNativeAppleSignIn] is true.
Future<AppleIdTokenResult> fetchAppleIdToken() async {
  // Mirrors `GoTrueClient.generateRawNonce()` (16 random bytes, base64url) —
  // duplicated rather than threading a client instance through just for this
  // one stateless helper.
  final random = Random.secure();
  final rawNonce = base64Url.encode(List<int>.generate(16, (_) => random.nextInt(256)));
  final hashedNonce = sha256.convert(utf8.encode(rawNonce)).toString();

  final credential = await SignInWithApple.getAppleIDCredential(
    scopes: [AppleIDAuthorizationScopes.email],
    nonce: hashedNonce,
  );
  final idToken = credential.identityToken;
  if (idToken == null) {
    throw const AuthException('Could not find ID Token from generated credential.');
  }
  return AppleIdTokenResult(idToken: idToken, rawNonce: rawNonce);
}

/// Whether [error] is the rider closing the Google or Apple sheet, which is
/// a choice, not a failure to report.
bool isSignInCancellation(Object error) =>
    (error is GoogleSignInException && error.code == GoogleSignInExceptionCode.canceled) ||
    (error is SignInWithAppleAuthorizationException && error.code == AuthorizationErrorCode.canceled);

/// Signs in with [provider] on [client]: the native Google / Apple sheet
/// where the platform has one (an ID token Supabase verifies), else the
/// provider's page in the browser, which returns through `bikecontrol://`.
Future<void> signInWithProvider(SupabaseClient client, OAuthProvider provider) async {
  if (provider == OAuthProvider.google && supportsNativeGoogleSignIn) {
    final token = await fetchGoogleIdToken();
    await client.auth.signInWithIdToken(
      provider: OAuthProvider.google,
      idToken: token.idToken,
      accessToken: token.accessToken,
    );
    return;
  }
  if (provider == OAuthProvider.apple && supportsNativeAppleSignIn) {
    final token = await fetchAppleIdToken();
    await client.auth.signInWithIdToken(provider: OAuthProvider.apple, idToken: token.idToken, nonce: token.rawNonce);
    return;
  }
  await client.auth.signInWithOAuth(
    provider,
    redirectTo: kIsWeb ? null : 'bikecontrol://login/',
    authScreenLaunchMode: kIsWeb ? LaunchMode.platformDefault : LaunchMode.externalApplication,
  );
}
