import 'package:bike_control/services/health/health_ride_service.dart';
import 'package:bike_control/utils/i18n_extension.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

/// Shown on the home screen while [HealthRideService] is recording a ride on
/// its own — the rider never pressed a record button, so without this there
/// would be nothing on screen to say a ride is being tracked at all.
class HealthRideChip extends StatelessWidget {
  const HealthRideChip({super.key, required this.service});

  final HealthRideService service;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: service.isAutoRecording,
      builder: (context, recording, _) {
        if (!recording) return const SizedBox.shrink();

        final theme = Theme.of(context);
        final l = context.i18n;

        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: theme.colorScheme.card,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: theme.colorScheme.border, width: 1.5),
            ),
            child: Row(
              children: [
                Icon(LucideIcons.heartPulse, size: 16, color: theme.colorScheme.primary),
                const Gap(8),
                Expanded(
                  child: Text(
                    l.healthRideChipLabel,
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                ),
                Button.ghost(
                  key: const Key('health-ride-chip-finish'),
                  style: ButtonStyle.ghost().withPadding(padding: const EdgeInsets.symmetric(horizontal: 8)),
                  onPressed: service.finishNow,
                  child: Text(l.healthRideFinishNow),
                ),
                Button.ghost(
                  key: const Key('health-ride-chip-discard'),
                  style: ButtonStyle.ghost().withPadding(padding: const EdgeInsets.symmetric(horizontal: 8)),
                  onPressed: () => _confirmDiscard(context),
                  child: Text(l.healthRideDiscard, style: TextStyle(color: theme.colorScheme.destructive)),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _confirmDiscard(BuildContext context) async {
    final l = context.i18n;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l.healthRideDiscardConfirmTitle),
        content: Text(l.healthRideDiscardConfirmBody),
        actions: [
          Button.outline(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(l.cancel),
          ),
          DestructiveButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(l.healthRideDiscardConfirmAction),
          ),
        ],
      ),
    );
    if (confirmed == true) service.discard();
  }
}
