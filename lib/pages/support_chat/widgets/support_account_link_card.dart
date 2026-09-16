import 'dart:async';

import 'package:bike_control/gen/l10n.dart';
import 'package:bike_control/main.dart' show recordError;
import 'package:bike_control/services/feedback_submission_service.dart';
import 'package:bike_control/utils/auth/social_sign_in.dart';
import 'package:bike_control/widgets/ui/small_progress_indicator.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:sign_in_button/sign_in_button.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show AuthState, OAuthProvider;

/// Inline "Get the reply" card offering to link an account to the rider's
/// anonymous support-chat session — email (→ 6-digit code, the same
/// two-phase flow as `FeedbackThanksStep`) or Google/Apple/GitHub/Facebook,
/// the same four providers `LoginPage` offers with no platform gating at
/// all — reusing [FeedbackSubmissionService] for the actual Supabase calls
/// since the account-linking logic isn't feedback-specific.
///
/// Every provider deliberately *links* the identity onto the current
/// session rather than signing in the way `LoginPage` does with the same
/// provider. The chat's session is anonymous and already owns rows (the
/// messages this rider just sent) — a plain sign-in would find-or-create a
/// *different* user for that identity and switch the client to it,
/// orphaning the anonymous chat. Linking keeps the session's user id (and
/// therefore the chat) exactly as it was, just with a permanent identity
/// attached — confirmed by support_account_link_card_test.dart, which
/// asserts the session's user id is unchanged after a simulated link on
/// every path below.
///
/// Two different link mechanisms back that, matching `LoginPage`'s own
/// native-vs-browser-redirect split (see `social_sign_in.dart`) provider by
/// provider and platform by platform:
///  - Where a native id-token SDK exists — Google on Android/iOS, Apple on
///    iOS/macOS — [FeedbackSubmissionService.linkGoogleIdentity]/
///    [FeedbackSubmissionService.linkAppleIdentity] call GoTrue's
///    `linkIdentityWithIdToken` directly, so linking completes
///    synchronously within the same call ([_linkWithGoogleNative]/
///    [_linkWithAppleNative]).
///  - Everywhere else — GitHub and Facebook always (no native SDK for
///    either on any platform here), plus Google/Apple wherever the native
///    path above doesn't apply — [FeedbackSubmissionService.linkOAuthIdentity]
///    drives GoTrue's browser-redirect `linkIdentity` instead: the same
///    mechanism `LoginPage.signInWithOAuth` uses for these providers,
///    except tied to the current session rather than signing in fresh. That
///    call only resolves once the browser tab opens — actual completion
///    arrives later through the app's existing deep-link handling, so
///    [_linkViaOAuthRedirect] doesn't flip `_linked` itself; this widget
///    instead listens on [FeedbackSubmissionService.authStateChanges] for
///    the moment the session stops being anonymous (see
///    [_onAuthStateChange]), exactly how `LoginPage` leaves its own
///    `signInWithOAuth` calls for these providers to the app's normal
///    reactive auth-state handling instead of awaiting completion inline.
///
/// [SupportChatPage] has two entry points that reveal this widget — the
/// post-send prompt and the header's "Sign In" button — and both converge on
/// this one instance, so there is exactly one state machine regardless of
/// which one the rider used.
class SupportAccountLinkCard extends StatefulWidget {
  final FeedbackSubmissionService accountService;

  /// Called once, right after a link/verify succeeds, so the parent can
  /// refresh anything that reads [FeedbackSubmissionService.isAnonymous]
  /// itself (the chat header).
  final VoidCallback? onLinked;

  /// Test seam: replaces the real Google-SDK token fetch — see
  /// support_account_link_card_test.dart.
  final Future<GoogleIdTokenResult> Function()? googleIdTokenFetcher;

  /// Test seam: replaces the real Sign in with Apple token fetch.
  final Future<AppleIdTokenResult> Function()? appleIdTokenFetcher;

  const SupportAccountLinkCard({
    super.key,
    required this.accountService,
    this.onLinked,
    this.googleIdTokenFetcher,
    this.appleIdTokenFetcher,
  });

  @override
  State<SupportAccountLinkCard> createState() => _SupportAccountLinkCardState();
}

class _SupportAccountLinkCardState extends State<SupportAccountLinkCard> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _codeController = TextEditingController();

  /// Null until [_sendLink] succeeds — then holds the address the code was
  /// sent to and the UI switches from the email field to the code field.
  String? _codeSentTo;
  bool _linked = false;
  bool _busy = false;
  bool _failed = false;

  /// Set alongside [_failed] when the identity already belongs to another
  /// account, so the card can tell the rider to sign in with it instead.
  bool _alreadyLinked = false;

  /// Watches for a browser-redirect link (see [_linkViaOAuthRedirect])
  /// completing asynchronously once the deep link brings the app back.
  StreamSubscription<AuthState>? _authStateSub;

  @override
  void initState() {
    super.initState();
    _authStateSub = widget.accountService.authStateChanges.listen(_onAuthStateChange);
  }

  @override
  void dispose() {
    _authStateSub?.cancel();
    _emailController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  /// Fires on every auth-state change, including the id-token links below
  /// (which already flip `_linked` synchronously themselves) — guarded so
  /// this only ever *adds* the redirect-completion case rather than acting
  /// twice for the same link.
  void _onAuthStateChange(AuthState state) {
    if (_linked || !mounted) return;
    if (!widget.accountService.isAnonymous) {
      setState(() {
        _linked = true;
        _busy = false;
      });
      widget.onLinked?.call();
    }
  }

  Future<void> _sendLink() async {
    final email = _emailController.text.trim();
    if (email.isEmpty || _busy) return;
    setState(() {
      _busy = true;
      _failed = false;
      _alreadyLinked = false;
    });
    try {
      await widget.accountService.beginEmailLink(email);
      if (!mounted) return;
      setState(() {
        _codeSentTo = email;
        _busy = false;
      });
    } catch (e, s) {
      await recordError(e, s, context: 'SupportAccountLinkCard.beginEmailLink');
      if (!mounted) return;
      setState(() {
        _busy = false;
        _failed = true;
      });
    }
  }

  Future<void> _verify() async {
    final email = _codeSentTo;
    final code = _codeController.text.trim();
    if (email == null || code.isEmpty || _busy) return;
    setState(() {
      _busy = true;
      _failed = false;
      _alreadyLinked = false;
    });
    try {
      await widget.accountService.confirmEmailLink(email: email, token: code);
      if (!mounted) return;
      setState(() {
        _linked = true;
        _busy = false;
      });
      widget.onLinked?.call();
    } catch (e, s) {
      await recordError(e, s, context: 'SupportAccountLinkCard.confirmEmailLink');
      if (!mounted) return;
      setState(() {
        _busy = false;
        _failed = true;
      });
    }
  }

  // Dispatchers: Google/Apple each pick the native id-token path where it
  // exists on this platform, falling back to the browser-redirect link
  // exactly like LoginPage's own `_nativeGoogleSignIn`/`_signInWithApple`
  // do with the same `supportsNative*SignIn` checks.
  Future<void> _linkWithGoogle() =>
      supportsNativeGoogleSignIn ? _linkWithGoogleNative() : _linkViaOAuthRedirect(OAuthProvider.google);

  Future<void> _linkWithApple() =>
      supportsNativeAppleSignIn ? _linkWithAppleNative() : _linkViaOAuthRedirect(OAuthProvider.apple);

  // Neither has a native SDK integration on any platform here — matching
  // LoginPage's own `_signInWithGithub`/`_signInWithFacebook`, always the
  // browser-redirect link.
  Future<void> _linkWithGithub() => _linkViaOAuthRedirect(OAuthProvider.github);

  Future<void> _linkWithFacebook() => _linkViaOAuthRedirect(OAuthProvider.facebook);

  Future<void> _linkWithGoogleNative() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _failed = false;
      _alreadyLinked = false;
    });
    try {
      final fetch = widget.googleIdTokenFetcher ?? fetchGoogleIdToken;
      final token = await fetch();
      await widget.accountService.linkGoogleIdentity(idToken: token.idToken, accessToken: token.accessToken);
      if (!mounted) return;
      setState(() {
        _linked = true;
        _busy = false;
      });
      widget.onLinked?.call();
    } catch (e, s) {
      await recordError(e, s, context: 'SupportAccountLinkCard.linkGoogleIdentity');
      if (!mounted) return;
      setState(() {
        _busy = false;
        _failed = true;
        _alreadyLinked = e is IdentityAlreadyLinkedException;
      });
    }
  }

  Future<void> _linkWithAppleNative() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _failed = false;
      _alreadyLinked = false;
    });
    try {
      final fetch = widget.appleIdTokenFetcher ?? fetchAppleIdToken;
      final token = await fetch();
      await widget.accountService.linkAppleIdentity(idToken: token.idToken, nonce: token.rawNonce);
      if (!mounted) return;
      setState(() {
        _linked = true;
        _busy = false;
      });
      widget.onLinked?.call();
    } catch (e, s) {
      await recordError(e, s, context: 'SupportAccountLinkCard.linkAppleIdentity');
      if (!mounted) return;
      setState(() {
        _busy = false;
        _failed = true;
        _alreadyLinked = e is IdentityAlreadyLinkedException;
      });
    }
  }

  /// The browser-redirect path for every provider without a native
  /// id-token SDK on this platform — see this file's header. Only resolves
  /// once the OAuth tab has opened, not once the rider has actually
  /// approved it there, so — unlike the two native methods above —
  /// `_linked` isn't set here; [_onAuthStateChange] flips it once the
  /// session stops being anonymous.
  Future<void> _linkViaOAuthRedirect(OAuthProvider provider) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _failed = false;
      _alreadyLinked = false;
    });
    try {
      await widget.accountService.linkOAuthIdentity(provider);
    } catch (e, s) {
      await recordError(e, s, context: 'SupportAccountLinkCard.linkViaOAuthRedirect.${provider.name}');
      if (!mounted) return;
      setState(() {
        _busy = false;
        _failed = true;
      });
      return;
    }
    if (!mounted) return;
    setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;

    if (_linked) {
      return _capped(
        Container(
          key: const ValueKey('support-account-linked'),
          margin: const EdgeInsets.fromLTRB(12, 6, 12, 0),
          padding: const EdgeInsets.all(13),
          decoration: BoxDecoration(
            color: Colors.green.withAlpha(20),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.green),
          ),
          child: Row(
            children: [
              const Icon(LucideIcons.check, size: 16, color: Colors.green),
              const Gap(9),
              Expanded(
                child: Text(
                  l10n.supportAccountLinkedNote,
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Only offered ahead of the email step — once the rider has an email
    // code in flight, let that finish rather than also surfacing the social
    // buttons. Unlike before, this no longer depends on native SDK support:
    // all four render everywhere, matching LoginPage exactly — each button
    // just picks the id-token or the browser-redirect link internally (see
    // _linkWithGoogle/_linkWithApple above).
    final showSocialButtons = _codeSentTo == null;

    return _capped(
      Container(
        key: const ValueKey('support-account-link-card'),
        margin: const EdgeInsets.fromLTRB(12, 6, 12, 0),
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(
          color: cs.muted.withAlpha(120),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(l10n.supportAccountLinkTitle, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
            const Gap(3),
            Text(l10n.supportAccountLinkBody, style: TextStyle(fontSize: 12.5, color: cs.mutedForeground)),
            const Gap(11),
            if (showSocialButtons) ...[
              SignInButton(Buttons.google, onPressed: _linkWithGoogle),
              const Gap(8),
              SignInButton(Buttons.apple, onPressed: _linkWithApple),
              const Gap(8),
              SignInButton(Buttons.gitHub, onPressed: _linkWithGithub),
              const Gap(8),
              SignInButton(Buttons.facebook, onPressed: _linkWithFacebook),
              const Gap(11),
              Divider(child: Text(l10n.orSeparator).small.muted),
              const Gap(11),
            ],
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: _codeSentTo == null
                      ? TextField(
                          key: const ValueKey('support-account-email-field'),
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          placeholder: Text(l10n.emailAddress),
                        )
                      : TextField(
                          key: const ValueKey('support-account-code-field'),
                          controller: _codeController,
                          keyboardType: TextInputType.number,
                          placeholder: Text(l10n.feedbackEmailCodeHint),
                        ),
                ),
                const Gap(8),
                PrimaryButton(
                  key: ValueKey(_codeSentTo == null ? 'support-account-email-send' : 'support-account-code-verify'),
                  onPressed: _busy ? null : (_codeSentTo == null ? _sendLink : _verify),
                  child: _busy
                      ? const SmallProgressIndicator()
                      : Text(_codeSentTo == null ? l10n.supportAccountLinkAddButton : l10n.feedbackEmailVerifyButton),
                ),
              ],
            ),
            if (_failed) ...[
              const Gap(8),
              Text(
                _alreadyLinked ? l10n.supportAccountAlreadyLinked : l10n.supportAccountLinkFailed,
                style: TextStyle(color: cs.destructive, fontSize: 12),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// Caps content width and centers it on desktop — this card used to
  /// stretch to the full window width there. Same idiom and the same
  /// maxWidth as `ClickV2OnboardingPage`'s own fix (Center + ConstrainedBox)
  /// rather than a new number — but with `heightFactor: 1`, matching
  /// help_answer_sheet.dart's version of the same idiom rather than the
  /// full-page one: this card is one sibling inside SupportChatPage's own
  /// Column, not a page's whole content, so a plain `Center` (no factor)
  /// would greedily fill all remaining vertical space in that Column
  /// instead of just wrapping its own natural height, pushing the composer
  /// below it out of place.
  Widget _capped(Widget child) {
    return Center(
      heightFactor: 1,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: child,
      ),
    );
  }
}
