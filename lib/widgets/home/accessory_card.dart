import 'package:bike_control/pages/home/chain_state.dart';
import 'package:bike_control/utils/i18n_extension.dart';
import 'package:bike_control/widgets/home/ampel.dart';
import 'package:bike_control/widgets/ui/bk_touch_target.dart';
import 'package:bike_control/widgets/ui/type_scale.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

/// A device BikeControl drives that isn't a link in the setup chain — a
/// Headwind fan, a KICKR Climb.
///
/// It sits below the chain because it answers none of "am I ready to ride",
/// and it is deliberately quieter than a chain card: no checklist, no steps,
/// one line of status. But it does have to be *on* the screen. Opening a
/// device's settings is the only route to "Disconnect and forget", which is
/// the only way onto the ignore list — so an accessory the scanner picked up
/// that isn't the rider's (a neighbour's Headwind, through a wall) was
/// previously unreachable and could not be dismissed at all.
class AccessoryCard extends StatelessWidget {
  const AccessoryCard({
    super.key,
    required this.title,
    required this.icon,
    required this.connected,
    required this.onOpen,
  });

  final String title;
  final IconData icon;
  final bool connected;

  /// Opens this accessory's settings page, where it can be forgotten.
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // An accessory is never "broken": it is either here or it isn't, and a fan
    // that is out of range is not a reason to colour the screen.
    final status = connected ? LinkStatus.ready : LinkStatus.off;

    return Container(
      decoration: ShapeDecoration(
        color: theme.colorScheme.card,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: theme.colorScheme.border, width: 1.5),
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(13, 10, 6, 10),
        child: Row(
          children: [
            TileWithAmpel(
              status: status,
              size: 38,
              child: Icon(
                icon,
                size: 19,
                color: connected ? theme.colorScheme.foreground : theme.colorScheme.mutedForeground,
              ),
            ),
            const Gap(12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.typography.small.copyWith(fontWeight: FontWeight.w700),
                  ),
                  StatusLine(
                    status: status,
                    label: connected ? context.i18n.connected : context.i18n.notConnected,
                  ),
                ],
              ),
            ),
            BkTouchTarget(
              child: Button.ghost(
                alignment: Alignment.center,
                onPressed: onOpen,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      context.i18n.chainEdit,
                      style: context.typography.small.copyWith(
                        fontWeight: FontWeight.w600,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                    Icon(LucideIcons.chevronRight, size: 15, color: theme.colorScheme.primary),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
