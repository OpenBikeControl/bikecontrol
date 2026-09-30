import 'package:bike_control/utils/i18n_extension.dart';
import 'package:bike_control/widgets/ui/app_theme.dart' show BkStatusColors;
import 'package:bike_control/widgets/ui/bk_tappable.dart';
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
/// It never goes away completely: after "Not now" it shrinks to "Gear overlay
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

  Widget _offer(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l = context.i18n;
    final accent = bkAccentText(context);
    return Padding(
      key: const ValueKey('ride-overlay-offer'),
      padding: const EdgeInsets.only(top: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 1),
                child: Icon(LucideIcons.layers, size: 18, color: accent),
              ),
              const Gap(10),
              Expanded(
                child: Text(
                  l.onboardingDoneOverlayNote(appName),
                  style: context.typography.small.copyWith(color: cs.foreground, height: 1.4),
                ),
              ),
            ],
          ),
          const Gap(12),
          Wrap(
            spacing: 4,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              // Primary-tinted rather than filled: − / + above keep the card's
              // one solid accent.
              BkTappable(
                onPressed: onEnable,
                borderRadius: BorderRadius.circular(22),
                child: Container(
                  height: 44,
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  decoration: BoxDecoration(
                    color: cs.primary.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(22),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(LucideIcons.layers, size: 17, color: accent),
                      const Gap(6),
                      Text(
                        l.onboardingDoneShowOverlay,
                        style: context.typography.small.copyWith(color: accent, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
              ),
              BkTappable(
                onPressed: onDecline,
                borderRadius: BorderRadius.circular(22),
                child: Container(
                  height: 44,
                  alignment: Alignment.center,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: Text(
                    l.chainStepOverlayDecline,
                    style: context.typography.small.copyWith(color: cs.mutedForeground, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
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
            Text(l.overlaySection, style: context.typography.small.copyWith(color: accent, fontWeight: FontWeight.w600)),
            Icon(LucideIcons.chevronRight, size: 15, color: accent),
          ],
        ),
      ),
    );
  }
}
