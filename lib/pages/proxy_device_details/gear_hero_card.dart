import 'package:bike_control/widgets/ui/setting_tile.dart';
import 'package:prop/emulators/definitions/fitness_bike_definition.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

class GearHeroCard extends StatelessWidget {
  final FitnessBikeDefinition definition;
  const GearHeroCard({super.key, required this.definition});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return AnimatedBuilder(
      animation: Listenable.merge([
        definition.trainerMode,
        definition.ergTargetPower,
        definition.currentGear,
        definition.gearRatio,
      ]),
      builder: (context, _) {
        final isErg = definition.trainerMode.value == TrainerMode.ergMode;
        return SettingTile(
          icon: LucideIcons.cog,
          title: 'Trainer Control',
          subtitle: isErg ? 'Fixed target power mode' : 'Virtual gear shifting',
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            spacing: 8,
            children: [
              _modePill(cs, TrainerMode.simMode, active: !isErg),
              Switch(
                value: isErg,
                onChanged: (v) {
                  if (v) {
                    definition.setManualErgPower(
                      definition.ergTargetPower.value ?? 150,
                    );
                  } else {
                    definition.exitErgMode();
                  }
                },
              ),
              _modePill(cs, TrainerMode.ergMode, active: isErg),
            ],
          ),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
            decoration: BoxDecoration(
              color: cs.muted,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: cs.border,
              ),
            ),
            child: isErg ? _ergContent(cs) : _gearContent(context, cs),
          ),
        );
      },
    );
  }

  Widget _gearContent(BuildContext context, ColorScheme cs) {
    final gear = definition.currentGear.value;
    final ratio = definition.gearRatio.value;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      spacing: 28,
      children: [
        _shiftButton(
          context: context,
          icon: LucideIcons.minus,
          filled: false,
          onTap: () => definition.shiftDown(),
        ),
        Column(
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
            Text(
              'of 24  ·  ratio ${ratio.toStringAsFixed(2)}',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: cs.mutedForeground,
              ),
            ),
          ],
        ),
        _shiftButton(
          context: context,
          icon: LucideIcons.plus,
          filled: true,
          onTap: () => definition.shiftUp(),
        ),
      ],
    );
  }

  Widget _ergContent(ColorScheme cs) {
    final target = definition.ergTargetPower.value ?? 150;
    return Column(
      spacing: 12,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          spacing: 8,
          children: [
            Text(
              '$target',
              style: TextStyle(
                fontSize: 72,
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
            Text(
              '0 W',
              style: TextStyle(fontSize: 10, color: cs.mutedForeground),
            ),
            Text(
              '500 W',
              style: TextStyle(fontSize: 10, color: cs.mutedForeground),
            ),
          ],
        ),
      ],
    );
  }

  Widget _modePill(ColorScheme cs, TrainerMode mode, {required bool active}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: active ? cs.primary : cs.muted,
        borderRadius: BorderRadius.circular(999),
        border: active ? null : Border.all(color: cs.border),
      ),
      child: Text(
        _modeLabel(mode),
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: active ? cs.primaryForeground : cs.mutedForeground,
        ),
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
        child: Icon(
          icon,
          size: 22,
          color: filled ? cs.primaryForeground : cs.mutedForeground,
        ),
      ),
    );
  }

  String _modeLabel(TrainerMode mode) => switch (mode) {
    TrainerMode.ergMode => 'ERG',
    TrainerMode.simMode => 'SIM',
    TrainerMode.simModeVirtualShifting => 'Virtual Shifting',
  };
}
