import 'package:bike_control/gen/l10n.dart';
import 'package:bike_control/widgets/ui/setting_tile.dart';
import 'package:prop/emulators/definitions/fitness_bike_definition.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

class GearHeroCard extends StatelessWidget {
  final FitnessBikeDefinition definition;

  /// When true, the card renders only in SIM mode and hides (returns an
  /// empty widget) in ERG mode. The mode switch is also omitted since the
  /// surface is dedicated to gear shifting.
  final bool simOnly;
  const GearHeroCard({super.key, required this.definition, this.simOnly = false});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return AnimatedBuilder(
      animation: Listenable.merge([
        definition.trainerMode,
        definition.ergTargetPower,
        definition.targetPowerW,
        definition.currentGear,
        definition.gearRatio,
      ]),
      builder: (context, _) {
        final isErg = definition.trainerMode.value == TrainerMode.ergMode;
        if (simOnly && isErg) return const SizedBox.shrink();
        return SettingTile(
          icon: LucideIcons.cog,
          title: AppLocalizations.of(context).trainerControl,
          subtitle: isErg ? AppLocalizations.of(context).fixedTargetPowerMode : AppLocalizations.of(context).virtualGearShifting,
          trailing: simOnly
              ? null
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  spacing: 8,
                  children: [
                    _modePill(context, cs, TrainerMode.simMode, active: !isErg),
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
                    _modePill(context, cs, TrainerMode.ergMode, active: isErg),
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
            child: isErg ? _ergContent(context, cs) : _gearContent(context, cs),
          ),
        );
      },
    );
  }

  Widget _gearContent(BuildContext context, ColorScheme cs) {
    final gear = definition.currentGear.value;
    final ratio = definition.gearRatio.value;
    final target = definition.targetPowerW.value;
    final subtitle = StringBuffer('of ${definition.maxGear}  ·  ratio ${ratio.toStringAsFixed(2)}');
    if (target != null) subtitle.write('  ·  target $target W');
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
              subtitle.toString(),
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

  Widget _ergContent(BuildContext context, ColorScheme cs) {
    final target = definition.ergTargetPower.value ?? 150;
    return Column(
      spacing: 12,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          spacing: 28,
          children: [
            _shiftButton(
              context: context,
              icon: LucideIcons.minus,
              filled: false,
              onTap: target > 0
                  ? () => definition.setManualErgPower((target - 5).clamp(0, 500))
                  : null,
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
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
            _shiftButton(
              context: context,
              icon: LucideIcons.plus,
              filled: true,
              onTap: target < 500
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

  Widget _modePill(BuildContext context, ColorScheme cs, TrainerMode mode, {required bool active}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: active ? cs.primary : cs.muted,
        borderRadius: BorderRadius.circular(999),
        border: active ? null : Border.all(color: cs.border),
      ),
      child: Text(
        _modeLabel(context, mode),
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
    required VoidCallback? onTap,
  }) {
    final cs = Theme.of(context).colorScheme;
    final disabled = onTap == null;
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
        child: Opacity(
          opacity: disabled ? 0.4 : 1.0,
          child: Icon(
            icon,
            size: 22,
            color: filled ? cs.primaryForeground : cs.mutedForeground,
          ),
        ),
      ),
    );
  }

  String _modeLabel(BuildContext context, TrainerMode mode) => switch (mode) {
    TrainerMode.ergMode => AppLocalizations.of(context).ergMode,
    TrainerMode.simMode => AppLocalizations.of(context).simMode,
    TrainerMode.simModeVirtualShifting => AppLocalizations.of(context).virtualShifting,
  };
}
