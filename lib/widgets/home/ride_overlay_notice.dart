import 'package:bike_control/utils/i18n_extension.dart';
import 'package:bike_control/widgets/ui/app_theme.dart' show BkStatusColors;
import 'package:bike_control/widgets/ui/bk_icon_button.dart';
import 'package:bike_control/widgets/ui/bk_tappable.dart';
import 'package:bike_control/widgets/ui/bk_touch_target.dart';
import 'package:bike_control/widgets/ui/colors.dart';
import 'package:bike_control/widgets/ui/type_scale.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

/// Where Ride's gear-overlay offer stands.
enum RideOverlayState {
  /// Off, and never turned down: the full offer.
  offer,

  /// Off after "Not now": one quiet line that still leads to it.
  declined,

  /// On: one line saying so, leading to its settings.
  on,
}

/// The gear-overlay offer at the foot of Ride's virtual shifting card, next to
/// the gear number riders compare against — for trainer apps that keep
/// showing their own gear, where the two numbers disagree.
///
/// The offer is one row (see [_offer]). It never goes away completely: after
/// "Not now" (its close button) it shrinks to "Gear overlay
/// is off · Overlay ›", and once on it reads "Gear overlay is on · Overlay ›".
/// Neither line is a second switch: the overlay is turned off in one place,
/// its page.
class RideOverlayNotice extends StatelessWidget {
  const RideOverlayNotice({
    super.key,
    required this.state,
    required this.appName,
    required this.onEnable,
    required this.onDecline,
    required this.onOpen,
  });

  final RideOverlayState state;
  final String appName;
  final VoidCallback onEnable;
  final VoidCallback onDecline;

  /// Opens Settings → Overlay.
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    return switch (state) {
      RideOverlayState.offer => _offer(context),
      RideOverlayState.declined => _line(context, on: false),
      RideOverlayState.on => _line(context, on: true),
    };
  }

  /// One row: the layers icon, one short line, a primary-tinted "Show
  /// overlay" and a "Not now" close button — short enough that Your buttons
  /// stays in a phone's first screen under the card.
  Widget _offer(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l = context.i18n;
    final accent = bkAccentText(context);
    return Row(
      key: const ValueKey('ride-overlay-offer'),
      children: [
        Icon(LucideIcons.layers, size: 18, color: accent),
        const Gap(8),
        Expanded(
          child: Text(
            l.rideOverlayOfferNote(appName),
            style: context.typography.small.copyWith(color: cs.foreground, height: 1.3),
          ),
        ),
        const Gap(6),
        // Primary-tinted rather than filled: − / + above keep the card's one
        // solid accent. The pill is drawn 36 tall inside a 48 tall target.
        BkTappable(
          key: const ValueKey('ride-overlay-show'),
          onPressed: onEnable,
          borderRadius: BorderRadius.circular(18),
          child: SizedBox(
            height: BkTouchTarget.minSize,
            child: Center(
              widthFactor: 1,
              child: Container(
                height: 36,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: cs.primary.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Center(
                  widthFactor: 1,
                  child: Text(
                    l.rideOverlayOfferShow,
                    maxLines: 1,
                    style: context.typography.small.copyWith(color: accent, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ),
          ),
        ),
        BkTouchTarget(
          child: BkIconButton.ghost(
            icon: Icon(LucideIcons.x, size: 18, color: cs.mutedForeground),
            label: l.chainStepOverlayDecline,
            onPressed: onDecline,
          ),
        ),
      ],
    );
  }

  Widget _line(BuildContext context, {required bool on}) {
    final cs = Theme.of(context).colorScheme;
    final l = context.i18n;
    final accent = bkAccentText(context);
    final text = on ? l.chainStepOverlayDone : l.rideOverlayOff;
    return BkTappable(
      key: ValueKey(on ? 'ride-overlay-on' : 'ride-overlay-off'),
      onPressed: onOpen,
      label: '$text, ${l.overlaySection}',
      excludeChildSemantics: true,
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        height: 48,
        child: Row(
          children: [
            // Green when on, a hollow ring when off: a status, not a button.
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: on ? BkStatusColors.of(context).success : null,
                border: on ? null : Border.all(color: cs.mutedForeground, width: 1.5),
              ),
            ),
            const Gap(8),
            Expanded(
              child: Text(
                text,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.typography.small.copyWith(color: cs.foreground, fontWeight: FontWeight.w500),
              ),
            ),
            Text(
              l.overlaySection,
              style: context.typography.small.copyWith(color: accent, fontWeight: FontWeight.w600),
            ),
            Icon(LucideIcons.chevronRight, size: 15, color: accent),
          ],
        ),
      ),
    );
  }
}

/// A one-line summary at the foot of Ride's virtual shifting card that opens
/// where it is changed — "⚙ 24 gears · Track Resistance   Settings ›". Drawn
/// like the overlay's own line ([RideOverlayNotice] once answered), 48 tall.
class RideSettingsLine extends StatelessWidget {
  const RideSettingsLine({
    super.key,
    required this.icon,
    required this.text,
    required this.linkLabel,
    required this.onPressed,
  });

  final IconData icon;
  final String text;
  final String linkLabel;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final accent = bkAccentText(context);
    final textStyle = context.typography.small.copyWith(color: cs.foreground, fontWeight: FontWeight.w500);
    final linkStyle = context.typography.small.copyWith(color: accent, fontWeight: FontWeight.w600);
    return BkTappable(
      onPressed: onPressed,
      label: '$text, $linkLabel',
      excludeChildSemantics: true,
      borderRadius: BorderRadius.circular(12),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: BkTouchTarget.minSize),
        child: LayoutBuilder(
          builder: (context, constraints) {
            // The summary keeps the line. When it and the link's words do not
            // both fit (German on a phone: "24 Gänge · Zielleistung" beside
            // "Gang-Einstellungen"), the link becomes a settings icon — the
            // whole row is the button, so nothing is lost but the words.
            final scaler = MediaQuery.textScalerOf(context);
            double width(String s, TextStyle style) {
              final painter = TextPainter(
                text: TextSpan(text: s, style: style),
                textDirection: Directionality.of(context),
                textScaler: scaler,
                maxLines: 1,
              )..layout();
              final w = painter.width;
              painter.dispose();
              return w;
            }

            const iconGap = 15 + 8.0;
            final words =
                iconGap + width(text, textStyle) + 8 + width(linkLabel, linkStyle) + 15 <= constraints.maxWidth;
            return Row(
              children: [
                Icon(icon, size: 15, color: cs.mutedForeground),
                const Gap(8),
                Expanded(
                  // Two lines of it still fit the 48, so the card keeps the
                  // connecting placeholder's height.
                  child: Text(text, maxLines: 2, overflow: TextOverflow.ellipsis, style: textStyle),
                ),
                const Gap(8),
                if (words) ...[
                  Text(linkLabel, style: linkStyle),
                  Icon(LucideIcons.chevronRight, size: 15, color: accent),
                ] else
                  Icon(
                    LucideIcons.settings2,
                    key: const ValueKey('ride-settings-line-icon'),
                    size: 18,
                    color: accent,
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}
