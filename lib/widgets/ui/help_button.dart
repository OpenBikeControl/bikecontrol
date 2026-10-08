import 'package:bike_control/main.dart';
import 'package:bike_control/pages/help_center/help_center_page.dart';
import 'package:bike_control/services/support_chat_models.dart';
import 'package:bike_control/services/support_chat_service.dart';
import 'package:bike_control/utils/core.dart';
import 'package:bike_control/utils/i18n_extension.dart';
import 'package:bike_control/utils/reduced_motion.dart';
import 'package:bike_control/widgets/ui/unread_dot.dart';
import 'package:bike_control/widgets/ui/bk_icon_button.dart';
import 'package:bike_control/widgets/ui/bk_tappable.dart';
import 'package:bike_control/widgets/ui/colors.dart';
import 'package:bike_control/widgets/ui/type_scale.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

/// Where the Help & Support entry is drawn.
enum HelpButtonStyle {
  /// The (?) icon in the top bar.
  icon,

  /// The row at the foot of the sidebar.
  sidebar,
}

/// Opens the Help Center. Carries a pulsing red dot while a support reply is
/// unread.
class HelpButton extends StatefulWidget {
  final HelpButtonStyle style;
  const HelpButton({super.key, this.style = HelpButtonStyle.icon});

  @override
  State<HelpButton> createState() => _HelpButtonState();
}

class _HelpButtonState extends State<HelpButton> {
  bool _hasUnread = false;

  @override
  void initState() {
    super.initState();
    if (core.settings.getSupportChatActive()) {
      _checkForUnread();
    }
  }

  /// Polls the support chat in the background and surfaces a small dot on
  /// the help button when at least one admin message has arrived since the
  /// last seen timestamp on the chat. Failures (no auth, network down,
  /// edge function unavailable) are recorded and the dot just stays off.
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
    } catch (error, stack) {
      // Best-effort — leave the dot off.
      recordError(error, stack, context: 'Checking for unread support messages');
    }
  }

  Future<void> _open() async {
    // Awaited so the unread badge re-syncs on return: this button stays
    // mounted under the pushed route, and ContactCommunitySection only ever
    // clears its own local unread flag.
    await context.push(const HelpCenterPage());
    if (mounted) {
      setState(() => _hasUnread = false);
      _checkForUnread();
    }
  }

  Widget _icon(BuildContext context, {double size = 20}) {
    final cs = Theme.of(context).colorScheme;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Icon(
          widget.style == HelpButtonStyle.icon ? LucideIcons.circleHelp : LucideIcons.lifeBuoy,
          size: size,
          color: _hasUnread ? cs.destructive : (widget.style == HelpButtonStyle.icon ? bkAccentText(context) : null),
        ),
        if (_hasUnread)
          const Positioned(
            right: -8,
            top: -8,
            child: PulsingUnreadBadge(),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final label = context.i18n.troubleshootingGuide;
    switch (widget.style) {
      case HelpButtonStyle.icon:
        return BkIconButton.ghost(
          key: const ValueKey('help-button'),
          icon: _icon(context, size: 22),
          label: label,
          onPressed: _open,
        );
      case HelpButtonStyle.sidebar:
        return ShellSidebarRow(
          key: const ValueKey('help-button'),
          icon: _icon(context, size: 18),
          label: label,
          onPressed: _open,
        );
    }
  }
}

/// A plain row at the sidebar's foot: icon and label, full width, 44 dp.
class ShellSidebarRow extends StatefulWidget {
  const ShellSidebarRow({super.key, required this.icon, required this.label, required this.onPressed});

  final Widget icon;
  final String label;
  final VoidCallback onPressed;

  @override
  State<ShellSidebarRow> createState() => _ShellSidebarRowState();
}

class _ShellSidebarRowState extends State<ShellSidebarRow> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return BkTappable(
      onPressed: widget.onPressed,
      label: widget.label,
      excludeChildSemantics: true,
      borderRadius: BorderRadius.circular(10),
      onHover: (hovered) => setState(() => _hovered = hovered),
      child: Container(
        constraints: const BoxConstraints(minHeight: 44),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: _hovered ? bkCardHover(context) : null,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            IconTheme.merge(
              data: IconThemeData(color: cs.mutedForeground),
              child: widget.icon,
            ),
            const Gap(12),
            Expanded(
              child: Text(widget.label, style: context.typography.small.copyWith(color: cs.foreground)),
            ),
          ],
        ),
      ),
    );
  }
}

/// Animated unread indicator: a red dot with a halo ring that pulses outward.
/// Used on the Help button's icon overlay so a new support reply is hard to miss.
class PulsingUnreadBadge extends StatefulWidget {
  const PulsingUnreadBadge({super.key});

  @override
  State<PulsingUnreadBadge> createState() => PulsingUnreadBadgeState();
}

class PulsingUnreadBadgeState extends State<PulsingUnreadBadge> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // With reduced motion the halo holds one frame of its pulse: still
    // visible, no longer moving.
    if (prefersReducedMotion(context)) {
      _controller.value = 0.35;
    } else if (!_controller.isAnimating) {
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final destructive = Theme.of(context).colorScheme.destructive;
    final scaleTween = Tween<double>(begin: 1.0, end: 2.6).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );
    final opacityTween = Tween<double>(begin: 0.55, end: 0.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );

    return IgnorePointer(
      child: SizedBox(
        width: 24,
        height: 24,
        child: Stack(
          alignment: Alignment.center,
          children: [
            AnimatedBuilder(
              animation: _controller,
              builder: (_, _) => Transform.scale(
                scale: scaleTween.value,
                child: Opacity(
                  opacity: opacityTween.value,
                  child: Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: destructive,
                    ),
                  ),
                ),
              ),
            ),
            const UnreadDot(),
          ],
        ),
      ),
    );
  }
}
