import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:bike_control/gen/l10n.dart';
import 'package:bike_control/utils/core.dart';
import 'package:bike_control/utils/iap/iap_manager.dart';
import 'package:bike_control/utils/requirements/windows.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:sign_in_button/sign_in_button.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class LoginPage extends StatefulWidget {
  final bool pushed;
  final VoidCallback? onBack;
  const LoginPage({super.key, required this.pushed, this.onBack});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final IAPManager _iapManager = IAPManager.instance;

  @override
  Widget build(BuildContext context) {
    final session = core.supabase.auth.currentSession;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 820),
          child: session == null ? _buildSignedOut(context) : _buildSignedIn(context, session),
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
              ],
            ),
          ),
        ),
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
    final hasActiveSubscription = _iapManager.hasActiveSubscription;
    final isPremiumEnabled = _iapManager.isProEnabled;
    final isRegisteredDevice = _iapManager.entitlements.isRegisteredDevice;
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
                  Text(
                    session.user.email ?? session.user.id,
                  ).small.bold,
                ],
              ),
              Button.secondary(
                child: Text(AppLocalizations.of(context).logout),
                onPressed: () async {
                  await core.supabase.auth.signOut();
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<AuthResponse?> _nativeGoogleSignIn() async {
    if (Platform.isAndroid || Platform.isIOS) {
      const webClientId = '709945926587-bgk7j9qc86t7nuemu100ngvl9c7irv9k.apps.googleusercontent.com';
      const iosClientId = '709945926587-0iierajthibf4vhqf85fc7bbpgbdgua2.apps.googleusercontent.com';
      final scopes = ['email'];
      final googleSignIn = GoogleSignIn.instance;
      await googleSignIn.initialize(
        serverClientId: webClientId,
        clientId: iosClientId,
      );
      GoogleSignInAccount? googleUser = await googleSignIn.attemptLightweightAuthentication(reportAllExceptions: true);
      googleUser ??= await googleSignIn.authenticate();

      final authorization =
          await googleUser.authorizationClient.authorizationForScopes(scopes) ??
          await googleUser.authorizationClient.authorizeScopes(scopes);
      final idToken = googleUser.authentication.idToken;
      if (idToken == null) {
        throw AuthException('No ID Token found.');
      }
      final response = await core.supabase.auth.signInWithIdToken(
        provider: OAuthProvider.google,
        idToken: idToken,
        accessToken: authorization.accessToken,
      );

      if (widget.pushed) {
        Navigator.pop(context);
      } else {
        widget.onBack?.call();
      }
      return response;
    } else {
      await core.supabase.auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo: kIsWeb ? null : 'bikecontrol://login/',
        authScreenLaunchMode: kIsWeb ? LaunchMode.platformDefault : LaunchMode.externalApplication,
      );
      if (widget.pushed) {
        Navigator.pop(context);
      } else {
        widget.onBack?.call();
      }
      return null;
    }
  }

  Future<AuthResponse?> _signInWithApple() async {
    if (Platform.isIOS || Platform.isMacOS) {
      final rawNonce = core.supabase.auth.generateRawNonce();
      final hashedNonce = sha256.convert(utf8.encode(rawNonce)).toString();

      final credential = await SignInWithApple.getAppleIDCredential(
        scopes: [AppleIDAuthorizationScopes.email],
        nonce: hashedNonce,
      );
      final idToken = credential.identityToken;
      if (idToken == null) {
        throw const AuthException('Could not find ID Token from generated credential.');
      }
      final authResponse = await core.supabase.auth.signInWithIdToken(
        provider: OAuthProvider.apple,
        idToken: idToken,
        nonce: rawNonce,
      );

      if (widget.pushed) {
        Navigator.pop(context);
      } else {
        widget.onBack?.call();
      }
      return authResponse;
    } else {
      await core.supabase.auth.signInWithOAuth(
        OAuthProvider.apple,
        redirectTo: kIsWeb ? null : 'bikecontrol://login/',
        authScreenLaunchMode: kIsWeb ? LaunchMode.platformDefault : LaunchMode.externalApplication,
      );
      if (widget.pushed) {
        Navigator.pop(context);
      } else {
        widget.onBack?.call();
      }
      return null;
    }
  }

  Future<void> _signInWithGithub() async {
    await core.supabase.auth.signInWithOAuth(
      OAuthProvider.github,
      redirectTo: kIsWeb ? null : 'bikecontrol://login/',
      authScreenLaunchMode: kIsWeb ? LaunchMode.platformDefault : LaunchMode.externalApplication,
    );
  }

  Future<void> _signInWithFacebook() async {
    await core.supabase.auth.signInWithOAuth(
      OAuthProvider.facebook,
      redirectTo: kIsWeb ? null : 'bikecontrol://login/',
      authScreenLaunchMode: kIsWeb ? LaunchMode.platformDefault : LaunchMode.externalApplication,
    );
  }
}
