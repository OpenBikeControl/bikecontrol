import 'dart:io';

import 'package:bike_control/widgets/ui/type_scale.dart';
import 'package:bike_control/gen/l10n.dart';
import 'package:bike_control/main.dart';
import 'package:bike_control/pages/subscriptions/email_login_form.dart';
import 'package:bike_control/services/email_otp_auth_service.dart';
import 'package:bike_control/utils/auth/account_session.dart';
import 'package:bike_control/utils/auth/social_sign_in.dart';
import 'package:bike_control/utils/i18n_extension.dart';
import 'package:bike_control/utils/requirements/windows.dart';
import 'package:bike_control/widgets/menu.dart' show debugText;
import 'package:bike_control/widgets/title.dart' show isFromPlayStore, packageInfoValue;
import 'package:bike_control/widgets/ui/app_theme.dart';
import 'package:bike_control/widgets/ui/bk_grouped_section.dart';
import 'package:bike_control/widgets/ui/bk_touch_target.dart';
import 'package:bike_control/widgets/ui/colors.dart';
import 'package:bike_control/widgets/ui/small_progress_indicator.dart';
import 'package:flutter/foundation.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:sign_in_button/sign_in_button.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

/// The Konto group of Plan & account. Signed out: Apple, Google and the
/// emailed code, Apple and Google in their vendors' branded buttons, with GitHub and Facebook
/// behind "More options"; the group steps forward in place once a code is
/// sent. Signed in: who, how, and Sign out.
class AccountSection extends StatefulWidget {
  const AccountSection({
    super.key,
    required this.client,
    required this.emailAuth,
    required this.signInWith,
    required this.onSignOut,
    required this.onSignedIn,
    required this.note,
  });

  final SupabaseClient client;
  final EmailOtpAuth emailAuth;
  final Future<void> Function(OAuthProvider provider) signInWith;
  final Future<void> Function() onSignOut;
  final VoidCallback onSignedIn;

  /// What signing in is for, here: the line above the buttons.
  final String note;

  @override
  State<AccountSection> createState() => _AccountSectionState();
}

class _AccountSectionState extends State<AccountSection> {
  bool _moreOptions = false;
  bool _codeSent = false;
  OAuthProvider? _busy;
  String? _error;
  bool _signingOut = false;

  Future<void> _signIn(OAuthProvider provider) async {
    if (_busy != null) return;
    setState(() {
      _busy = provider;
      _error = null;
    });
    try {
      await widget.signInWith(provider);
      if (mounted) widget.onSignedIn();
    } catch (e, s) {
      if (isSignInCancellation(e)) return;
      recordError(e, s, context: 'Sign in with ${provider.name}');
      if (mounted) setState(() => _error = AppLocalizations.of(context).signInFailed);
    } finally {
      if (mounted) setState(() => _busy = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final session = widget.client.auth.currentSession;
    // The support chat's anonymous session is not an account.
    if (session != null && hasAccount(session.user)) return _signedIn(context, session.user);

    final cs = Theme.of(context).colorScheme;
    // Apple first where it is the platform's own sign-in.
    final applePlatform = defaultTargetPlatform == TargetPlatform.iOS || defaultTargetPlatform == TargetPlatform.macOS;
    final primary = applePlatform
        ? [OAuthProvider.apple, OAuthProvider.google]
        : [OAuthProvider.google, OAuthProvider.apple];

    return BkGroupedSection(
      header: l10n.account,
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: 10,
            children: [
              if (!_codeSent) ...[
                Text(widget.note, style: context.typography.small.copyWith(color: cs.mutedForeground)),
                const Gap(2),
                for (final provider in primary) _providerButton(context, provider),
                Center(
                  child: BkTouchTarget(
                    child: Button.ghost(
                      key: const ValueKey('plan-more-options'),
                      onPressed: () => setState(() => _moreOptions = !_moreOptions),
                      trailing: Icon(_moreOptions ? LucideIcons.chevronUp : LucideIcons.chevronDown, size: 16),
                      child: Semantics(
                        expanded: _moreOptions,
                        child: Text(
                          l10n.moreSignInOptions,
                          style: context.typography.small.copyWith(
                            color: bkAccentText(context),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                if (_moreOptions) ...[
                  _providerButton(context, OAuthProvider.github),
                  _providerButton(context, OAuthProvider.facebook),
                ],
                if (_error != null) _errorLine(context, _error!),
                Row(
                  spacing: 12,
                  children: [
                    const Expanded(child: Divider()),
                    Text(
                      context.i18n.orSeparator,
                      style: context.typography.xSmall.copyWith(color: cs.mutedForeground),
                    ),
                    const Expanded(child: Divider()),
                  ],
                ),
              ],
              EmailLoginForm(
                // Keyed: the rows above it come and go as the code is sent.
                key: const ValueKey('plan-email-form'),
                auth: widget.emailAuth,
                onSignedIn: widget.onSignedIn,
                onCodeSentChanged: (sent) {
                  setState(() {
                    _codeSent = sent;
                    _error = null;
                  });
                  // The code field takes the keyboard: bring the group up.
                  if (sent) {
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (!mounted) return;
                      Scrollable.ensureVisible(
                        context,
                        duration: MediaQuery.of(context).disableAnimations
                            ? Duration.zero
                            : const Duration(milliseconds: 250),
                      );
                    });
                  }
                },
              ),
              if (!_codeSent) _privacyLine(context),
              if (kDebugMode && !kIsWeb && Platform.isWindows)
                Button.secondary(
                  child: const Text('Register protocol handler'),
                  onPressed: () => WindowsProtocolHandler().register('bikecontrol'),
                ),
            ],
          ),
        ),
      ],
    );
  }

  /// The vendors' own sign-in buttons: Apple and Google require their
  /// branded button (logo, colours, approved localized title), so these keep
  /// the vendor styling instead of the app's pills. Apple's is white on the
  /// dark theme and black on the light one, as Apple's guidelines ask.
  Widget _providerButton(BuildContext context, OAuthProvider provider) {
    final l10n = AppLocalizations.of(context);
    final dark = Theme.of(context).brightness == Brightness.dark;
    final (button, label) = switch (provider) {
      OAuthProvider.apple => (dark ? Buttons.apple : Buttons.appleDark, l10n.signInWithApple),
      OAuthProvider.google => (Buttons.google, l10n.signInWithGoogle),
      OAuthProvider.github => (Buttons.gitHub, l10n.signInWithGithub),
      _ => (Buttons.facebook, l10n.signInWithFacebook),
    };
    return SizedBox(
      key: ValueKey('plan-sign-in-${provider.name}'),
      height: 48,
      child: SignInButton(
        button,
        text: label,
        onPressed: () => _signIn(provider),
      ),
    );
  }

  Widget _errorLine(BuildContext context, String message) {
    final danger = BkStatusColors.of(context).danger;
    return Semantics(
      liveRegion: true,
      child: Row(
        key: const ValueKey('plan-sign-in-error'),
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 8,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Icon(LucideIcons.circleAlert, size: 16, color: danger),
          ),
          Expanded(
            child: Text(message, style: context.typography.small.copyWith(color: danger)),
          ),
        ],
      ),
    );
  }

  Widget _privacyLine(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;
    final sentence = l10n.bySigningInYouAgreeToOur(l10n.privacyPolicy);
    final at = sentence.indexOf(l10n.privacyPolicy);
    final muted = context.typography.xSmall.copyWith(color: cs.mutedForeground);
    if (at < 0) return Text(sentence, textAlign: TextAlign.center, style: muted);
    return Text.rich(
      TextSpan(
        style: muted,
        children: [
          TextSpan(text: sentence.substring(0, at)),
          WidgetSpan(
            alignment: PlaceholderAlignment.baseline,
            baseline: TextBaseline.alphabetic,
            child: Button.link(
              style: const ButtonStyle.link().withPadding(padding: EdgeInsets.zero),
              onPressed: () => launchUrl(Uri.parse('https://bikecontrol.app/privacy-policy')),
              child: Text(
                l10n.privacyPolicy,
                style: context.typography.xSmall.copyWith(color: bkAccentText(context)),
              ),
            ),
          ),
          TextSpan(text: sentence.substring(at + l10n.privacyPolicy.length)),
        ],
      ),
      textAlign: TextAlign.center,
    );
  }

  Widget _signedIn(BuildContext context, User user) {
    final l10n = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;
    final label = accountLabel(user);
    final provider = _providerLabel(l10n, user);
    return BkGroupedSection(
      header: l10n.account,
      children: [
        ConstrainedBox(
          constraints: const BoxConstraints(minHeight: BkGroupedRow.minHeight),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: BkGroupedSection.inset, vertical: 12),
            child: Row(
              children: [
                ExcludeSemantics(
                  child: Container(
                    width: 36,
                    height: 36,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(color: cs.muted, shape: BoxShape.circle),
                    child: Text(
                      label.characters.first.toUpperCase(),
                      style: context.typography.small.copyWith(
                        color: bkAccentText(context),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
                const Gap(BkGroupedRow.gap),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    spacing: 2,
                    children: [
                      // One line, cut at the end: an address must not break
                      // mid-word.
                      Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        softWrap: false,
                        style: context.typography.small.copyWith(fontWeight: FontWeight.w500),
                      ),
                      if (provider != null)
                        Text(
                          l10n.signedInWith(provider),
                          style: context.typography.xSmall.copyWith(color: cs.mutedForeground),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        BkGroupedRow(
          key: const ValueKey('plan-sign-out'),
          title: l10n.logout,
          titleColor: bkAccentText(context),
          trailing: _signingOut ? const SmallProgressIndicator() : null,
          onPressed: _signingOut
              ? null
              : () async {
                  setState(() => _signingOut = true);
                  await widget.onSignOut();
                  if (mounted) setState(() => _signingOut = false);
                },
        ),
      ],
    );
  }

  static String? _providerLabel(AppLocalizations l10n, User user) {
    final provider =
        user.appMetadata['provider'] as String? ??
        (user.identities ?? const <UserIdentity>[]).where((i) => i.provider != 'anonymous').firstOrNull?.provider;
    return switch (provider) {
      'apple' => 'Apple',
      'google' => 'Google',
      'github' => 'GitHub',
      'facebook' => 'Facebook',
      'email' => l10n.signInMethodEmailCode,
      _ => null,
    };
  }
}

/// Opens a mail to support with this app's diagnostics, for a rider who would
/// rather not sign in.
Future<void> openMailFallback(BuildContext context) async {
  try {
    final isFromStore = (Platform.isAndroid ? isFromPlayStore == true : Platform.isIOS);
    final suffix = isFromStore ? '' : '-sw';
    final email = Uri.encodeComponent('jonas$suffix@bikecontrol.app');
    final subject = Uri.encodeComponent(context.i18n.helpRequested(packageInfoValue?.version ?? ''));
    final dbg = await debugText();
    final body = Uri.encodeComponent('\n\n$dbg');
    await launchUrl(Uri.parse('mailto:$email?subject=$subject&body=$body'));
  } catch (e, s) {
    recordError(e, s, context: 'Plan: mail instead of signing in');
  }
}
