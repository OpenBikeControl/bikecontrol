import 'package:supabase_flutter/supabase_flutter.dart';

/// Whether [user] is a real account the rider signed into, as opposed to no
/// user at all or the anonymous session the support chat and feedback flows
/// create on demand.
///
/// A non-null session alone is not enough: an anonymous user is a real
/// GoTrue user with a session, and GoTrue reports its email as `""`, not
/// null. A user counts as an account when it is not anonymous and has either
/// an email or at least one sign-in identity (an OAuth provider that shared
/// no email still is an account).
bool hasAccount(User? user) {
  if (user == null || user.isAnonymous) return false;
  if (_nonEmpty(user.email) != null) return true;
  return _identities(user).isNotEmpty;
}

/// A readable, never-empty label for [user] on the Account page: the email,
/// else an email or name from its sign-in identities or profile, else the
/// phone number, else the user id.
String accountLabel(User user) {
  final identityData = _identities(user).map((i) => i.identityData ?? const <String, dynamic>{});
  final candidates = <Object?>[
    user.email,
    for (final data in identityData) data['email'],
    for (final key in const ['full_name', 'name', 'user_name', 'preferred_username']) user.userMetadata?[key],
    user.phone,
  ];
  for (final candidate in candidates) {
    final value = candidate is String ? _nonEmpty(candidate) : null;
    if (value != null) return value;
  }
  return user.id;
}

Iterable<UserIdentity> _identities(User user) =>
    (user.identities ?? const <UserIdentity>[]).where((i) => i.provider != 'anonymous');

String? _nonEmpty(String? value) {
  final trimmed = value?.trim();
  return (trimmed == null || trimmed.isEmpty) ? null : trimmed;
}
