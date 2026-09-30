import 'package:bike_control/utils/units.dart';
import 'package:bike_control/widgets/ui/type_scale.dart';
import 'package:prop/emulators/definitions/fitness_bike_definition.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

/// Heart rate and speed on Ride, one chip each, only while there is a
/// reading. Power and cadence are on the virtual shifting card already; where
/// each reading comes from is chosen under Devices → Sensors.
class RideLiveChips extends StatelessWidget {
  const RideLiveChips({super.key, required this.definition});

  final FitnessBikeDefinition definition;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([definition.heartRateBpm, definition.speedKph]),
      builder: (context, _) {
        final heart = definition.heartRateBpm.value;
        final speed = definition.speedKph.value;
        if (heart == null && speed == null) return const SizedBox.shrink();
        final units = unitSystemOf(context);
        return Padding(
          padding: const EdgeInsets.only(top: 16),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (heart != null)
                _Chip(key: const ValueKey('ride-chip-heart'), icon: LucideIcons.heart, value: '$heart', unit: 'bpm'),
              if (speed != null)
                _Chip(
                  key: const ValueKey('ride-chip-speed'),
                  icon: LucideIcons.gauge,
                  value: units.fromKph(speed).toStringAsFixed(1),
                  unit: units.speedSymbol,
                ),
            ],
          ),
        );
      },
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({super.key, required this.icon, required this.value, required this.unit});

  final IconData icon;
  final String value;
  final String unit;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
      decoration: BoxDecoration(color: cs.card, borderRadius: BorderRadius.circular(10)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: cs.mutedForeground),
          const Gap(6),
          Text(
            value,
            style: context.typography.small.copyWith(fontWeight: FontWeight.w700, fontFeatures: BkNumerals.tabular),
          ),
          const Gap(4),
          Text(unit, style: context.typography.xSmall.copyWith(color: cs.mutedForeground)),
        ],
      ),
    );
  }
}
