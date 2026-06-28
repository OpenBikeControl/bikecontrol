import 'package:bike_control/gen/l10n.dart';
import 'package:bike_control/main.dart' show screenshotMode;
import 'package:bike_control/utils/core.dart';
import 'package:bike_control/utils/keymap/apps/my_whoosh.dart';
import 'package:bike_control/widgets/ui/setting_tile.dart';
import 'package:bike_control/widgets/ui/warning.dart';
import 'package:prop/emulators/definitions/fitness_bike_definition.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

class GearHeroCard extends StatefulWidget {
  final FitnessBikeDefinition definition;

  /// When true, the card renders only in SIM mode and hides (returns an
  /// empty widget) in ERG mode. The mode switch is also omitted since the
  /// surface is dedicated to gear shifting.
  final bool simOnly;
  const GearHeroCard({super.key, required this.definition, this.simOnly = false});

  @override
  State<GearHeroCard> createState() => _GearHeroCardState();
}

class _GearHeroCardState extends State<GearHeroCard> {
  late bool _myWhooshHintDismissed;

  @override
  void initState() {
    super.initState();
    _myWhooshHintDismissed = core.settings.getMyWhooshGearHintDismissed();
  }

  bool get _isMyWhooshActive => core.settings.getTrainerApp() is MyWhoosh;

  Future<void> _dismissMyWhooshHint() async {
    await core.settings.setMyWhooshGearHintDismissed(true);
    if (!mounted) return;
    setState(() => _myWhooshHintDismissed = true);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return AnimatedBuilder(
      animation: Listenable.merge([
        widget.definition.trainerMode,
        widget.definition.ergTargetPower,
        widget.definition.targetPowerW,
        widget.definition.currentGear,
        widget.definition.gearRatio,
        widget.definition.frontRing,
      ]),
      builder: (context, _) {
        final isErg = widget.definition.trainerMode.value == TrainerMode.ergMode;
        if (widget.simOnly && isErg) return const SizedBox.shrink();
        final showMyWhooshHint = !isErg && !_myWhooshHintDismissed && _isMyWhooshActive && !screenshotMode;
        final tile = SettingTile(
          icon: LucideIcons.cog,
          title: AppLocalizations.of(context).trainerControl,
          subtitle: isErg
              ? AppLocalizations.of(context).fixedTargetPowerMode
              : AppLocalizations.of(context).virtualGearShifting,
          trailing: widget.simOnly
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
                          widget.definition.setManualErgPower(
                            widget.definition.ergTargetPower.value ?? 150,
                          );
                        } else {
                          widget.definition.exitErgMode();
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
        if (!showMyWhooshHint) return tile;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: 8,
          children: [
            tile,
            Warning(
              important: false,
              children: [
                Row(
                  children: [
                    const Icon(Icons.info_outline, size: 18),
                    const Gap(8),
                    Expanded(
                      child: Text(AppLocalizations.of(context).myWhooshGearHintTitle).bold.small,
                    ),
                    IconButton.ghost(
                      icon: const Icon(Icons.close, size: 16),
                      onPressed: _dismissMyWhooshHint,
                    ),
                  ],
                ),
                Text(AppLocalizations.of(context).myWhooshGearHintBody).small,
              ],
            ),
          ],
        );
      },
    );
  }

  Widget _gearContent(BuildContext context, ColorScheme cs) {
    final gear = widget.definition.currentGear.value;
    final ratio = widget.definition.gearRatio.value;
    final target = widget.definition.targetPowerW.value;
    final isSmall = MediaQuery.sizeOf(context).width < 600;
    final subtitle = StringBuffer('of ${widget.definition.maxGear}  ·  ratio ${ratio.toStringAsFixed(2)}');
    if (target != null && widget.definition.trainerMode.value == TrainerMode.ergMode) {
      subtitle.write('  ·  target $target W');
    }
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          spacing: isSmall ? 12 : 28,
          children: [
            Expanded(child: SizedBox()),
            _shiftButton(
              context: context,
              icon: LucideIcons.minus,
              filled: false,
              onTap: () => widget.definition.shiftDown(),
            ),
            Text(
              '$gear',
              style: TextStyle(
                fontSize: isSmall ? 52 : 72,
                fontWeight: FontWeight.w700,
                letterSpacing: -2,
                color: cs.foreground,
              ),
            ),
            _shiftButton(
              context: context,
              icon: LucideIcons.plus,
              filled: true,
              onTap: () => widget.definition.shiftUp(),
            ),
            Expanded(child: SizedBox()),
          ],
        ),
        Text(
          subtitle.toString(),
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: cs.mutedForeground,
          ),
        ),
        if (widget.definition.frontShiftEnabled)
          Text(
            widget.definition.frontRing.value == FrontRing.large
                ? '2× · ${widget.definition.largeChainringTeeth}T'
                : '1× · ${widget.definition.smallChainringTeeth}T',
            style: TextStyle(fontSize: 13, color: cs.mutedForeground),
          ),
      ],
    );
  }

  Widget _ergContent(BuildContext context, ColorScheme cs) {
    final target = widget.definition.ergTargetPower.value ?? 150;
    final isSmall = MediaQuery.sizeOf(context).width < 600;
    return Column(
      spacing: isSmall ? 12 : 28,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Expanded(child: SizedBox()),
            _shiftButton(
              context: context,
              icon: LucideIcons.minus,
              filled: false,
              onTap: target > 0 ? () => widget.definition.setManualErgPower((target - 5).clamp(0, 500)) : null,
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  '$target',
                  style: TextStyle(
                    fontSize: isSmall ? 52 : 72,
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
              onTap: target < 500 ? () => widget.definition.setManualErgPower((target + 5).clamp(0, 500)) : null,
            ),
            Expanded(child: SizedBox()),
          ],
        ),
        Slider(
          value: SliderValue.single(target.toDouble()),
          min: 0,
          max: 500,
          divisions: 100,
          onChanged: (v) => widget.definition.setManualErgPower(v.value.round()),
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
          border: filled ? null : Border.all(color: cs.border, width: 2),
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
