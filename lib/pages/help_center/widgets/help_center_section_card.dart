import 'package:bike_control/widgets/ui/colors.dart' show BKColor;
import 'package:bike_control/widgets/ui/type_scale.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

/// A single Help Center section: a header row over a `Card` body, staggered
/// into view — fade+slide, 60 ms per [index] — as the page first builds.
/// Cheap by design: a single `TweenAnimationBuilder` per section, no
/// controllers to dispose.
///
/// Card anatomy (matches `docs/design-mockups/Help Center.dc.html`): a
/// 36×36 rounded-square icon tile, an optional uppercase micro-label above
/// the title, an optional muted subtitle below it, then a full-bleed 1px
/// divider under the header. [child] renders directly below that divider —
/// it owns its own edge-to-edge row padding and inter-row dividers, rather
/// than sitting inside a padded column, so the card itself carries no
/// padding at all.
///
/// [accent] colours the icon and, when it equals [BKColor.main], tints the
/// icon tile with the brand tint too (matching the mockup's "brand-accented"
/// tiles). Any other non-null accent (e.g. a warning colour) gets a light
/// tint of itself instead. `null` renders the mockup's neutral tile: a plain
/// muted background with a foreground-coloured icon.
class HelpCenterSectionCard extends StatelessWidget {
  final int index;
  final IconData icon;
  final String title;
  final String? microLabel;
  final String? subtitle;
  final Color? accent;
  final bool focused;
  final Widget child;

  const HelpCenterSectionCard({
    super.key,
    required this.index,
    required this.icon,
    required this.title,
    this.microLabel,
    this.subtitle,
    this.accent = BKColor.main,
    this.focused = false,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final accent = this.accent;
    final tileBackground = accent == null
        ? cs.muted
        : (accent == BKColor.main ? BKColor.backgroundLight : accent.withValues(alpha: 0.12));
    final iconColor = accent ?? cs.foreground;
    final microLabel = this.microLabel;
    final subtitle = this.subtitle;

    return TweenAnimationBuilder<double>(
      key: ValueKey('help-center-section-anim-$index'),
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 220 + index * 60),
      curve: Curves.easeOut,
      builder: (context, value, animatedChild) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, (1 - value) * 14),
            child: animatedChild,
          ),
        );
      },
      child: Card(
        padding: EdgeInsets.zero,
        // Keeps the border-colour easing feel the old focus frame had, now
        // driven by the card's own border instead of a nested container.
        duration: const Duration(milliseconds: 220),
        borderColor: focused ? BKColor.main : null,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
              child: Row(
                spacing: 11,
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(color: tileBackground, borderRadius: BorderRadius.circular(6)),
                    child: Icon(icon, size: 19, color: iconColor),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (microLabel != null)
                          Text(
                            microLabel.toUpperCase(),
                            style: context.typography.caption.copyWith(
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.735,
                              color: cs.mutedForeground,
                            ),
                          ),
                        Padding(
                          padding: EdgeInsets.only(top: microLabel != null ? 1 : 0),
                          child: Text(
                            title,
                            style: context.typography.large.copyWith(fontWeight: FontWeight.w700, letterSpacing: -0.17),
                          ),
                        ),
                        if (subtitle != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Text(subtitle, style: context.typography.xSmall.copyWith(color: cs.mutedForeground)),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const Divider(),
            child,
          ],
        ),
      ),
    );
  }
}
