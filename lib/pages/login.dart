import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:sign_in_button/sign_in_button.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../utils/core.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(32.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('Please sign in to continue'),
          const SizedBox(height: 16),
          SignInButton(
            Buttons.google,
            onPressed: _nativeGoogleSignIn,
          ),
          SignInButton(
            Buttons.apple,
            onPressed: _signInWithApple,
          ),
          Button.secondary(
            child: Text('Logout'),
            onPressed: () {
              core.supabase.auth.signOut();
            },
          ),
        ],
      ),
    );
  }

  Future<AuthResponse?> _nativeGoogleSignIn() async {
    if (Platform.isAndroid || Platform.isIOS) {
      /// Web Client ID that you registered with Google Cloud.
      const webClientId = '709945926587-bgk7j9qc86t7nuemu100ngvl9c7irv9k.apps.googleusercontent.com';

      /// iOS Client ID that you registered with Google Cloud.
      const iosClientId = '709945926587-0iierajthibf4vhqf85fc7bbpgbdgua2.apps.googleusercontent.com';
      final scopes = ['email'];
      final googleSignIn = GoogleSignIn.instance;
      await googleSignIn.initialize(
        serverClientId: webClientId,
        clientId: iosClientId,
      );
      GoogleSignInAccount? googleUser = await googleSignIn.attemptLightweightAuthentication(reportAllExceptions: true);
      googleUser ??= await googleSignIn.authenticate();

      /// Authorization is required to obtain the access token with the appropriate scopes for Supabase authentication,
      /// while also granting permission to access user information.
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
      return response;
    } else {
      await core.supabase.auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo: kIsWeb ? null : 'bikecontrol://login/',
        authScreenLaunchMode: kIsWeb
            ? LaunchMode.platformDefault
            : LaunchMode.externalApplication, // Launch the auth screen in a new webview on mobile.
      );
      return null;
    }
  }

  /// Performs Apple sign in on iOS or macOS
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
      return authResponse;
    } else {
      await core.supabase.auth.signInWithOAuth(
        OAuthProvider.apple,
        redirectTo: kIsWeb ? null : 'bikecontrol://login/',
        authScreenLaunchMode: kIsWeb ? LaunchMode.platformDefault : LaunchMode.externalApplication,
      );
      return null;
    }
  }
}
