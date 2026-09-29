import 'package:bike_control/utils/erg_power_stepping.dart';
import 'package:bike_control/utils/i18n_extension.dart';
import 'package:bike_control/widgets/drivetrain/drivetrain_controls.dart' show FrontRingToggle;
import 'package:bike_control/widgets/drivetrain/trainer_drivetrain.dart';
import 'package:bike_control/widgets/ui/bk_tappable.dart';
import 'package:bike_control/widgets/ui/bk_touch_target.dart';
import 'package:bike_control/widgets/ui/colors.dart';
import 'package:bike_control/widgets/ui/type_scale.dart';
import 'package:flutter/services.dart' show HapticFeedback;
import 'package:prop/emulators/definitions/fitness_bike_definition.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

/// How the virtual shifting card arranges the drivetrain and the gear.
enum VsCardLayout {
  /// The drivetrain on the left, the gear and − / + on the right (phone,
  /// medium windows, and one-column desktop).
  beside,

  /// − gear + across the top, the drivetrain full width under it — for a
  /// narrow column that is still tall (Ride's left column from 840).
  stacked,
}

/// Ride's hero: the live gear of a bridged trainer, the drivetrain picture it
/// drives, − / + to shift, and power / cadence / ratio.
///
/// In ERG the big number is the target power and − / + step it, as on the
/// trainer's own page. The SIM / ERG segments only report the mode — the
/// switch lives on the trainer page, which the header opens.
class VirtualShiftingCard extends StatelessWidget {
  const VirtualShiftingCard({
    super.key,
    required this.definition,
    required this.trainerName,
    this.dim = false,
    this.onOpen,
    this.layout = VsCardLayout.beside,
  });

  final FitnessBikeDefinition definition;
  final String trainerName;

  /// Paired, but not carrying gears right now — see [TrainerDrivetrain.dim].
  final bool dim;

  /// Opens the trainer's page.
  final VoidCallback? onOpen;

  final VsCardLayout layout;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return AnimatedBuilder(
      animation: Listenable.merge([
        definition.trainerMode,
        definition.ergTargetPower,
        definition.currentGear,
        definition.gearRatio,
        definition.gearRatios,
        definition.powerW,
        definition.cadenceRpm,
      ]),
      builder: (context, _) {
        final erg = definition.trainerMode.value == TrainerMode.ergMode;
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: cs.card, borderRadius: BorderRadius.circular(16)),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final width = constraints.maxWidth;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _header(context, erg),
                  const Gap(12),
                  if (layout == VsCardLayout.stacked) ..._stacked(context, erg, width) else _beside(context, erg, width),
                ],
              );
            },
          ),
        );
      },
    );
  }

  Widget _header(BuildContext context, bool erg) {
    final cs = Theme.of(context).colorScheme;
    final l = context.i18n;
    return Row(
      children: [
        Expanded(
          child: Align(
            alignment: AlignmentDirectional.centerStart,
            child: BkTappable(
              onPressed: onOpen,
              label: '${l.rideVirtualShifting}, $trainerName',
              excludeChildSemantics: true,
              borderRadius: BorderRadius.circular(8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    l.rideVirtualShifting,
                    style: context.typography.base.copyWith(fontWeight: FontWeight.w600, color: cs.foreground),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(
                        child: Text(
                          trainerName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: context.typography.small.copyWith(color: cs.mutedForeground),
                        ),
                      ),
                      if (onOpen != null) Icon(LucideIcons.chevronRight, size: 14, color: cs.mutedForeground),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
        const Gap(8),
        _ModeIndicator(erg: erg),
      ],
    );
  }

  // ── Layouts ───────────────────────────────────────────────────────────

  Widget _beside(BuildContext context, bool erg, double width) {
    final numeral = (width * 0.27).clamp(84.0, 140.0);
    final button = width >= 480 ? 56.0 : 48.0;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              _picture(erg),
              if (definition.frontShiftEnabled) Align(child: FrontRingToggle(definition: definition)),
              const Gap(8),
              _stats(context, erg),
            ],
          ),
        ),
        const Gap(12),
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _number(context, erg, numeral),
            const Gap(12),
            Row(
              mainAxisSize: MainAxisSize.min,
              spacing: 8,
              children: [_down(context, erg, button), _up(context, erg, button)],
            ),
          ],
        ),
      ],
    );
  }

  List<Widget> _stacked(BuildContext context, bool erg, double width) {
    final numeral = (width * 0.4).clamp(96.0, 176.0);
    return [
      Row(
        children: [
          _down(context, erg, 56),
          Expanded(child: Center(child: _number(context, erg, numeral))),
          _up(context, erg, 56),
        ],
      ),
      const Gap(16),
      // Full width would make the picture taller than the gear it explains.
      Center(
        child: SizedBox(width: (width * 0.8).clamp(0.0, 420.0), child: _picture(erg)),
      ),
      if (definition.frontShiftEnabled) Align(child: FrontRingToggle(definition: definition)),
      const Gap(12),
      _stats(context, erg),
    ];
  }

  // ── Parts ─────────────────────────────────────────────────────────────

  /// Dimmed in ERG too: the trainer holds a power target there, and the gear
  /// the picture shows is not what the rider feels.
  Widget _picture(bool erg) =>
      TrainerDrivetrain(definition: definition, showGear: false, framed: false, dim: dim || erg);

  /// The gear (or ERG target) in a box sized for the widest value it can
  /// show, so − / + never move under a thumb as the number changes width.
  Widget _number(BuildContext context, bool erg, double size) {
    final cs = Theme.of(context).colorScheme;
    // Three-digit ERG targets get a smaller face so they fit the same box.
    final style = BkNumerals.gear(erg ? size * 0.72 : size, color: cs.foreground, height: 0.8);
    final value = erg ? '${definition.ergTargetPower.value ?? 0}' : '${definition.currentGear.value}';
    final widest = erg ? '000' : '0' * '${definition.maxGear}'.length;
    return Column(
      key: const ValueKey('ride-vs-number'),
      mainAxisSize: MainAxisSize.min,
      children: [
        Stack(
          alignment: Alignment.center,
          children: [
            Visibility(
              visible: false,
              maintainSize: true,
              maintainAnimation: true,
              maintainState: true,
              child: Text(widest, style: style),
            ),
            Text(value, style: style),
          ],
        ),
        Text(
          erg ? 'W' : context.i18n.gearOfMax('${definition.maxGear}'),
          style: BkNumerals.display(
            (context.typography.base.fontSize ?? 16) * 1.1,
            color: cs.mutedForeground,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _down(BuildContext context, bool erg, double size) {
    final l = context.i18n;
    final target = definition.ergTargetPower.value;
    return _ShiftButton(
      icon: LucideIcons.minus,
      filled: false,
      size: size,
      label: erg ? l.a11yDecrease : l.actionShiftDown,
      onTap: erg
          ? (target != null && target > 0 ? () => definition.stepManualErgPower(up: false) : null)
          : () => definition.shiftDown(),
    );
  }

  Widget _up(BuildContext context, bool erg, double size) {
    final l = context.i18n;
    final target = definition.ergTargetPower.value;
    return _ShiftButton(
      icon: LucideIcons.plus,
      filled: true,
      size: size,
      label: erg ? l.a11yIncrease : l.actionShiftUp,
      onTap: erg
          ? (target != null && target < ErgPowerStepping.maxManualW
                ? () => definition.stepManualErgPower(up: true)
                : null)
          : () => definition.shiftUp(),
    );
  }

  Widget _stats(BuildContext context, bool erg) {
    final l = context.i18n;
    final cs = Theme.of(context).colorScheme;
    final power = definition.powerW.value;
    final cadence = definition.cadenceRpm.value;
    return Container(
      padding: const EdgeInsets.only(top: 10),
      decoration: BoxDecoration(border: Border(top: BorderSide(color: cs.border, width: 1))),
      child: Row(
        children: [
          Expanded(child: _Stat(value: power?.toString() ?? '--', unit: 'W', label: l.sensorQuantityPower)),
          Expanded(child: _Stat(value: cadence?.toString() ?? '--', unit: 'rpm', label: l.sensorQuantityCadence)),
          Expanded(
            child: erg
                ? const SizedBox.shrink()
                : _Stat(value: '×${_ratio(definition.gearRatio.value)}', label: l.rideRatio),
          ),
        ],
      ),
    );
  }

  /// "2.4" for 2.40, "1.75" for 1.75: as short as the value allows.
  static String _ratio(double ratio) {
    var text = ratio.toStringAsFixed(2);
    if (text.endsWith('0')) text = text.substring(0, text.length - 1);
    return text;
  }
}

/// SIM | ERG, the current one filled. Reports the mode; it is not a switch.
class _ModeIndicator extends StatelessWidget {
  const _ModeIndicator({required this.erg});

  final bool erg;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l = context.i18n;
    Widget segment(String text, bool on) => Container(
      constraints: const BoxConstraints(minWidth: 52),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      alignment: Alignment.center,
      decoration: BoxDecoration(color: on ? cs.primary : null, borderRadius: BorderRadius.circular(8)),
      child: Text(
        text,
        style: context.typography.small.copyWith(
          fontWeight: FontWeight.w600,
          letterSpacing: 0.3,
          color: on ? cs.primaryForeground : cs.mutedForeground,
        ),
      ),
    );
    return Semantics(
      label: '${l.trainerControl}: ${erg ? l.ergMode : l.simMode}',
      excludeSemantics: true,
      child: Container(
        height: 36,
        padding: const EdgeInsets.all(2),
        decoration: BoxDecoration(color: cs.muted, borderRadius: BorderRadius.circular(10)),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [segment(l.simMode, !erg), segment(l.ergMode, erg)],
        ),
      ),
    );
  }
}

class _ShiftButton extends StatelessWidget {
  const _ShiftButton({
    required this.icon,
    required this.filled,
    required this.size,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final bool filled;
  final double size;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final enabled = onTap != null;
    return BkTappable(
      onPressed: onTap == null
          ? null
          : () {
              onTap!();
              HapticFeedback.selectionClick();
            },
      label: label,
      excludeChildSemantics: true,
      borderRadius: BorderRadius.circular(size / 2),
      child: Opacity(
        opacity: enabled ? 1 : 0.4,
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(color: filled ? cs.primary : cs.muted, shape: BoxShape.circle),
          child: Icon(icon, size: size * 0.46, color: filled ? cs.primaryForeground : cs.foreground),
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.value, required this.label, this.unit});

  final String value;
  final String? unit;
  final String label;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final big = (context.typography.x2Large.fontSize ?? 24) * 1.1;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text.rich(
          TextSpan(
            children: [
              TextSpan(text: value, style: BkNumerals.display(big, color: cs.foreground)),
              if (unit != null)
                TextSpan(
                  text: ' $unit',
                  style: BkNumerals.display(big * 0.55, color: cs.mutedForeground, fontWeight: FontWeight.w600),
                ),
            ],
          ),
          maxLines: 1,
          overflow: TextOverflow.fade,
          softWrap: false,
        ),
        Text(label, style: context.typography.xSmall.copyWith(color: cs.mutedForeground)),
      ],
    );
  }
}

/// A compact Ride card that stands in for a section that has nothing live to
/// show yet: an icon tile, a title, one line of body and, when there is
/// something to do about it, an action.
class RidePromptCard extends StatelessWidget {
  const RidePromptCard({
    super.key,
    required this.icon,
    required this.title,
    required this.body,
    this.bodyColor,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String body;

  /// For a body that is a status ("Lost connection").
  final Color? bodyColor;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
      decoration: BoxDecoration(color: cs.card, borderRadius: BorderRadius.circular(16)),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(color: cs.muted, borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, size: 20, color: cs.foreground),
          ),
          const Gap(12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(title, style: context.typography.base.copyWith(fontWeight: FontWeight.w600)),
                const Gap(2),
                Text(body, style: context.typography.small.copyWith(color: bodyColor ?? cs.mutedForeground)),
              ],
            ),
          ),
          if (actionLabel != null && onAction != null) ...[
            const Gap(8),
            BkTouchTarget(
              child: PrimaryButton(
                alignment: Alignment.center,
                size: ButtonSize.small,
                onPressed: onAction,
                child: Text(actionLabel!),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// One quiet line where a card would be too much — "MyWhoosh handles
/// shifting" — with a link to change it.
class RideStatusLine extends StatelessWidget {
  const RideStatusLine({super.key, required this.icon, required this.text, this.actionLabel, this.onAction});

  final IconData icon;
  final String text;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        children: [
          Icon(icon, size: 16, color: cs.mutedForeground),
          const Gap(8),
          Expanded(child: Text(text, style: context.typography.small.copyWith(color: cs.mutedForeground))),
          if (actionLabel != null && onAction != null)
            Button.ghost(
              onPressed: onAction,
              child: Text(
                actionLabel!,
                style: context.typography.small.copyWith(color: bkAccentText(context), fontWeight: FontWeight.w600),
              ),
            ),
        ],
      ),
    );
  }
}
