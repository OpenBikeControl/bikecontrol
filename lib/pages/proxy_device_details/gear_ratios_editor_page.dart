import 'package:bike_control/bluetooth/devices/proxy/proxy_device.dart';
import 'package:bike_control/gen/l10n.dart';
import 'package:bike_control/models/shifting_config.dart';
import 'package:bike_control/pages/proxy_device_details/gear_ratio_curve.dart';
import 'package:bike_control/pages/proxy_device_details/gear_ratio_presets.dart';
import 'package:bike_control/utils/core.dart';
import 'package:bike_control/widgets/ui/bk_grouped_section.dart';
import 'package:bike_control/widgets/ui/bk_page_header.dart';
import 'package:bike_control/widgets/ui/setting_tile.dart';
import 'package:bike_control/widgets/ui/stepper_control.dart';
import 'package:bike_control/widgets/ui/type_scale.dart';
import 'package:prop/emulators/definitions/fitness_bike_definition.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

// The parts of the gear editor. The editor used to be one page behind the
// trainer's "Gear Settings" row; it is now Settings → Virtual shifting (the
// curve, presets, gear count and switches, see VirtualShiftingSettingsPage)
// with only the per-gear steppers one screen deeper, in [PerGearRatiosPage].

/// Applies [mutate] to [device]'s active shifting config and stores it.
Future<void> updateActiveShiftingConfig(ProxyDevice device, ShiftingConfig Function(ShiftingConfig) mutate) async {
  final current = core.shiftingConfigs.activeFor(device.trainerKey);
  await core.shiftingConfigs.upsert(mutate(current));
}

/// Stores [ratios] as [device]'s custom curve; null goes back to the stock one.
Future<void> saveActiveGearRatios(ProxyDevice device, List<double>? ratios) async {
  final current = core.shiftingConfigs.activeFor(device.trainerKey);
  if (ratios == null) {
    await core.shiftingConfigs.upsert(current.copyWith(clearGearRatios: true));
  } else {
    await core.shiftingConfigs.upsert(current.copyWith(gearRatios: ratios));
  }
}

bool _ratiosMatch(List<double> a, List<double> b, {double tol = 0.001}) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if ((a[i] - b[i]).abs() > tol) return false;
  }
  return true;
}

/// The preset [ratios] match, if any — what "Per-gear ratios" says the curve is.
GearRatioPreset? matchingGearRatioPreset(BuildContext context, List<double> ratios) {
  for (final preset in gearRatioPresets(context, ratios.length)) {
    if (_ratiosMatch(preset.values, ratios)) return preset;
  }
  return null;
}

/// "Default · 24 gears", or "Custom ratios · 24 gears" once a gear was edited.
String perGearRatiosSummary(BuildContext context, List<double> ratios) {
  final l10n = AppLocalizations.of(context);
  final preset = matchingGearRatioPreset(context, ratios);
  return '${preset?.label ?? l10n.customRatios} · ${l10n.gearsCount(ratios.length)}';
}

/// PRESETS and the four one-tap curves under it. They sit right under the
/// ratio curve because each of them changes it in one tap.
class GearRatioPresetChips extends StatelessWidget {
  const GearRatioPresetChips({super.key, required this.definition, required this.device});

  final FitnessBikeDefinition definition;
  final ProxyDevice device;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 8,
      children: [
        Text(
          AppLocalizations.of(context).presetsLabel,
          style: context.typography.caption.copyWith(
            fontWeight: FontWeight.w700,
            letterSpacing: 1,
            color: cs.mutedForeground,
          ),
        ),
        ValueListenableBuilder<List<double>>(
          valueListenable: definition.gearRatios,
          builder: (context, current, _) {
            return Row(
              spacing: 8,
              children: gearRatioPresets(
                context,
                definition.maxGear,
              ).map((p) => Expanded(child: _presetButton(context, p, current))).toList(),
            );
          },
        ),
      ],
    );
  }

  Widget _presetButton(BuildContext context, GearRatioPreset preset, List<double> current) {
    final cs = Theme.of(context).colorScheme;
    final active = _ratiosMatch(preset.values, current);
    return Button(
      style: active ? ButtonStyle.primary(size: ButtonSize.small) : ButtonStyle.outline(size: ButtonSize.small),
      onPressed: () async {
        definition.setGearRatios(preset.values);
        await saveActiveGearRatios(device, preset.values);
      },
      // Four chips share a phone's width, and a preset name like "Compact" or
      // "Predeterminado" is wider than a quarter of it: the label is kept on
      // one line and shrunk to fit rather than broken mid-word.
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              preset.label,
              maxLines: 1,
              softWrap: false,
              style: context.typography.xSmall.copyWith(
                fontWeight: active ? FontWeight.w700 : FontWeight.w600,
              ),
            ),
            Text(
              preset.range,
              maxLines: 1,
              softWrap: false,
              style: context.typography.caption.copyWith(
                fontWeight: FontWeight.w500,
                color: active ? cs.primaryForeground.withValues(alpha: 0.8) : cs.mutedForeground,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Gear Count with its stepper. BikeControl's gear count is its own: it is
/// not synced with the trainer app's, and the overlay is what shows the rider
/// the gear they are actually in.
class GearCountRow extends StatelessWidget {
  const GearCountRow({super.key, required this.definition, required this.device});

  final FitnessBikeDefinition definition;
  final ProxyDevice device;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final count = definition.maxGear;
    return BkGroupedRow(
      icon: LucideIcons.hash,
      title: l10n.gearCount,
      subtitle: l10n.gearCountDesc,
      trailing: StepperControl(
        value: count.toDouble(),
        step: 1.0,
        min: ShiftingConfig.maxGearMin.toDouble(),
        max: ShiftingConfig.maxGearMax.toDouble(),
        format: (v) => v.toStringAsFixed(0),
        onChanged: (v) async {
          final next = v.toInt();
          definition.setMaxGear(next);
          await updateActiveShiftingConfig(device, (c) => c.copyWith(maxGear: next));
        },
      ),
    );
  }
}

/// Virtual shifting → Per-gear ratios: one ±0.05 stepper per gear, with the
/// ratio curve pinned above the rows so an edit to one gear shows up in the
/// curve straight away.
class PerGearRatiosPage extends StatefulWidget {
  final FitnessBikeDefinition definition;
  final ProxyDevice device;
  const PerGearRatiosPage({super.key, required this.definition, required this.device});

  @override
  State<PerGearRatiosPage> createState() => _PerGearRatiosPageState();
}

class _PerGearRatiosPageState extends State<PerGearRatiosPage> {
  FitnessBikeDefinition get def => widget.definition;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      headers: [BkPageHeader(title: l10n.perGearRatiosTitle)],
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
                child: GearRatioCurve(definition: def, compact: true),
              ),
              BkGroupedDivider(indent: 0),
              Expanded(
                child: AnimatedBuilder(
                  animation: Listenable.merge([def.gearRatios, def.currentGear]),
                  builder: (context, _) {
                    final ratios = def.gearRatios.value;
                    final current = def.currentGear.value;
                    return ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                      itemCount: ratios.length + 1,
                      separatorBuilder: (_, i) => Gap(i == 0 ? 8 : 6),
                      itemBuilder: (context, i) {
                        if (i == 0) return _header(context, ratios.length);
                        final gear = i;
                        return GearRatioRow(
                          definition: def,
                          gear: gear,
                          ratios: ratios,
                          current: current,
                          onChanged: (v) async {
                            def.setGearRatio(gear, v);
                            await saveActiveGearRatios(widget.device, def.gearRatios.value);
                          },
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// PER-GEAR and how many rows follow — they follow the gear count.
  Widget _header(BuildContext context, int count) {
    final cs = Theme.of(context).colorScheme;
    final style = context.typography.caption.copyWith(color: cs.mutedForeground);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          AppLocalizations.of(context).perGearLabel,
          style: style.copyWith(fontWeight: FontWeight.w700, letterSpacing: 1),
        ),
        Text(AppLocalizations.of(context).perGearCount(count), style: style.copyWith(fontWeight: FontWeight.w500)),
      ],
    );
  }
}

/// One gear of the per-gear list: its number, CURRENT / NEUTRAL, how it sits
/// against the neutral gear, and a ±0.05 stepper.
class GearRatioRow extends StatelessWidget {
  const GearRatioRow({
    super.key,
    required this.definition,
    required this.gear,
    required this.ratios,
    required this.current,
    required this.onChanged,
  });

  final FitnessBikeDefinition definition;
  final int gear;
  final List<double> ratios;
  final int current;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context);
    final ratio = ratios[gear - 1];
    final isCurrent = gear == current;
    final isNeutral = gear == definition.neutralGear;
    final colors = gearRowColors(cs, isCurrent: isCurrent, isNeutral: isNeutral);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
      decoration: BoxDecoration(
        color: colors.background,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: colors.border, width: isCurrent ? 1.5 : 1),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        spacing: 12,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: colors.badgeBackground,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: Text(
                '$gear',
                style: context.typography.small.copyWith(
                  fontWeight: FontWeight.w700,
                  color: colors.badgeForeground,
                ),
              ),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: 2,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  spacing: 6,
                  children: [
                    Text(
                      l10n.gearNumber(gear),
                      style: context.typography.small.copyWith(fontWeight: FontWeight.w600),
                    ),
                    if (isCurrent) _badge(context, l10n.currentBadge, cs.primary, cs.primaryForeground),
                    if (isNeutral && !isCurrent)
                      _badge(context, l10n.neutralBadge, colors.badgeBackground, colors.badgeForeground),
                  ],
                ),
                Text(
                  _hintFor(context, gear, ratio, ratios, definition.neutralGear),
                  style: context.typography.caption.copyWith(color: cs.mutedForeground),
                ),
              ],
            ),
          ),
          StepperControl(
            value: ratio,
            step: 0.05,
            min: 0.10,
            max: 10.0,
            format: (v) => v.toStringAsFixed(2),
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }

  Widget _badge(BuildContext context, String text, Color bg, Color fg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: context.typography.caption.copyWith(fontWeight: FontWeight.w700, color: fg),
      ),
    );
  }
}

String _hintFor(BuildContext context, int gear, double ratio, List<double> ratios, int neutralGear) {
  final l10n = AppLocalizations.of(context);
  if (gear == neutralGear) {
    return l10n.referenceBaseRatio;
  }
  final neutral = ratios[neutralGear - 1];
  final delta = ratio - neutral;
  if (delta.abs() < 0.05) return l10n.closeToNeutral;
  final mag = delta.abs().toStringAsFixed(2);
  if (delta > 0) return l10n.harderThanNeutral(mag);
  return l10n.easierThanNeutral(mag);
}

/// The Virtual Shifting mode selector (Target Power / Track Resistance / Basic),
/// extracted from [GearRatiosEditorPage] so it can be rendered standalone (e.g.
/// for a widget snapshot). It reads/writes the same [core.shiftingConfigs] and
/// the passed [definition], so behaviour inside the page is unchanged.
class VirtualShiftingModeCard extends StatelessWidget {
  final FitnessBikeDefinition definition;
  final ProxyDevice device;
  const VirtualShiftingModeCard({
    super.key,
    required this.definition,
    required this.device,
  });

  Future<void> _updateActive(ShiftingConfig Function(ShiftingConfig) mutate) async {
    final current = core.shiftingConfigs.activeFor(device.trainerKey);
    await core.shiftingConfigs.upsert(mutate(current));
  }

  // Side by side, the three cards must stay the same height regardless of
  // which one (if any) shows the "Recommended" tag, and a translated label
  // must never be clipped instead of wrapping: the Row is wrapped in
  // IntrinsicHeight with CrossAxisAlignment.stretch (see build()), so every
  // card takes the tallest card's own natural height.
  //
  // Side by side is only used where every word of every label fits its card:
  // a word wider than the card would be broken mid-word ("Track Re" /
  // "sistance", "Zielleistu" / "ng"). Otherwise — a phone, or a language with
  // long compounds — the options stack as full-width rows (see [_stacks]).
  Widget _vsRadioCard(
    BuildContext context,
    String label,
    VirtualShiftingMode value, {
    required bool recommended,
    required bool stacked,
  }) {
    final supported = definition.supportsVirtualShiftingMode(value);
    final l10n = AppLocalizations.of(context);
    final card = RadioCard<VirtualShiftingMode>(
      value: value,
      enabled: supported,
      child: stacked
          ? Row(
              children: [
                Expanded(
                  child: Text(label, style: _labelStyle(context, stacked: true)),
                ),
                if (recommended) ...[
                  const Gap(8),
                  Text(l10n.vsModeRecommended).xSmall.muted,
                ],
              ],
            )
          : Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  label,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: _labelStyle(context, stacked: false),
                ),
                if (recommended) ...[
                  const Gap(2),
                  Text(l10n.vsModeRecommended).xSmall.muted,
                ],
              ],
            ),
    );
    return stacked ? card : Expanded(child: card);
  }

  static TextStyle _labelStyle(BuildContext context, {required bool stacked}) =>
      (stacked ? context.typography.small : context.typography.xSmall).copyWith(fontWeight: FontWeight.w600);

  static const double _cardGap = 6;

  /// Whether the options have to stack: some word of a label (or of the
  /// "Recommended" tag) is wider than a third of [width] leaves for text.
  bool _stacks(BuildContext context, double width, List<String> labels) {
    final theme = Theme.of(context);
    // RadioCard's own padding on both sides plus its border, and a little
    // slack so a word that only just fits isn't broken by rounding.
    final inset = 2 * theme.density.baseContainerPadding * theme.scaling + 4 * theme.scaling + 2;
    final available = (width - 2 * _cardGap) / 3 - inset;
    final scaler = MediaQuery.textScalerOf(context);
    final direction = Directionality.of(context);
    bool tooWide(String text, TextStyle style) => text.split(RegExp(r'\s+')).any((word) {
      final painter = TextPainter(
        text: TextSpan(text: word, style: style),
        textDirection: direction,
        textScaler: scaler,
        maxLines: 1,
      )..layout();
      final w = painter.width;
      painter.dispose();
      return w > available;
    });
    final labelStyle = DefaultTextStyle.of(context).style.merge(_labelStyle(context, stacked: false));
    final tagStyle = DefaultTextStyle.of(context).style.merge(theme.typography.xSmall);
    return labels.any((label) => tooWide(label, labelStyle)) ||
        tooWide(AppLocalizations.of(context).vsModeRecommended, tagStyle);
  }

  /// The description for [mode], prefixed with a "not supported" notice when
  /// the connected trainer can't actually carry it (e.g. a saved preference
  /// that survived a reconnect onto a lesser trainer).
  String _descriptionFor(BuildContext context, VirtualShiftingMode mode) {
    final l10n = AppLocalizations.of(context);
    final desc = switch (mode) {
      VirtualShiftingMode.trackResistance => l10n.vsModeTrackResistanceDesc,
      VirtualShiftingMode.targetPower => l10n.vsModeTargetPowerDesc,
      VirtualShiftingMode.basicResistance => l10n.vsModeBasicDesc,
    };
    if (!definition.supportsVirtualShiftingMode(mode)) {
      return '${l10n.vsModeUnsupported}$desc';
    }
    return desc;
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([definition.virtualShiftingMode, definition.trainerFeature]),
      builder: (context, _) {
        final mode = definition.virtualShiftingMode.value;
        final defaultMode = definition.defaultVirtualShiftingMode;
        return SettingTile(
          title: AppLocalizations.of(context).virtualShiftingMode,
          subtitle: AppLocalizations.of(context).virtualShiftingModeDesc,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              RadioGroup<VirtualShiftingMode>(
                value: mode,
                onChanged: (v) async {
                  definition.setVirtualShiftingMode(v);
                  await _updateActive((c) => c.copyWith(mode: v));
                },
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final l10n = AppLocalizations.of(context);
                    final options = [
                      (l10n.targetPowerMode, VirtualShiftingMode.targetPower),
                      (l10n.trackResistanceMode, VirtualShiftingMode.trackResistance),
                      (l10n.basicMode, VirtualShiftingMode.basicResistance),
                    ];
                    final stacked = _stacks(context, constraints.maxWidth, [for (final o in options) o.$1]);
                    final cards = [
                      for (final (label, value) in options)
                        _vsRadioCard(context, label, value, recommended: defaultMode == value, stacked: stacked),
                    ];
                    if (stacked) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        spacing: _cardGap,
                        children: cards,
                      );
                    }
                    // IntrinsicHeight + stretch: all three cards take the
                    // height of whichever one actually needs the most room (a
                    // wrapped 2-line label, the Recommended tag, or both) —
                    // never a fixed guess that a translated label could
                    // outgrow.
                    return IntrinsicHeight(
                      child: Row(
                        spacing: _cardGap,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: cards,
                      ),
                    );
                  },
                ),
              ),
              const Gap(8),
              Text(_descriptionFor(context, mode)).xSmall.muted,
            ],
          ),
        );
      },
    );
  }
}

/// Colours for one row of the per-gear list, all derived from the theme so
/// the current row stays legible in dark mode (it used to be a fixed #EFF6FF
/// wash under near-white text).
@visibleForTesting
({Color background, Color border, Color badgeBackground, Color badgeForeground}) gearRowColors(
  ColorScheme cs, {
  required bool isCurrent,
  required bool isNeutral,
}) {
  if (isCurrent) {
    return (
      background: cs.primary.withValues(alpha: 0.10),
      border: cs.primary.withValues(alpha: 0.45),
      badgeBackground: cs.primary,
      badgeForeground: cs.primaryForeground,
    );
  }
  if (isNeutral) {
    return (
      background: cs.card,
      border: cs.border,
      badgeBackground: cs.primary.withValues(alpha: 0.15),
      badgeForeground: cs.foreground,
    );
  }
  return (background: cs.card, border: cs.border, badgeBackground: cs.muted, badgeForeground: cs.foreground);
}
