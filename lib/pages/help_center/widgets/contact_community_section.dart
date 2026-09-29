// "Contact & community" section body — the support-chat entry point plus
// Reddit/Facebook/GitHub links, lifted unchanged from the old help-button
// dropdown's `MenuButton` (Task 8): unread-dot polling, the pre-staged
// overview screenshot, and the debug-text/TelemetrySnapshot handoff into
// `SupportChatPage` all behave exactly as before. Design round 1 relabeled
// the support row "Tell us what's wrong" / "Chat with support · no account
// needed" — it is the single entry point into reporting a problem now that
// the feedback prompt's own free-text complaint route is gone — without
// touching any of that wiring, and moved it first (matching the mockup and
// the original spec's stated order) ahead of the Reddit/Facebook/GitHub
// links. Layout-fidelity round: those links moved from three stacked
// full-width rows into a single row of three equal-width bordered buttons
// (icon above label), matching the mockup's Contact & Community card — same
// targets, same icons, unchanged wiring.
//
// Feedback-routing round: the support row now accepts an optional
// [HelpCenterSupportContext] (forwarded from [HelpCenterPage]) carrying a
// trainer-specific payload gathered by whoever pushed the Help Center (the
// "No difference"/"Not working" feedback buttons) — when present, that
// payload goes to [SupportChatPage] instead of the generic one this section
// gathers itself, so continuing into the chat from here never loses it.
//
// Review round: [HelpCenterSupportContext.telemetryBuilder] is lazy and
// memoized (see `memoizeAsync`), so calling it here — the point the rider
// actually commits to opening the chat, not whenever the Help Center merely
// *might* have been reached — is what triggers its (slow, mDNS-scanning)
// gather for the first and only time; `diagnosticPreviewFuture` is derived
// from that same call rather than stored separately, so the preview and
// every later send share one result. Also collapsed the two branches' near-
// identical `Navigator.push` into one.
import 'dart:convert';

import 'package:bike_control/main.dart' show recordError;
import 'package:bike_control/pages/help_center/help_center_support_context.dart';
import 'package:bike_control/pages/support_chat/support_chat_page.dart';
import 'package:bike_control/pages/support_chat/widgets/support_composer.dart' show StagedAttachment;
import 'package:bike_control/services/overview_screenshot.dart';
import 'package:bike_control/services/support_chat_models.dart';
import 'package:bike_control/services/support_chat_service.dart';
import 'package:bike_control/services/telemetry_snapshot.dart';
import 'package:bike_control/utils/core.dart';
import 'package:bike_control/utils/i18n_extension.dart';
import 'package:bike_control/widgets/menu.dart' show debugText;
import 'package:bike_control/widgets/ui/type_scale.dart';
import 'package:bike_control/widgets/ui/unread_dot.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:url_launcher/url_launcher_string.dart';

class ContactCommunitySection extends StatefulWidget {
  /// Trainer-specific support payload to hand [SupportChatPage] when the
  /// rider taps "Tell us what's wrong", in place of this section's own
  /// generic one. Null for every entry point that isn't a feedback button
  /// (the help button, "Get help" from the sentiment prompt).
  final HelpCenterSupportContext? launchContext;

  const ContactCommunitySection({super.key, this.launchContext});

  @override
  State<ContactCommunitySection> createState() => _ContactCommunitySectionState();
}

class _ContactCommunitySectionState extends State<ContactCommunitySection> {
  bool _hasUnread = false;

  @override
  void initState() {
    super.initState();
    if (core.settings.getSupportChatActive()) {
      _checkForUnread();
    }
  }

  /// Polls the support chat in the background and surfaces a small dot next
  /// to the support row when at least one admin message has arrived since
  /// the last seen timestamp on the chat. Failures (no auth, network down,
  /// edge function unavailable) are swallowed — the dot just stays off.
  Future<void> _checkForUnread() async {
    if (core.supabase.auth.currentSession == null) return;
    try {
      final fetched = await SupportChatService().fetchChat(skipLastSeen: true);
      if (!mounted) return;
      final lastSeen = fetched.chat?.lastSeenAt;
      final hasUnreadAdminReply = fetched.messages.any(
        (m) => m.senderRole == SupportMessageSenderRole.admin && (lastSeen == null || m.createdAt.isAfter(lastSeen)),
      );
      if (hasUnreadAdminReply != _hasUnread) {
        setState(() => _hasUnread = hasUnreadAdminReply);
      }
    } catch (e, s) {
      // Best-effort — leave the dot off.
      recordError(e, s, context: 'ContactCommunitySection.checkForUnread');
    }
  }

  Future<void> _openChat(BuildContext context) async {
    final launchContext = widget.launchContext;
    final Future<String>? diagnosticPreviewFuture;
    final StagedAttachment? initialAttachment;
    final TelemetryBuilder telemetryBuilder;
    if (launchContext != null) {
      // A caller upstream (currently only the trainer-feedback buttons)
      // already gathered a trainer-specific payload before pushing the Help
      // Center — reuse it verbatim instead of collecting a fresh, generic
      // one from scratch. telemetryBuilder is lazy + memoized (memoizeAsync):
      // this call is what actually starts its gather, and it's the only one
      // — the preview below and every later send-time attachment
      // (SupportChatPage._send calling telemetryBuilder again) share this
      // same in-flight/completed snapshot instead of re-gathering.
      telemetryBuilder = launchContext.telemetryBuilder;
      diagnosticPreviewFuture = telemetryBuilder().then((s) => JsonEncoder.withIndent('  ').convert(s.toJson()));
      initialAttachment = launchContext.initialAttachment;
    } else {
      final screenshot = await captureOverviewScreenshot(context: context);
      if (!context.mounted) return;
      // Gather diagnostics in the background so the chat opens immediately; the
      // page awaits this future lazily for the preview. Send-time telemetry is
      // re-gathered fresh (see telemetryBuilder) so a later message reflects
      // the current state, not the compose-time snapshot.
      diagnosticPreviewFuture = debugText();
      initialAttachment = screenshot;
      telemetryBuilder = () async => TelemetrySnapshot.general(freetext: await debugText());
    }
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => SupportChatPage(
          diagnosticPreviewFuture: diagnosticPreviewFuture,
          initialAttachment: initialAttachment,
          telemetryBuilder: telemetryBuilder,
        ),
      ),
    );
    if (mounted) {
      setState(() => _hasUnread = false);
      _checkForUnread();
    }
  }

  @override
  Widget build(BuildContext context) {
    final destructive = Theme.of(context).colorScheme.destructive;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // The support row leads (spec: "support chat ... then Reddit/
        // Facebook/GitHub links"; the mockup puts it first too) — it is the
        // single entry point into reporting a problem now that the feedback
        // prompt's own free-text complaint route is gone. Padding matches
        // the mockup's row padding (`padding:12px 14px`) now that the card
        // itself carries no padding — rows run edge-to-edge and supply
        // their own inset.
        Button.ghost(
          key: const ValueKey('help-center-chat-with-support'),
          style: ButtonStyle.ghost().withPadding(padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14)),
          onPressed: () => _openChat(context),
          child: Basic(
            leading: Icon(LucideIcons.messageCircle, size: 18, color: _hasUnread ? destructive : null),
            title: _hasUnread
                ? Text(context.i18n.helpCenterReportTitle).semiBold
                : Text(context.i18n.helpCenterReportTitle),
            subtitle: Text(context.i18n.helpCenterReportSubtitle).xSmall.muted,
            trailing: _hasUnread
                ? const UnreadDot(key: ValueKey('help-center-chat-unread-dot'), size: 10)
                : const Icon(LucideIcons.chevronRight, size: 16).iconMutedForeground,
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
          child: Text(context.i18n.helpCenterChatLanguageHint).xSmall.muted,
        ),
        const Divider(),
        // Reddit/Facebook/GitHub as three equal-width bordered buttons in a
        // row (icon above label), matching the mockup — replacing the old
        // stacked full-width list rows.
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
          child: Row(
            spacing: 8,
            children: [
              Expanded(
                child: _CommunityLinkButton(
                  icon: Icons.reddit_outlined,
                  label: 'Reddit',
                  onPressed: () => launchUrlString('https://www.reddit.com/r/BikeControl/'),
                ),
              ),
              Expanded(
                child: _CommunityLinkButton(
                  icon: LucideIcons.facebook,
                  label: 'Facebook',
                  onPressed: () => launchUrlString('https://www.facebook.com/groups/1892836898778912'),
                ),
              ),
              Expanded(
                child: _CommunityLinkButton(
                  icon: LucideIcons.github,
                  label: 'GitHub',
                  onPressed: () => launchUrlString('https://github.com/OpenBikeControl/bikecontrol/issues'),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// One tile in the Reddit/Facebook/GitHub row: a bordered, equal-width
/// button with its icon stacked above its label (mockup's Contact &
/// Community card).
class _CommunityLinkButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  const _CommunityLinkButton({required this.icon, required this.label, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Button.outline(
      style: ButtonStyle.outline().withPadding(padding: const EdgeInsets.symmetric(vertical: 11)),
      onPressed: onPressed,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        spacing: 6,
        children: [
          Icon(icon, size: 18, color: cs.mutedForeground),
          Text(label, style: context.typography.xSmall.copyWith(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
