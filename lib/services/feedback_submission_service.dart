// In-app feedback: a rider taps thumbs up/down, writes a note, and it lands
// in the `submit-feedback` edge function. The session may be anonymous — no
// sign-in is required to leave feedback — but the composer can offer to link
// an email afterwards so we can follow up.
import 'dart:io';

import 'package:bike_control/main.dart' show recordError;
import 'package:bike_control/utils/core.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

enum FeedbackSentiment { up, down }

enum FeedbackKind { suggestion, complaint }

class FeedbackSubmissionException implements Exception {
  const FeedbackSubmissionException(this.message);

  final String message;

  @override
  String toString() => 'FeedbackSubmissionException: $message';
}

/// The Google/Apple identity being linked already belongs to a different
/// BikeControl account (GoTrue `identity_already_exists`). The rider has to
/// sign in with that identity instead of linking it, so the UI shows a
/// specific hint rather than the generic "try again".
class IdentityAlreadyLinkedException extends FeedbackSubmissionException {
  const IdentityAlreadyLinkedException(super.message);
}

/// GoTrue's error code for linking an identity that another user owns.
const _identityAlreadyExistsCode = 'identity_already_exists';

bool _isIdentityAlreadyLinked(Object error) =>
    error is AuthException && error.code == _identityAlreadyExistsCode;

/// Submits rider feedback to the `submit-feedback` edge function, creating an
/// anonymous Supabase session on demand, and offers a follow-up flow that
/// links an email address to that session.
class FeedbackSubmissionService {
  FeedbackSubmissionService({SupabaseClient? client}) : _client = client ?? core.supabase;

  static const _submitFunction = 'submit-feedback';

  final SupabaseClient _client;

  /// True when the current session has no confirmed email — either there is
  /// no session yet, or the signed-in user is anonymous.
  bool get isAnonymous {
    final user = _client.auth.currentSession?.user;
    if (user == null) return true;
    if (user.isAnonymous) return true;
    final email = user.email;
    return email == null || email.isEmpty;
  }

  /// Ensures a session (anonymous if none), then invokes the submit-feedback
  /// edge function. Throws [FeedbackSubmissionException] on any failure so
  /// the composer can keep the text and offer retry.
  Future<void> submit({
    required FeedbackSentiment sentiment,
    required FeedbackKind kind,
    required String body,
  }) async {
    await ensureSession();

    final payload = <String, dynamic>{
      'sentiment': sentiment.name,
      'kind': kind.name,
      'body': body,
      ...await _contextFields(),
    };

    try {
      await _client.functions.invoke(_submitFunction, body: payload);
    } catch (e, s) {
      await recordError(e, s, context: 'FeedbackSubmissionService.submit');
      throw const FeedbackSubmissionException('Failed to submit feedback');
    }
  }

  /// Starts linking [email] to the anonymous session (updateUser → OTP mail).
  Future<void> beginEmailLink(String email) async {
    // Guarantees a session exists before the authenticated `updateUser` call
    // below — a no-op whenever one already does (the common case: the rider
    // reached this card after `_send()` already created one). Covers the
    // header "Sign In" button, which can be tapped before any message — and
    // therefore any session — exists yet. Called outside this method's own
    // try/catch: `ensureSession` already records and wraps its own failures,
    // so nesting it here would only double-record the same error under a
    // less accurate message.
    await ensureSession();
    try {
      await _client.auth.updateUser(UserAttributes(email: email));
    } catch (e, s) {
      await recordError(e, s, context: 'FeedbackSubmissionService.beginEmailLink');
      throw const FeedbackSubmissionException('Failed to start email verification');
    }
  }

  /// Confirms the 6-digit [token] for [email] (OtpType.emailChange).
  Future<void> confirmEmailLink({required String email, required String token}) async {
    try {
      await _client.auth.verifyOTP(type: OtpType.emailChange, email: email, token: token);
    } catch (e, s) {
      await recordError(e, s, context: 'FeedbackSubmissionService.confirmEmailLink');
      throw const FeedbackSubmissionException('Failed to confirm the verification code');
    }
  }

  /// Links a Google identity — its [idToken]/[accessToken] obtained via
  /// [fetchGoogleIdToken] — onto the CURRENT session via GoTrue's id-token
  /// identity linking (`linkIdentityWithIdToken`), rather than signing in as
  /// a — possibly different — user the way [LoginPage] does with the same
  /// token. Linking preserves the session's user id, so anything already
  /// written under it (e.g. this rider's support chat, still anonymous at
  /// this point) stays intact instead of being orphaned under a swapped-out
  /// user. See `SupportAccountLinkCard`'s file header for the full story.
  Future<void> linkGoogleIdentity({required String idToken, String? accessToken}) async {
    // See beginEmailLink for why this runs outside the try/catch below.
    await ensureSession();
    try {
      await _client.auth.linkIdentityWithIdToken(
        provider: OAuthProvider.google,
        idToken: idToken,
        accessToken: accessToken,
      );
    } catch (e, s) {
      await recordError(e, s, context: 'FeedbackSubmissionService.linkGoogleIdentity');
      if (_isIdentityAlreadyLinked(e)) {
        throw const IdentityAlreadyLinkedException('This Google account is already linked to another user');
      }
      throw const FeedbackSubmissionException('Failed to link your Google account');
    }
  }

  /// Links an Apple identity — its [idToken]/[nonce] obtained via
  /// [fetchAppleIdToken] — onto the CURRENT session. See
  /// [linkGoogleIdentity] for why this links rather than signs in.
  Future<void> linkAppleIdentity({required String idToken, required String nonce}) async {
    // See beginEmailLink for why this runs outside the try/catch below.
    await ensureSession();
    try {
      await _client.auth.linkIdentityWithIdToken(
        provider: OAuthProvider.apple,
        idToken: idToken,
        nonce: nonce,
      );
    } catch (e, s) {
      await recordError(e, s, context: 'FeedbackSubmissionService.linkAppleIdentity');
      if (_isIdentityAlreadyLinked(e)) {
        throw const IdentityAlreadyLinkedException('This Apple account is already linked to another user');
      }
      throw const FeedbackSubmissionException('Failed to link your Apple account');
    }
  }

  /// Links [provider] onto the CURRENT session via Supabase's browser-
  /// redirect OAuth identity linking (`GoTrueClient.linkIdentity`, which
  /// hits `/user/identities/authorize` with the session's own JWT attached)
  /// — the path for every provider with no native id-token SDK on this
  /// platform: GitHub and Facebook always, and Google/Apple wherever
  /// `supportsNative*SignIn` is false. Like [linkGoogleIdentity]/
  /// [linkAppleIdentity], this attaches the identity to whatever session is
  /// already there — anonymous or not — instead of signing in as a
  /// different user the way `LoginPage.signInWithOAuth` does with the same
  /// provider. Unlike those two methods, though, the returned `Future`
  /// only resolves once the OAuth browser tab has been launched; actual
  /// completion arrives later through the app's existing deep-link
  /// handling and shows up on [authStateChanges] — exactly like
  /// `LoginPage`'s own `signInWithOAuth` calls for these same providers,
  /// which don't await completion inline either.
  Future<void> linkOAuthIdentity(OAuthProvider provider) async {
    // See beginEmailLink for why this runs outside the try/catch below.
    await ensureSession();
    try {
      await _client.auth.linkIdentity(
        provider,
        redirectTo: kIsWeb ? null : 'bikecontrol://login/',
        authScreenLaunchMode: kIsWeb ? LaunchMode.platformDefault : LaunchMode.externalApplication,
      );
    } catch (e, s) {
      await recordError(e, s, context: 'FeedbackSubmissionService.linkOAuthIdentity.${provider.name}');
      throw FeedbackSubmissionException('Failed to link your ${provider.name} account');
    }
  }

  /// The session's own auth-state stream. [SupportAccountLinkCard] listens
  /// on this for the moment a [linkOAuthIdentity] redirect that's still
  /// pending in the browser actually completes and the session stops being
  /// anonymous — the id-token methods above don't need it since they
  /// already know synchronously.
  Stream<AuthState> get authStateChanges => _client.auth.onAuthStateChange;

  /// Ensures the client has a session, signing in anonymously if it has
  /// none. Public so other callers that need "a session, any session"
  /// before their own request — e.g. [SupportChatPage] sending a message
  /// with no rider signed in yet — can reuse this instead of duplicating
  /// the signInAnonymously + error-wrapping dance.
  Future<void> ensureSession() async {
    if (_client.auth.currentSession != null) return;
    try {
      await _client.auth.signInAnonymously();
    } catch (e, s) {
      await recordError(e, s, context: 'FeedbackSubmissionService.ensureSession');
      throw const FeedbackSubmissionException('Failed to start a session');
    }
  }

  Future<Map<String, dynamic>> _contextFields() async {
    final fields = <String, dynamic>{'platform': _platform()};

    try {
      fields['locale'] = Intl.getCurrentLocale();
    } catch (e, s) {
      await recordError(e, s, context: 'FeedbackSubmissionService.submit.locale');
    }

    try {
      final info = await PackageInfo.fromPlatform();
      fields['app_version'] = info.version;
    } catch (e, s) {
      await recordError(e, s, context: 'FeedbackSubmissionService.submit.packageInfo');
    }

    return fields;
  }

  String _platform() {
    if (kIsWeb) return 'web';
    return Platform.operatingSystem;
  }
}
