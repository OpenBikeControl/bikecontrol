import 'dart:math' as math;

import 'package:bike_control/widgets/drivetrain/chain_geometry.dart';
import 'package:bike_control/utils/erg_power_stepping.dart';
import 'package:bike_control/utils/gear_readout.dart';
import 'package:bike_control/utils/i18n_extension.dart';
import 'package:bike_control/widgets/drivetrain/drivetrain_controls.dart' show FrontRingToggle;
import 'package:bike_control/widgets/drivetrain/drivetrain_view.dart';
import 'package:bike_control/widgets/drivetrain/trainer_drivetrain.dart';
import 'package:bike_control/widgets/ui/bk_brand_band.dart';
import 'package:bike_control/widgets/ui/bk_skeleton.dart';
import 'package:bike_control/widgets/ui/bk_tappable.dart';
import 'package:bike_control/widgets/ui/bk_touch_target.dart';
import 'package:bike_control/widgets/ui/app_theme.dart' show BkBrandColors, BkStatusColors;
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
/// segments switch the trainer between the two.
///
/// The header holds two links: "Virtual shifting ›" opens how the trainer
/// shifts (Settings → Virtual shifting), the trainer's name opens the trainer
/// itself (its hardware page). [footer] sits under the numbers, behind a
/// hairline — Ride's gear-overlay offer.
class VirtualShiftingCard extends StatelessWidget {
  const VirtualShiftingCard({
    super.key,
    required FitnessBikeDefinition this.definition,
    required this.trainerName,
    this.dim = false,
    this.dimNotice,
    this.trialNotice,
    this.onOpenSettings,
    this.onOpenTrainer,
    this.footer,
    this.layout = VsCardLayout.beside,
  });

  /// The card while [trainerName] is still connecting: the live card's
  /// layout, at its size, with nothing live in it — the drivetrain still and
  /// muted, no gear, no readings, the controls inert, and a quiet shimmer
  /// over the parts that are on their way. When the trainer arrives the live
  /// card takes its place without anything around it moving.
  const VirtualShiftingCard.connecting({
    super.key,
    required this.trainerName,
    this.onOpenTrainer,
    this.layout = VsCardLayout.beside,
  }) : definition = null,
       dim = true,
       dimNotice = null,
       trialNotice = null,
       onOpenSettings = null,
       footer = null;

  /// Null while connecting — see [VirtualShiftingCard.connecting].
  final FitnessBikeDefinition? definition;
  final String trainerName;

  bool get _connecting => definition == null;

  /// Until the trainer says otherwise, the most common cassette.
  int get _maxGear => definition?.maxGear ?? 24;
  bool get _frontShift => definition?.frontShiftEnabled ?? false;

  /// Paired, but not carrying gears right now — see [TrainerDrivetrain.dim].
  final bool dim;

  /// One line under the gear while [dim]: why − / + change the number but
  /// nothing the rider feels. Not shown when null.
  final String? dimNotice;

  /// One line under the gear once today's virtual shifting trial is over:
  /// what that means for the ride. Not shown when null.
  final String? trialNotice;

  /// Opens Settings → Virtual shifting.
  final VoidCallback? onOpenSettings;

  /// Opens the trainer's page.
  final VoidCallback? onOpenTrainer;

  final Widget? footer;

  final VsCardLayout layout;

  @override
  Widget build(BuildContext context) {
    final definition = this.definition;
    if (definition == null) return _card(context, erg: false);
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
      builder: (context, _) => _card(context, erg: definition.trainerMode.value == TrainerMode.ergMode),
    );
  }

  Widget _card(BuildContext context, {required bool erg}) {
    final cs = Theme.of(context).colorScheme;
    // On touch the header links are 48 tall and take over the band's padding
    // (see [_HeaderLink]), so the text stays about where it was.
    final touch = _HeaderLink.touch;
    const radius = Radius.circular(16);
    return Container(
      decoration: BoxDecoration(
        color: cs.card,
        borderRadius: const BorderRadius.all(radius),
        boxShadow: bkCardShadow(context),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // The header is the brand band: the one card riders look at.
          BkBrandBand(
            borderRadius: const BorderRadius.vertical(top: radius),
            padding: EdgeInsets.fromLTRB(16, touch ? 0 : 12, 16, touch ? 0 : 12),
            child: Builder(builder: (context) => _header(context, erg)),
          ),
          // The card's 16 plus a deliberate 8 under the band, so the gear
          // reads as the card's content rather than the header's caption.
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16 + 8, 16, 16),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final width = constraints.maxWidth;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (layout == VsCardLayout.stacked)
                      ..._stacked(context, erg, width)
                    else
                      _beside(context, erg, width),
                    if (dim && dimNotice != null) ...[
                      const Gap(12),
                      _CardNote(
                        key: const ValueKey('ride-vs-dim-notice'),
                        icon: LucideIcons.info,
                        text: dimNotice!,
                      ),
                    ],
                    if (trialNotice case final notice?) ...[
                      const Gap(12),
                      _CardNote(key: const ValueKey('ride-vs-trial-notice'), icon: LucideIcons.clock, text: notice),
                    ],
                    if (_footer(context) case final footer?) ...[
                      const Gap(14),
                      DecoratedBox(
                        decoration: BoxDecoration(
                          border: Border(top: BorderSide(color: cs.border, width: 1)),
                        ),
                        child: Padding(padding: const EdgeInsets.only(top: 6), child: footer),
                      ),
                    ],
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  /// While connecting, "Connecting…" where the settings line will be — the
  /// live card always has one, so the placeholder keeps its height.
  Widget? _footer(BuildContext context) {
    if (!_connecting) return footer;
    final cs = Theme.of(context).colorScheme;
    return SizedBox(
      key: const ValueKey('ride-vs-connecting'),
      height: BkTouchTarget.minSize,
      child: Row(
        children: [
          Icon(LucideIcons.bluetooth, size: 15, color: cs.mutedForeground),
          const Gap(8),
          Expanded(
            child: BkShimmer(
              child: Text(
                context.i18n.chainStatusConnecting,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.typography.small.copyWith(color: cs.mutedForeground, fontWeight: FontWeight.w500),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _header(BuildContext context, bool erg) {
    final cs = Theme.of(context).colorScheme;
    final l = context.i18n;
    final accent = bkAccentText(context);
    final titleStyle = context.typography.base.copyWith(fontWeight: FontWeight.w600, color: cs.foreground);
    final trainerStyle = context.typography.small.copyWith(color: cs.mutedForeground);
    final title = _HeaderLink(
      key: const ValueKey('ride-vs-settings-link'),
      alignment: AlignmentDirectional.bottomStart,
      onPressed: onOpenSettings,
      label: l.rideVirtualShifting,
      children: [
        Flexible(
          // Two lines rather than an ellipsis when even the header's full
          // width is too narrow for it.
          child: Text(
            l.rideVirtualShifting,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            // The chevron follows the longer line, not the column's edge.
            textWidthBasis: TextWidthBasis.longestLine,
            style: titleStyle,
          ),
        ),
        if (onOpenSettings != null) Icon(LucideIcons.chevronRight, size: 16, color: accent),
      ],
    );
    final trainer = _HeaderLink(
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
            // On the band the green dot wears a white ring, so it
            // reads against the blue.
            boxShadow: !dim && BkBrandBand.isOn(context) ? [BoxShadow(color: cs.foreground, spreadRadius: 1.5)] : null,
          ),
        ),
        const Gap(6),
        Flexible(
          child: Text(trainerName, maxLines: 1, overflow: TextOverflow.ellipsis, style: trainerStyle),
        ),
        if (onOpenTrainer != null) Icon(LucideIcons.chevronRight, size: 14, color: cs.mutedForeground),
      ],
    );
    final modeSwitch = _ModeSwitch(definition: definition, erg: erg);
    return LayoutBuilder(
      builder: (context, constraints) {
        // The title and the trainer's name beside the switch while both fit
        // there whole; otherwise the title takes the header's full width and
        // the switch moves down beside the trainer — never "Virtual shi…".
        // Chevrons counted whether shown or not, so the connecting card picks
        // the live card's arrangement and nothing moves when it arrives.
        final titleWidth = _textWidth(context, l.rideVirtualShifting, titleStyle) + 16;
        final trainerWidth = 13 + _textWidth(context, trainerName, trainerStyle) + 14;
        final textWidth = math.max(titleWidth, trainerWidth) + _HeaderLink.endPadding;
        final beside = textWidth + 8 + _ModeSwitch.widthIn(context) <= constraints.maxWidth;
        if (beside) {
          return Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [title, trainer],
                ),
              ),
              const Gap(8),
              modeSwitch,
            ],
          );
        }
        return Column(
          key: const ValueKey('ride-vs-header-stacked'),
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            title,
            Row(
              children: [
                Expanded(
                  child: Align(alignment: AlignmentDirectional.centerStart, child: trainer),
                ),
                const Gap(8),
                modeSwitch,
              ],
            ),
          ],
        );
      },
    );
  }

  /// [text]'s width on one line in [style], as the header lays it out.
  static double _textWidth(BuildContext context, String text, TextStyle style) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: DefaultTextStyle.of(context).style.merge(style)),
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
      maxLines: 1,
    )..layout();
    final width = painter.width;
    painter.dispose();
    return width.ceilToDouble();
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
    // The readings sit under the drivetrain while every label fits its column
    // on one line; four readings, or labels as long as German's, move to the
    // card's full width under the gear instead of breaking mid-word.
    final stats = _statItems(context, erg);
    final columnWidth = width - 12 - _gearColumnWidth(context, erg, numeral, button);
    final statsBeside = _StatsRow.fitsOneLine(context, stats, columnWidth);
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
              if (_frontShift) Align(child: FrontRingToggle(definition: definition!)),
              if (statsBeside) ...[const Gap(8), _StatsRow(stats: stats)],
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
    if (statsBeside) return row;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        row,
        const Gap(12),
        _StatsRow(stats: stats),
      ],
    );
  }

  /// How wide the gear column beside the drivetrain is: the widest value the
  /// numeral box holds, its "of 24" / "W" line, or − / + side by side.
  double _gearColumnWidth(BuildContext context, bool erg, double numeral, double button) {
    final widest = erg ? '000' : '0' * '$_maxGear'.length;
    final number = _measure(
      context,
      TextSpan(text: widest, style: BkNumerals.gear(erg ? numeral * 0.72 : numeral, height: 0.8)),
    );
    final caption = _measure(
      context,
      TextSpan(
        text: erg ? 'W' : context.i18n.gearOfMax('$_maxGear'),
        style: BkNumerals.display((context.typography.base.fontSize ?? 16) * 1.1, fontWeight: FontWeight.w600),
      ),
    );
    return [number, caption, button * 2 + 8].reduce((a, b) => a > b ? a : b);
  }

  /// Heart rate is a reading only while a source reports a real one.
  int? get _heart => switch (definition?.heartRateBpm.value) {
    final bpm? when bpm > 0 => bpm,
    _ => null,
  };

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
      if (_frontShift) Align(child: FrontRingToggle(definition: definition!)),
      const Gap(12),
      _StatsRow(stats: _statItems(context, erg)),
    ];
  }

  // ── Parts ─────────────────────────────────────────────────────────────

  /// Dimmed in ERG too: the trainer holds a power target there, and the gear
  /// the picture shows is not what the rider feels.
  Widget _picture(bool erg) {
    final definition = this.definition;
    if (definition == null) {
      // Still and muted, mid-cassette: the shape of what is coming, not a
      // gear anyone is in.
      return BkShimmer(
        child: DrivetrainView(
          gear: _maxGear ~/ 2,
          gearCount: _maxGear,
          moving: false,
          dim: true,
          showGear: false,
          framed: false,
        ),
      );
    }
    return TrainerDrivetrain(definition: definition, showGear: false, framed: false, dim: dim || erg);
  }

  /// How far, per em, the numeral's figures reach above its 0.8 line box:
  /// about 0.04 for a flat top ("1"), round tops ("2", "0") overshoot more.
  static const double _inkOverhang = 0.06;

  /// The gear (or ERG target) in a box sized for the widest value it can
  /// show, so − / + never move under a thumb as the number changes width.
  Widget _number(BuildContext context, bool erg, double size) {
    final cs = Theme.of(context).colorScheme;
    // Three-digit ERG targets get a smaller face so they fit the same box.
    final style = BkNumerals.gear(
      erg ? size * 0.72 : size,
      color: _connecting ? cs.mutedForeground : cs.foreground,
      height: 0.8,
    );
    final definition = this.definition;
    final value = definition == null
        ? '–'
        : erg
        ? '${definition.ergTargetPower.value ?? 0}'
        : '${definition.currentGear.value}';
    final widest = erg ? '000' : '0' * '$_maxGear'.length;
    return Column(
      key: const ValueKey('ride-vs-number'),
      mainAxisSize: MainAxisSize.min,
      children: [
        // In a 0.8 line box Barlow Condensed's figures stand a little proud
        // of the box's top; inset by that much so the ink, not the box,
        // keeps the card's spacing under the band.
        SizedBox(height: (style.fontSize ?? size) * _inkOverhang),
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
            if (definition == null)
              BkShimmer(
                child: BkBone(width: size * 0.62, height: size * 0.6, radius: 14),
              )
            else
              Text(value, style: style),
          ],
        ),
        Text(
          erg ? 'W' : context.i18n.gearOfMax('$_maxGear'),
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
    final definition = this.definition;
    final target = definition?.ergTargetPower.value;
    return _ShiftButton(
      icon: LucideIcons.minus,
      filled: false,
      size: size,
      label: erg ? l.a11yDecrease : l.actionShiftDown,
      felt: !dim,
      onTap: definition == null
          ? null
          : erg
          ? (target != null && target > 0 ? () => definition.stepManualErgPower(up: false) != null : null)
          : () => definition.shiftDown(),
    );
  }

  Widget _up(BuildContext context, bool erg, double size) {
    final l = context.i18n;
    final definition = this.definition;
    final target = definition?.ergTargetPower.value;
    return _ShiftButton(
      icon: LucideIcons.plus,
      filled: true,
      size: size,
      label: erg ? l.a11yIncrease : l.actionShiftUp,
      felt: !dim,
      onTap: definition == null
          ? null
          : erg
          ? (target != null && target < ErgPowerStepping.maxManualW
                ? () => definition.stepManualErgPower(up: true) != null
                : null)
          : () => definition.shiftUp(),
    );
  }

  /// Power, cadence, the ratio (a blank slot in ERG, so the others keep
  /// their places) and heart rate while a source reports one.
  List<_Stat> _statItems(BuildContext context, bool erg) {
    final l = context.i18n;
    final power = definition?.powerW.value;
    final cadence = definition?.cadenceRpm.value;
    return [
      _Stat(
        RideStat(value: power?.toString() ?? '--', unit: 'W', label: l.sensorQuantityPower),
        widest: '000',
      ),
      _Stat(
        RideStat(value: cadence?.toString() ?? '--', unit: 'rpm', label: l.sensorQuantityCadence),
        widest: '000',
      ),
      erg
          ? const _Stat.blank()
          : _Stat(
              RideStat(
                value: definition == null ? '--' : formatGearRatio(definition!.gearRatio.value),
                label: l.rideRatio,
              ),
              widest: '×0.00',
            ),
      if (_heart case final heart?)
        _Stat(
          RideStat(
            key: const ValueKey('ride-stat-heart'),
            value: '$heart',
            unit: 'bpm',
            label: l.sensorQuantityHeartRate,
          ),
          widest: '000',
        ),
    ];
  }
}

/// A reading of the stats row, and the widest value it expects to show — so
/// the row is laid out once for the ride, not again as power passes 100 W.
class _Stat {
  const _Stat(RideStat this.stat, {required this.widest});

  const _Stat.blank() : stat = null, widest = '';

  final RideStat? stat;
  final String widest;

  /// What the reading needs with its label on one line.
  double width(BuildContext context) {
    final stat = this.stat;
    if (stat == null) return 0;
    return RideStat.intrinsicWidth(context, value: widest, unit: stat.unit, label: stat.label, scale: stat.scale);
  }
}

/// The card's readings behind a hairline, each label on one line.
///
/// Equal columns while every reading fits one (English on a phone); columns
/// sized to their readings while the row as a whole fits; otherwise two rows
/// of equal columns. A label never breaks mid-word.
class _StatsRow extends StatelessWidget {
  const _StatsRow({required this.stats});

  final List<_Stat> stats;

  /// Room between two readings, so neighbouring labels never touch.
  static const double gap = 8;

  /// Whether [stats] fit one row [width] wide.
  static bool fitsOneLine(BuildContext context, List<_Stat> stats, double width) {
    final widths = [for (final s in stats) s.width(context)];
    return widths.fold(0.0, (a, b) => a + b) + gap * (stats.length - 1) <= width;
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.only(top: 10),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: cs.border, width: 1)),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          final widths = [for (final s in stats) s.width(context)];
          Widget cell(int i) => stats[i].stat ?? const SizedBox.shrink();

          // Equal columns: the phone's English look.
          final equal = width / stats.length;
          if (widths.every((w) => w + gap <= equal)) {
            return Row(children: [for (var i = 0; i < stats.length; i++) Expanded(child: cell(i))]);
          }
          // Each reading its own width, the room left shared out.
          if (fitsOneLine(context, stats, width)) {
            final spare = (width - widths.fold(0.0, (a, b) => a + b) - gap * (stats.length - 1)) / stats.length;
            return Row(
              spacing: gap,
              children: [
                for (var i = 0; i < stats.length; i++) SizedBox(width: widths[i] + spare, child: cell(i)),
              ],
            );
          }
          // Two rows of equal columns, lined up under each other.
          final perRow = (stats.length / 2).ceil();
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            spacing: 10,
            children: [
              for (var start = 0; start < stats.length; start += perRow)
                Row(
                  children: [
                    for (var i = start; i < start + perRow; i++)
                      Expanded(child: i < stats.length ? cell(i) : const SizedBox.shrink()),
                  ],
                ),
            ],
          );
        },
      ),
    );
  }
}

/// Lays [span] out on one line in [context]'s text scale; its width.
double _measure(BuildContext context, InlineSpan span) {
  final painter = TextPainter(
    text: span,
    textDirection: Directionality.of(context),
    textScaler: MediaQuery.textScalerOf(context),
    maxLines: 1,
  )..layout();
  final width = painter.width;
  painter.dispose();
  return width;
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

  /// The room a link keeps after its text.
  static const double endPadding = 6;

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
          padding: EdgeInsetsDirectional.only(end: endPadding, top: touch ? 4 : 0, bottom: touch ? 4 : 0),
          child: touch ? Align(alignment: alignment, widthFactor: 1, child: row) : row,
        ),
      ),
    );
  }
}

/// SIM | ERG, the current one filled — a switch, like the "Switch ERG/SIM"
/// button action: ERG holds the last power target (150 W the first time)
/// and keeps it against the trainer app's terrain until the rider picks SIM
/// again, which hands the trainer back to gears and grade.
class _ModeSwitch extends StatelessWidget {
  const _ModeSwitch({required this.definition, required this.erg});

  /// Null while the trainer connects: the switch is drawn, inert.
  final FitnessBikeDefinition? definition;
  final bool erg;

  /// What ERG starts at when there is no target yet; the button action's.
  static const int defaultErgW = 150;

  static const double _segmentMinWidth = 52;
  static const double _segmentPadding = 12;
  static const double _trackInset = 2;

  static TextStyle _labelStyle(BuildContext context) =>
      context.typography.small.copyWith(fontWeight: FontWeight.w600, letterSpacing: 0.3);

  /// The switch's width as it lays itself out, so the header can tell
  /// whether the title still fits beside it.
  static double widthIn(BuildContext context) {
    final l = context.i18n;
    double segment(String text) => math.max(
      _segmentMinWidth,
      VirtualShiftingCard._textWidth(context, text, _labelStyle(context)) + 2 * _segmentPadding,
    );
    return 2 * _trackInset + segment(l.simMode) + segment(l.ergMode);
  }

  void _select(bool toErg) {
    final definition = this.definition;
    if (definition == null || toErg == erg) return;
    if (toErg) {
      definition.setManualErgPower(definition.ergTargetPower.value ?? defaultErgW);
    } else {
      definition.exitErgMode();
    }
    HapticFeedback.selectionClick();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l = context.i18n;
    // Each segment is a full 48 on touch, inside the track's 2 px inset.
    final height = _HeaderLink.touch ? BkTouchTarget.minSize + 4 : 36.0;
    Widget segment(String text, bool forErg) {
      final on = forErg == erg;
      return BkTappable(
        key: ValueKey(forErg ? 'ride-vs-mode-erg' : 'ride-vs-mode-sim'),
        onPressed: definition == null ? null : () => _select(forErg),
        label: text,
        selected: on,
        inMutuallyExclusiveGroup: true,
        excludeChildSemantics: true,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          constraints: const BoxConstraints(minWidth: _segmentMinWidth),
          padding: const EdgeInsets.symmetric(horizontal: _segmentPadding),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: on ? (definition == null ? cs.border : cs.primary) : null,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            text,
            style: _labelStyle(context).copyWith(
              color: on && definition != null ? cs.primaryForeground : cs.mutedForeground,
            ),
          ),
        ),
      );
    }

    return Semantics(
      label: l.trainerControl,
      container: true,
      explicitChildNodes: true,
      child: Container(
        height: height,
        padding: const EdgeInsets.all(_trackInset),
        decoration: BoxDecoration(color: cs.muted, borderRadius: BorderRadius.circular(10)),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [segment(l.simMode, false), segment(l.ergMode, true)],
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
    this.felt = true,
  });

  final IconData icon;
  final bool filled;
  final double size;
  final String label;

  /// Shifts, and says whether anything changed — false at the top or bottom
  /// gear, or at the end of the ERG range.
  final bool Function()? onTap;

  /// Whether a shift reaches the trainer. While it does not (the card is
  /// dimmed), the number still moves but nothing buzzes: the haptic is the
  /// promise that the rider will feel it.
  final bool felt;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final enabled = onTap != null;
    return BkTappable(
      onPressed: onTap == null
          ? null
          : () {
              final changed = onTap!();
              if (changed && felt) HapticFeedback.selectionClick();
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

  static TextSpan _valueSpan(
    BuildContext context,
    String value,
    String? unit,
    double scale, {
    Color? color,
    Color? unitColor,
  }) {
    final big = (context.typography.x2Large.fontSize ?? 24) * scale;
    return TextSpan(
      children: [
        TextSpan(
          text: value,
          style: BkNumerals.display(big, color: color),
        ),
        if (unit != null)
          TextSpan(
            text: ' $unit',
            style: BkNumerals.display(big * 0.55, color: unitColor, fontWeight: FontWeight.w600),
          ),
      ],
    );
  }

  static TextStyle _labelStyle(BuildContext context) => context.typography.xSmall;

  /// The width a reading needs to show [value] and its [label] each on one
  /// line.
  static double intrinsicWidth(
    BuildContext context, {
    required String value,
    required String label,
    String? unit,
    double scale = 1.1,
  }) {
    final number = _measure(context, _valueSpan(context, value, unit, scale));
    final text = _measure(
      context,
      TextSpan(text: label, style: DefaultTextStyle.of(context).style.merge(_labelStyle(context))),
    );
    return number > text ? number : text;
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text.rich(
          _valueSpan(context, value, unit, scale, color: cs.foreground, unitColor: cs.mutedForeground),
          maxLines: 1,
          overflow: TextOverflow.fade,
          softWrap: false,
        ),
        Text(label, style: _labelStyle(context).copyWith(color: cs.mutedForeground)),
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
    this.actionIsSecondary = false,
  });

  final IconData icon;
  final String title;
  final String body;

  /// Whether the action is the quieter option rather than the thing to do —
  /// the body already says what to do, and the button offers an alternative.
  final bool actionIsSecondary;

  /// For a body that is a status ("Lost connection").
  final Color? bodyColor;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
      decoration: BoxDecoration(
        color: cs.card,
        borderRadius: BorderRadius.circular(16),
        boxShadow: bkCardShadow(context),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: BkBrandColors.of(context).tileWash,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 20, color: BkBrandColors.of(context).tileInk),
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
              child: actionIsSecondary
                  ? OutlineButton(
                      alignment: Alignment.center,
                      size: ButtonSize.small,
                      onPressed: onAction,
                      child: Text(actionLabel!),
                    )
                  : PrimaryButton(
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

/// One quiet line under the gear: what the selected mode does, or, on a
/// dimmed card, why the gears change nothing right now.
class _CardNote extends StatelessWidget {
  const _CardNote({super.key, required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Icon(icon, size: 15, color: cs.mutedForeground),
        ),
        const Gap(8),
        Expanded(
          child: Text(text, style: context.typography.small.copyWith(color: cs.mutedForeground)),
        ),
      ],
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
          Expanded(
            child: Text(text, style: context.typography.small.copyWith(color: cs.mutedForeground)),
          ),
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
