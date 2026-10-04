// Email sign-in: the rider types an address, Supabase mails a six-digit code,
// the rider types the code back. No deep link is involved — that is the whole
// point of the code-only flow, because `bikecontrol://` round-trips are
// unreliable on Windows/Linux and mail scanners burn one-shot links.
import 'package:bike_control/gen/l10n.dart';
import 'package:bike_control/main.dart' show OtherLocalizationsDelegate;
import 'package:bike_control/pages/subscriptions/email_login_form.dart';
import 'package:bike_control/services/email_otp_auth_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'widget_snapshot.dart';

/// Stands in for Supabase's auth endpoints: records what the form asked for and
/// replays whatever the test told it to answer.
class _FakeEmailOtpAuth implements EmailOtpAuth {
  final List<String> sentTo = <String>[];
  final List<({String email, String code})> verified = <({String email, String code})>[];

  Object? sendError;
  Object? verifyError;

  @override
  Future<void> sendCode(String email) async {
    sentTo.add(email);
    if (sendError != null) throw sendError!;
  }

  @override
  Future<void> verifyCode({required String email, required String code}) async {
    verified.add((email: email, code: code));
    if (verifyError != null) throw verifyError!;
  }
}

Future<void> main() async {
  await ensureSnapshotHarness();

  late _FakeEmailOtpAuth auth;
  late int signedIn;

  setUp(() {
    auth = _FakeEmailOtpAuth();
    signedIn = 0;
  });

  /// The real form waits a minute; the binding these tests run under pumps in
  /// real time, so shrink it rather than sitting out the wait.
  const cooldown = Duration(milliseconds: 300);

  Future<void> pumpForm(WidgetTester tester) async {
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
        home: Scaffold(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: EmailLoginForm(
              auth: auth,
              cooldown: cooldown,
              onSignedIn: () => signedIn++,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> submitEmail(WidgetTester tester, String email) async {
    await tester.enterText(find.byKey(EmailLoginForm.emailFieldKey), email);
    await tester.tap(find.byKey(EmailLoginForm.sendButtonKey));
    await tester.pumpAndSettle();
  }

  /// Types [code] digit by digit into the OTP boxes, which are ordinary
  /// text fields that hand focus on to the next box as each one fills.
  Future<void> enterCode(WidgetTester tester, String code) async {
    final boxes = find.descendant(
      of: find.byKey(EmailLoginForm.codeFieldKey),
      matching: find.byType(TextField),
    );
    for (var i = 0; i < code.length; i++) {
      await tester.enterText(boxes.at(i), code[i]);
      await tester.pump();
    }
    await tester.pumpAndSettle();
  }

  testWidgets('sending a code asks Supabase to mail it and moves to code entry', (tester) async {
    await pumpForm(tester);

    await submitEmail(tester, 'rider@example.com');

    expect(auth.sentTo, <String>['rider@example.com']);
    expect(find.byKey(EmailLoginForm.codeFieldKey), findsOneWidget);
    expect(find.byKey(EmailLoginForm.emailFieldKey), findsNothing);
  });

  testWidgets('an address that is not an email never reaches Supabase', (tester) async {
    await pumpForm(tester);

    await submitEmail(tester, 'rider@');

    expect(auth.sentTo, isEmpty);
    expect(find.byKey(EmailLoginForm.errorKey), findsOneWidget);
    expect(find.byKey(EmailLoginForm.codeFieldKey), findsNothing);
  });

  testWidgets('a whitespace-padded address is trimmed before it is sent', (tester) async {
    await pumpForm(tester);

    await submitEmail(tester, '  Rider@Example.com  ');

    expect(auth.sentTo, <String>['Rider@Example.com']);
  });

  testWidgets('the right code signs the rider in', (tester) async {
    await pumpForm(tester);
    await submitEmail(tester, 'rider@example.com');

    await enterCode(tester, '123456');

    expect(auth.verified, <({String email, String code})>[(email: 'rider@example.com', code: '123456')]);
    expect(signedIn, 1);
  });

  testWidgets('a rejected code keeps the rider on the code screen with an error', (tester) async {
    await pumpForm(tester);
    await submitEmail(tester, 'rider@example.com');
    auth.verifyError = const AuthException('Token has expired or is invalid');

    await enterCode(tester, '000000');

    expect(signedIn, 0);
    expect(find.byKey(EmailLoginForm.codeFieldKey), findsOneWidget);
    expect(find.byKey(EmailLoginForm.errorKey), findsOneWidget);
  });

  testWidgets('a rate-limited send explains the wait instead of the raw error', (tester) async {
    await pumpForm(tester);
    auth.sendError = AuthApiException('over_email_send_rate_limit', statusCode: '429');

    await submitEmail(tester, 'rider@example.com');

    expect(find.byKey(EmailLoginForm.codeFieldKey), findsNothing);
    expect(
      find.text(AppLocalizations.current.tooManyCodeRequestsPleaseWait),
      findsOneWidget,
    );
  });

  testWidgets('the rider can go back and use a different address', (tester) async {
    await pumpForm(tester);
    await submitEmail(tester, 'typo@example.com');

    await tester.tap(find.byKey(EmailLoginForm.changeEmailKey));
    await tester.pumpAndSettle();

    expect(find.byKey(EmailLoginForm.emailFieldKey), findsOneWidget);
    expect(find.byKey(EmailLoginForm.codeFieldKey), findsNothing);
  });

  testWidgets('resending is blocked until the cooldown runs out', (tester) async {
    await pumpForm(tester);
    await submitEmail(tester, 'rider@example.com');

    await tester.tap(find.byKey(EmailLoginForm.resendButtonKey));
    await tester.pumpAndSettle();
    expect(auth.sentTo, hasLength(1), reason: 'still inside the cooldown');

    await tester.pump(cooldown);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(EmailLoginForm.resendButtonKey));
    await tester.pumpAndSettle();

    expect(auth.sentTo, hasLength(2));
  });

  testWidgets('code sent: the resend countdown and "use a different address" sit centred under the code', (tester) async {
    await pumpForm(tester);
    await submitEmail(tester, 'rider@example.com');

    final centre = tester.getCenter(find.byType(EmailLoginForm)).dx;
    // The label itself, not just a button stretched across the form.
    for (final key in [EmailLoginForm.resendButtonKey, EmailLoginForm.changeEmailKey]) {
      final label = find.descendant(of: find.byKey(key), matching: find.byType(RichText)).first;
      expect(tester.getCenter(label).dx, moreOrLessEquals(centre, epsilon: 1));
    }
  });
}
