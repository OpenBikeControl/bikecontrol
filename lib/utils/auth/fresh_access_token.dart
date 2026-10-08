import 'package:supabase_flutter/supabase_flutter.dart';

/// Refresh this long before the access token actually expires, so a request
/// in flight does not land at the server just after `exp`.
const Duration accessTokenRefreshMargin = Duration(seconds: 30);

/// Whether [session]'s access token is expired or expires within [margin].
bool accessTokenNeedsRefresh(
  Session session, {
  DateTime? now,
  Duration margin = accessTokenRefreshMargin,
}) {
  final expiresAt = session.expiresAt;
  if (expiresAt == null) return false;
  final expiry = DateTime.fromMillisecondsSinceEpoch(expiresAt * 1000);
  return (now ?? DateTime.now()).add(margin).isAfter(expiry);
}

/// The current access token, refreshed first if it is expired or about to be.
///
/// Only needed for requests that bypass the Supabase client's own HTTP stack
/// (raw `http` calls). `functions.invoke` already attaches a refreshed token
/// as long as no explicit `Authorization` header is passed.
Future<String> freshAccessToken(GoTrueClient auth) async {
  final session = auth.currentSession;
  if (session == null) {
    throw AuthSessionMissingException();
  }
  if (!accessTokenNeedsRefresh(session)) {
    return session.accessToken;
  }
  final refreshed = await auth.refreshSession();
  final token = refreshed.session?.accessToken;
  if (token == null) {
    throw AuthSessionMissingException();
  }
  return token;
}
