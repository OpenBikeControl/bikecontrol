import 'package:prop/emulators/definitions/fitness_bike_definition.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

class GearHeroCard extends StatelessWidget {
  final FitnessBikeDefinition definition;
  const GearHeroCard({super.key, required this.definition});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
      decoration: BoxDecoration(
        color: cs.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.border),
      ),
      child: Column(
        spacing: 12,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                spacing: 6,
                children: [
                  Icon(LucideIcons.cog, size: 14, color: cs.mutedForeground),
                  Text(
                    'CURRENT GEAR',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1,
                      color: cs.mutedForeground,
                    ),
                  ),
                ],
              ),
              ValueListenableBuilder<TrainerMode>(
                valueListenable: definition.trainerMode,
                builder: (_, mode, _) => Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                  decoration: BoxDecoration(
                    color: cs.primary,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    _modeLabel(mode),
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: cs.primaryForeground,
                    ),
                  ),
                ),
              ),
            ],
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            spacing: 28,
            children: [
              _shiftButton(
                context: context,
                icon: LucideIcons.minus,
                filled: false,
                onTap: () => definition.shiftDown(),
              ),
              ValueListenableBuilder<int>(
                valueListenable: definition.currentGear,
                builder: (_, gear, _) => Column(
                  spacing: 2,
                  children: [
                    Text(
                      '$gear',
                      style: TextStyle(
                        fontSize: 72,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -2,
                        color: cs.foreground,
                      ),
                    ),
                    ValueListenableBuilder<double>(
                      valueListenable: definition.gearRatio,
                      builder: (_, ratio, _) => Text(
                        'of 24  ·  ratio ${ratio.toStringAsFixed(2)}',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: cs.mutedForeground,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              _shiftButton(
                context: context,
                icon: LucideIcons.plus,
                filled: true,
                onTap: () => definition.shiftUp(),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _shiftButton({
    required BuildContext context,
    required IconData icon,
    required bool filled,
    required VoidCallback onTap,
  }) {
    final cs = Theme.of(context).colorScheme;
    return Button.ghost(
      onPressed: onTap,
      child: Container(
        width: 52,
        height: 52,
        decoration: BoxDecoration(
          color: filled ? cs.primary : cs.muted,
          shape: BoxShape.circle,
          border: filled ? null : Border.all(color: cs.border, width: 1),
        ),
        child: Icon(icon, size: 22, color: filled ? cs.primaryForeground : cs.mutedForeground),
      ),
    );
  }

  String _modeLabel(TrainerMode mode) => switch (mode) {
        TrainerMode.ergMode => 'ERG',
        TrainerMode.simMode => 'SIM',
        TrainerMode.simModeVirtualShifting => 'Virtual Shifting',
      };
}
