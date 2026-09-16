// A non-null Supabase session is not the same as "signed in to an account":
// the support chat creates anonymous sessions on demand, and GoTrue reports
// their email as "" rather than null. These pin what counts as a real account
// and what the Account page shows as its label.
import 'package:bike_control/utils/auth/account_session.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

User _user({
  bool anonymous = false,
  String? email,
  String? phone,
  Map<String, dynamic> userMetadata = const {},
  List<Map<String, dynamic>> identities = const [],
}) {
  return User.fromJson({
    'id': 'user-id',
    'aud': 'authenticated',
    'created_at': '2026-08-24T00:00:00Z',
    'app_metadata': <String, dynamic>{},
    'user_metadata': userMetadata,
    'is_anonymous': anonymous,
    if (email != null) 'email': email,
    if (phone != null) 'phone': phone,
    'identities': identities,
  })!;
}

Map<String, dynamic> _identity(String provider, {Map<String, dynamic> data = const {}}) => {
  'id': 'identity-$provider',
  'user_id': 'user-id',
  'identity_id': 'identity-$provider',
  'identity_data': data,
  'provider': provider,
  'created_at': '2026-08-24T00:00:00Z',
  'last_sign_in_at': '2026-08-24T00:00:00Z',
  'updated_at': '2026-08-24T00:00:00Z',
};

void main() {
  group('hasAccount', () {
    test('is false without a user', () {
      expect(hasAccount(null), isFalse);
    });

    test('is false for an anonymous user, even though GoTrue reports its email as ""', () {
      expect(hasAccount(_user(anonymous: true, email: '')), isFalse);
    });

    test('is true for a user with an email', () {
      expect(hasAccount(_user(email: 'rider@example.com', identities: [_identity('email')])), isTrue);
    });

    test('is false for a non-anonymous user with no email and no identity at all', () {
      expect(hasAccount(_user(email: '')), isFalse);
    });

    test('is true for an OAuth user whose provider shared no email', () {
      expect(hasAccount(_user(email: '', identities: [_identity('github')])), isTrue);
    });
  });

  group('accountLabel', () {
    test('prefers the email', () {
      expect(accountLabel(_user(email: 'rider@example.com')), 'rider@example.com');
    });

    test('falls back to an email from one of the identities', () {
      expect(
        accountLabel(
          _user(
            email: '',
            identities: [
              _identity('github', data: {'email': 'gh@example.com'}),
            ],
          ),
        ),
        'gh@example.com',
      );
    });

    test('falls back to the profile name', () {
      expect(
        accountLabel(_user(email: '', userMetadata: {'full_name': 'Rider One'}, identities: [_identity('github')])),
        'Rider One',
      );
      expect(
        accountLabel(_user(email: '', userMetadata: {'user_name': 'rider1'}, identities: [_identity('github')])),
        'rider1',
      );
    });

    test('falls back to the phone number', () {
      expect(accountLabel(_user(email: '', phone: '+491234')), '+491234');
    });

    test('never returns an empty label', () {
      expect(accountLabel(_user(email: '', phone: '')), 'user-id');
    });
  });
}
