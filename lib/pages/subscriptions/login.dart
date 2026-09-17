import 'dart:async';
import 'dart:io';

import 'package:bike_control/gen/l10n.dart';
import 'package:bike_control/pages/subscriptions/email_login_form.dart';
import 'package:bike_control/services/email_otp_auth_service.dart';
import 'package:bike_control/utils/auth/account_session.dart';
import 'package:bike_control/utils/auth/social_sign_in.dart';
import 'package:bike_control/utils/core.dart';
import 'package:bike_control/utils/i18n_extension.dart';
import 'package:bike_control/utils/iap/iap_manager.dart';
import 'package:bike_control/utils/requirements/windows.dart';
import 'package:bike_control/widgets/menu.dart';
import 'package:bike_control/widgets/title.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:sign_in_button/sign_in_button.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:url_launcher/url_launcher_string.dart';

class LoginPage extends StatefulWidget {
  final bool pushed;
  final VoidCallback? onBack;

  /// Test seam; defaults to the app's Supabase client.
  final SupabaseClient? client;

  const LoginPage({super.key, required this.pushed, this.onBack, this.client});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final IAPManager _iapManager = IAPManager.instance;

  SupabaseClient get _client => widget.client ?? core.supabase;

  @override
  Widget build(BuildContext context) {
    // An anonymous session (created on demand by the support chat) is not an
    // account — offer the sign-in options; signing in replaces that session.
    final session = _client.auth.currentSession;
    final signedIn = session != null && hasAccount(session.user);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 820),
          child: signedIn ? _buildSignedIn(context, session) : _buildSignedOut(context),
        ),
      ),
    );
  }

  Widget _buildSignedOut(BuildContext context) {
    return Column(
      spacing: 32,
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primary.withAlpha(20),
            shape: BoxShape.circle,
          ),
          child: Icon(
            Icons.account_circle,
            size: 64,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
        Column(
          spacing: 8,
          children: [
            Text(
              'BikeControl',
            ).large,
            Text(
              AppLocalizations.of(context).signInToSyncYourSubscriptionAndManageDevices,
            ).small.muted,
          ],
        ),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              spacing: 16,
              mainAxisSize: MainAxisSize.min,
              children: [
                SignInButton(
                  Buttons.google,
                  onPressed: _nativeGoogleSignIn,
                ),
                SignInButton(
                  Buttons.apple,
                  onPressed: _signInWithApple,
                ),
                SignInButton(
                  Buttons.gitHub,
                  onPressed: _signInWithGithub,
                ),
                SignInButton(
                  Buttons.facebook,
                  onPressed: _signInWithFacebook,
                ),
                Divider(child: Text(context.i18n.orSeparator).small.muted),
                EmailLoginForm(
                  auth: SupabaseEmailOtpAuth(supabase: _client),
                  onSignedIn: _afterSignIn,
                ),
              ],
            ),
          ),
        ),
        if (!kIsWeb && widget.pushed)
          Button.ghost(
            leading: const Icon(Icons.mail_outline, size: 16),
            onPressed: _openMailFallback,
            child: Text(context.i18n.dontWantToSignInWriteAMail),
          ),
        Text.rich(
          TextSpan(
            children: [
              TextSpan(
                text: AppLocalizations.of(context)
                    .bySigningInYouAgreeToOur(
                      AppLocalizations.of(context).privacyPolicy,
                    )
                    .split(AppLocalizations.of(context).privacyPolicy)
                    .first,
              ),
              TextSpan(
                text: AppLocalizations.of(context).privacyPolicy,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.primary,
                ),
                recognizer: TapGestureRecognizer()
                  ..onTap = () => launchUrlString('https://bikecontrol.app/privacy-policy'),
              ),
              TextSpan(
                text: AppLocalizations.of(context)
                    .bySigningInYouAgreeToOur(
                      AppLocalizations.of(context).privacyPolicy,
                    )
                    .split(AppLocalizations.of(context).privacyPolicy)
                    .last,
              ),
            ],
          ),
          textAlign: TextAlign.center,
        ).small.muted,
        if (kDebugMode && Platform.isWindows)
          Button.secondary(
            child: const Text('Register protocol handler'),
            onPressed: () {
              WindowsProtocolHandler().register('bikecontrol');
            },
          ),
      ],
    );
  }

  Widget _buildSignedIn(BuildContext context, Session session) {
    return Column(
      spacing: 16,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Card(
          child: Column(
            spacing: 16,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.green.withAlpha(30),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.check_circle, size: 28, color: Colors.green),
                  ),
                  const SizedBox(width: 16),
                  Flexible(
                    child: Text(accountLabel(session.user)).small.bold,
                  ),
                ],
              ),
              Button.secondary(
                child: Text(AppLocalizations.of(context).logout),
                onPressed: () async {
                  await _client.auth.signOut();
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Leaves the sign-in screen the way it was opened: a pushed page pops, an
  /// embedded one hands control back to its host.
  void _afterSignIn() {
    if (!mounted) return;
    setState(() {});
    if (widget.pushed) {
      Navigator.pop(context);
    } else {
      widget.onBack?.call();
    }
  }

  Future<AuthResponse?> _nativeGoogleSignIn() async {
    if (supportsNativeGoogleSignIn) {
      final token = await fetchGoogleIdToken();
      final response = await _client.auth.signInWithIdToken(
        provider: OAuthProvider.google,
        idToken: token.idToken,
        accessToken: token.accessToken,
      );

      _afterSignIn();
      return response;
    } else {
      await _client.auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo: kIsWeb ? null : 'bikecontrol://login/',
        authScreenLaunchMode: kIsWeb ? LaunchMode.platformDefault : LaunchMode.externalApplication,
      );
      _afterSignIn();
      return null;
    }
  }

  Future<AuthResponse?> _signInWithApple() async {
    if (supportsNativeAppleSignIn) {
      final token = await fetchAppleIdToken();
      final authResponse = await _client.auth.signInWithIdToken(
        provider: OAuthProvider.apple,
        idToken: token.idToken,
        nonce: token.rawNonce,
      );

      _afterSignIn();
      return authResponse;
    } else {
      await _client.auth.signInWithOAuth(
        OAuthProvider.apple,
        redirectTo: kIsWeb ? null : 'bikecontrol://login/',
        authScreenLaunchMode: kIsWeb ? LaunchMode.platformDefault : LaunchMode.externalApplication,
      );
      _afterSignIn();
      return null;
    }
  }

  Future<void> _signInWithGithub() async {
    await _client.auth.signInWithOAuth(
      OAuthProvider.github,
      redirectTo: kIsWeb ? null : 'bikecontrol://login/',
      authScreenLaunchMode: kIsWeb ? LaunchMode.platformDefault : LaunchMode.externalApplication,
    );
  }

  Future<void> _signInWithFacebook() async {
    await _client.auth.signInWithOAuth(
      OAuthProvider.facebook,
      redirectTo: kIsWeb ? null : 'bikecontrol://login/',
      authScreenLaunchMode: kIsWeb ? LaunchMode.platformDefault : LaunchMode.externalApplication,
    );
  }

  Future<void> _openMailFallback() async {
    final isFromStore = (Platform.isAndroid ? isFromPlayStore == true : Platform.isIOS);
    final suffix = isFromStore ? '' : '-sw';
    final email = Uri.encodeComponent('jonas$suffix@bikecontrol.app');
    final subject = Uri.encodeComponent(
      context.i18n.helpRequested(packageInfoValue?.version ?? ''),
    );
    final dbg = await debugText();
    final body = Uri.encodeComponent('\n\n$dbg');
    final mail = Uri.parse('mailto:$email?subject=$subject&body=$body');
    await launchUrl(mail);
  }
}
