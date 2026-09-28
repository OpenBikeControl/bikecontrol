import 'package:bike_control/utils/window_size.dart';
import 'package:bike_control/utils/i18n_extension.dart';
import 'package:bike_control/widgets/ui/bk_icon_button.dart';
import 'package:bike_control/gen/l10n.dart';
import 'package:bike_control/main.dart' show screenshotMode;
import 'package:bike_control/utils/core.dart';
import 'package:bike_control/utils/erg_power_stepping.dart';
import 'package:bike_control/utils/keymap/apps/my_whoosh.dart';
import 'package:bike_control/widgets/drivetrain/drivetrain_controls.dart';
import 'package:bike_control/widgets/ui/setting_tile.dart';
import 'package:bike_control/widgets/ui/type_scale.dart';
import 'package:bike_control/widgets/ui/warning.dart';
import 'package:prop/emulators/definitions/fitness_bike_definition.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

class GearHeroCard extends StatefulWidget {
  final FitnessBikeDefinition definition;

  /// When true, the card renders only in SIM mode and hides (returns an
  /// empty widget) in ERG mode. The mode switch is also omitted since the
  /// surface is dedicated to gear shifting.
  final bool simOnly;

  /// Opens the Virtual Shifting settings — gear count, ratios, weights. Null
  /// hides the Edit affordance (the onboarding preview has nothing to open).
  final VoidCallback? onEditSettings;

  const GearHeroCard({super.key, required this.definition, this.simOnly = false, this.onEditSettings});

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
        final isSmall = isCompactWindow(context);
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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                width: double.infinity,
                // A phone has no width to spare: the drivetrain is the widest
                // thing on the card and every pixel of inset comes off it.
                padding: isSmall
                    ? const EdgeInsets.symmetric(vertical: 10, horizontal: 6)
                    : const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
                decoration: BoxDecoration(
                  color: cs.muted,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: cs.border,
                  ),
                ),
                child: isErg ? _ergContent(context, cs) : _gearContent(),
              ),
              // Everything this card *shows* is live; everything that shapes it
              // — gear count, ratios, weights — lives further down the page.
              if (widget.onEditSettings != null)
                Align(
                  alignment: AlignmentDirectional.centerEnd,
                  child: Button.ghost(
                    onPressed: widget.onEditSettings,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          AppLocalizations.of(context).chainEdit,
                          style: context.typography.small.copyWith(fontWeight: FontWeight.w600, color: cs.primary),
                        ),
                        Icon(LucideIcons.chevronRight, size: 15, color: cs.primary),
                      ],
                    ),
                  ),
                ),
            ],
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
                    const Icon(LucideIcons.info, size: 18),
                    const Gap(8),
                    Expanded(
                      child: Text(AppLocalizations.of(context).myWhooshGearHintTitle).bold.small,
                    ),
                    BkIconButton.ghost(
                      icon: const Icon(LucideIcons.x, size: 16),
                      label: context.i18n.a11yDismiss,
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

  Widget _gearContent() => DrivetrainControls(definition: widget.definition);

  Widget _ergContent(BuildContext context, ColorScheme cs) {
    final target = widget.definition.ergTargetPower.value ?? 150;
    final isSmall = isCompactWindow(context);
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
              label: AppLocalizations.of(context).a11yDecrease,
              onTap: target > 0 ? () => widget.definition.stepManualErgPower(up: false) : null,
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
                    fontFeatures: BkNumerals.tabular,
                  ),
                ),
                const Gap(4),
                Text(
                  'W',
                  style: context.typography.large.copyWith(
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
              label: AppLocalizations.of(context).a11yIncrease,
              onTap: target < ErgPowerStepping.maxManualW ? () => widget.definition.stepManualErgPower(up: true) : null,
            ),
            Expanded(child: SizedBox()),
          ],
        ),
        Slider(
          value: SliderValue.single(target.toDouble()),
          min: 0,
          max: ErgPowerStepping.maxManualW.toDouble(),
          divisions: 100,
          onChanged: (v) => widget.definition.setManualErgPower(v.value.round()),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '0 W',
              style: context.typography.caption.copyWith(color: cs.mutedForeground),
            ),
            Text(
              '${ErgPowerStepping.maxManualW} W',
              style: context.typography.caption.copyWith(color: cs.mutedForeground),
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
        style: context.typography.caption.copyWith(
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
    required String label,
    required VoidCallback? onTap,
  }) {
    final cs = Theme.of(context).colorScheme;
    final disabled = onTap == null;
    return Semantics(
      container: true,
      button: true,
      enabled: !disabled,
      label: label,
      child: _ergButton(cs, disabled, icon: icon, filled: filled, onTap: onTap),
    );
  }

  Widget _ergButton(
    ColorScheme cs,
    bool disabled, {
    required IconData icon,
    required bool filled,
    required VoidCallback? onTap,
  }) {
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
