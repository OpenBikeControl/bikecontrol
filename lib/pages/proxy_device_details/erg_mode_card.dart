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
                  spacing: 8,
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
