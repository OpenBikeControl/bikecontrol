import 'package:bike_control/widgets/drivetrain/chain_geometry.dart';
import 'package:bike_control/utils/erg_power_stepping.dart';
import 'package:bike_control/utils/gear_readout.dart';
import 'package:bike_control/utils/i18n_extension.dart';
import 'package:bike_control/widgets/drivetrain/drivetrain_controls.dart' show FrontRingToggle;
import 'package:bike_control/widgets/drivetrain/trainer_drivetrain.dart';
import 'package:bike_control/widgets/ui/bk_tappable.dart';
import 'package:bike_control/widgets/ui/bk_touch_target.dart';
import 'package:bike_control/widgets/ui/app_theme.dart' show BkStatusColors;
import 'package:bike_control/widgets/ui/colors.dart';
import 'package:bike_control/widgets/ui/type_scale.dart';
import 'package:flutter/foundation.dart' show defaultTargetPlatform;
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
/// drives, − / + to shift, and power / cadence / ratio — plus heart rate
/// while a source reports one.
///
/// In ERG the big number is the target power and − / + step it. The SIM / ERG
/// segments only report the mode.
///
/// The header holds two links: "Virtual shifting ›" opens how the trainer
/// shifts (Settings → Virtual shifting), the trainer's name opens the trainer
/// itself (its hardware page). [footer] sits under the numbers, behind a
/// hairline — Ride's gear-overlay offer.
class VirtualShiftingCard extends StatelessWidget {
  const VirtualShiftingCard({
    super.key,
    required this.definition,
    required this.trainerName,
    this.dim = false,
    this.onOpenSettings,
    this.onOpenTrainer,
    this.footer,
    this.layout = VsCardLayout.beside,
  });

  final FitnessBikeDefinition definition;
  final String trainerName;

  /// Paired, but not carrying gears right now — see [TrainerDrivetrain.dim].
  final bool dim;

  /// Opens Settings → Virtual shifting.
  final VoidCallback? onOpenSettings;

  /// Opens the trainer's page.
  final VoidCallback? onOpenTrainer;

  final Widget? footer;

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
        definition.heartRateBpm,
      ]),
      builder: (context, _) {
        final erg = definition.trainerMode.value == TrainerMode.ergMode;
        // On touch the header links are 48 tall and take over the card's top
        // padding and the gap below them (see [_HeaderLink]), so the text
        // stays about where it was.
        final touch = _HeaderLink.touch;
        return Container(
          padding: EdgeInsets.fromLTRB(16, touch ? 0 : 16, 16, 16),
          decoration: BoxDecoration(color: cs.card, borderRadius: BorderRadius.circular(16)),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final width = constraints.maxWidth;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _header(context, erg),
                  if (!touch) const Gap(12),
                  if (layout == VsCardLayout.stacked) ..._stacked(context, erg, width) else _beside(context, erg, width),
                  if (footer case final footer?) ...[
                    const Gap(14),
                    DecoratedBox(
                      decoration: BoxDecoration(border: Border(top: BorderSide(color: cs.border, width: 1))),
                      child: Padding(padding: const EdgeInsets.only(top: 6), child: footer),
                    ),
                  ],
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
    final accent = bkAccentText(context);
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _HeaderLink(
                key: const ValueKey('ride-vs-settings-link'),
                alignment: AlignmentDirectional.bottomStart,
                onPressed: onOpenSettings,
                label: l.rideVirtualShifting,
                children: [
                  Flexible(
                    child: Text(
                      l.rideVirtualShifting,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.typography.base.copyWith(fontWeight: FontWeight.w600, color: cs.foreground),
                    ),
                  ),
                  if (onOpenSettings != null) Icon(LucideIcons.chevronRight, size: 16, color: accent),
                ],
              ),
              _HeaderLink(
                key: const ValueKey('ride-vs-trainer-link'),
                alignment: AlignmentDirectional.topStart,
                onPressed: onOpenTrainer,
                label: trainerName,
                children: [
                  Container(
                    width: 7,
                    height: 7,
                    decoration: BoxDecoration(
                      color: dim ? cs.mutedForeground : BkStatusColors.of(context).success,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const Gap(6),
                  Flexible(
                    child: Text(
                      trainerName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.typography.small.copyWith(color: cs.mutedForeground),
                    ),
                  ),
                  if (onOpenTrainer != null) Icon(LucideIcons.chevronRight, size: 14, color: cs.mutedForeground),
                ],
              ),
            ],
          ),
        ),
        const Gap(8),
        _ModeIndicator(erg: erg),
      ],
    );
  }

  // ── Layouts ───────────────────────────────────────────────────────────

  Widget _beside(BuildContext context, bool erg, double width) {
    // Up to the stacked layout's 176 on a wide card (an iPad in portrait),
    // so the gear stays the largest thing on it.
    final numeral = (width * 0.27).clamp(84.0, 176.0);
    final button = width >= 480 ? 56.0 : 48.0;
    // The picture is never taller than the numeral beside it; on a phone the
    // column is narrower than this anyway.
    final pictureWidth = numeral * kDrivetrainBox.width / kDrivetrainBox.height;
    final row = Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: pictureWidth),
                  child: _picture(erg),
                ),
              ),
              if (definition.frontShiftEnabled) Align(child: FrontRingToggle(definition: definition)),
              if (!_hasHeart) ...[const Gap(8), _stats(context, erg)],
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
    // Four readings don't fit the drivetrain's column; with heart rate the
    // row runs the card's full width under the gear.
    if (!_hasHeart) return row;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [row, const Gap(12), _stats(context, erg)],
    );
  }

  /// Heart rate is a reading only while a source reports a real one.
  int? get _heart => switch (definition.heartRateBpm.value) {
    final bpm? when bpm > 0 => bpm,
    _ => null,
  };

  bool get _hasHeart => _heart != null;

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
          Expanded(child: RideStat(value: power?.toString() ?? '--', unit: 'W', label: l.sensorQuantityPower)),
          Expanded(child: RideStat(value: cadence?.toString() ?? '--', unit: 'rpm', label: l.sensorQuantityCadence)),
          Expanded(
            child: erg
                ? const SizedBox.shrink()
                : RideStat(value: formatGearRatio(definition.gearRatio.value), label: l.rideRatio),
          ),
          if (_heart case final heart?)
            Expanded(
              child: RideStat(
                key: const ValueKey('ride-stat-heart'),
                value: '$heart',
                unit: 'bpm',
                label: l.sensorQuantityHeartRate,
              ),
            ),
        ],
      ),
    );
  }
}

/// One of the card header's two links: a row of text that opens something,
/// tall enough to hit on its own, with a focus ring and a spoken name.
class _HeaderLink extends StatelessWidget {
  const _HeaderLink({
    super.key,
    required this.onPressed,
    required this.label,
    required this.alignment,
    required this.children,
  });

  final VoidCallback? onPressed;
  final String label;

  /// Where the text sits in a touch-height link: the title at the bottom of
  /// its 48 and the trainer name at the top of its own, so the two lines stay
  /// as close together as the 32-tall pointer links, and the extra height
  /// stands in for the card's top padding and the gap under the header.
  final AlignmentGeometry alignment;
  final List<Widget> children;

  /// The height with a mouse: two of them stack in the header.
  static const double pointerHeight = 32;

  /// Whether the links are thumb-sized: touch platforms get a full 48 each.
  static bool get touch =>
      defaultTargetPlatform == TargetPlatform.android || defaultTargetPlatform == TargetPlatform.iOS;

  @override
  Widget build(BuildContext context) {
    final row = Row(mainAxisSize: MainAxisSize.min, children: children);
    return BkTappable(
      onPressed: onPressed,
      label: label,
      excludeChildSemantics: true,
      borderRadius: BorderRadius.circular(8),
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: touch ? BkTouchTarget.minSize : pointerHeight),
        child: Padding(
          padding: EdgeInsetsDirectional.only(end: 6, top: touch ? 4 : 0, bottom: touch ? 4 : 0),
          child: touch ? Align(alignment: alignment, widthFactor: 1, child: row) : row,
        ),
      ),
    );
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

/// One number of a stats row: the value in the display face, its unit smaller
/// and muted, and a label under it. Ride's card and the Devices trainer row
/// share it.
class RideStat extends StatelessWidget {
  const RideStat({super.key, required this.value, required this.label, this.unit, this.scale = 1.1});

  final String value;
  final String? unit;
  final String label;

  /// Of `x2Large`: 1.1 on Ride's card, smaller in a list row.
  final double scale;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final big = (context.typography.x2Large.fontSize ?? 24) * scale;
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
