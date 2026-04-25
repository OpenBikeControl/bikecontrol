import 'package:prop/emulators/definitions/fitness_bike_definition.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

class ErgModeCard extends StatelessWidget {
  final FitnessBikeDefinition definition;
  const ErgModeCard({super.key, required this.definition});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return AnimatedBuilder(
      animation: Listenable.merge([definition.ergTargetPower, definition.trainerMode]),
      builder: (context, _) {
        final target = definition.ergTargetPower.value;
        final isErg = definition.trainerMode.value == TrainerMode.ergMode;
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: cs.card,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: isErg ? cs.primary : cs.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: 12,
            children: [
              Row(
                children: [
                  Icon(LucideIcons.zap, size: 18, color: isErg ? cs.primary : null),
                  const Gap(12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      spacing: 2,
                      children: [
                        const Text(
                          'ERG Mode',
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                        ),
                        Text(
                          'Set a fixed target power — trainer holds this wattage',
                          style: TextStyle(fontSize: 12, color: cs.mutedForeground),
                        ),
                      ],
                    ),
                  ),
                  Switch(
                    value: isErg,
                    onChanged: (v) {
                      if (v) {
                        definition.setManualErgPower(target ?? 150);
                      } else {
                        definition.exitErgMode();
                      }
                    },
                  ),
                ],
              ),
              if (isErg && target != null) ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    IconButton.outline(
                      icon: const Icon(LucideIcons.minus, size: 20),
                      onPressed: target > 0
                          ? () => definition.setManualErgPower((target - 5).clamp(0, 500))
                          : null,
                    ),
                    const Gap(16),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(
                          '$target',
                          style: TextStyle(
                            fontSize: 48,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -2,
                            color: cs.primary,
                          ),
                        ),
                        const Gap(4),
                        Text(
                          'W',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: cs.mutedForeground,
                          ),
                        ),
                      ],
                    ),
                    const Gap(16),
                    IconButton.outline(
                      icon: const Icon(LucideIcons.plus, size: 20),
                      onPressed: target < 500
                          ? () => definition.setManualErgPower((target + 5).clamp(0, 500))
                          : null,
                    ),
                  ],
                ),
                Slider(
                  value: SliderValue.single(target.toDouble()),
                  min: 0,
                  max: 500,
                  divisions: 100,
                  onChanged: (v) => definition.setManualErgPower(v.value.round()),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('0 W', style: TextStyle(fontSize: 10, color: cs.mutedForeground)),
                    Text('500 W', style: TextStyle(fontSize: 10, color: cs.mutedForeground)),
                  ],
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}
