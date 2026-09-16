import 'package:bike_control/bluetooth/devices/proxy/proxy_device.dart';
import 'package:bike_control/gen/l10n.dart';
import 'package:bike_control/main.dart';
import 'package:bike_control/models/shifting_config.dart';
import 'package:bike_control/pages/proxy_device_details/front_shift_card.dart';
import 'package:bike_control/pages/proxy_device_details/gear_hero_card.dart';
import 'package:bike_control/pages/proxy_device_details/gear_ratio_curve.dart';
import 'package:bike_control/pages/proxy_device_details/gear_ratio_presets.dart';
import 'package:bike_control/utils/core.dart';
import 'package:bike_control/widgets/ui/setting_tile.dart';
import 'package:bike_control/widgets/ui/stepper_control.dart';
import 'package:prop/emulators/definitions/fitness_bike_definition.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

class GearRatiosEditorPage extends StatefulWidget {
  final FitnessBikeDefinition definition;
  final ProxyDevice device;
  const GearRatiosEditorPage({super.key, required this.definition, required this.device});

  @override
  State<GearRatiosEditorPage> createState() => _GearRatiosEditorPageState();
}

class _GearRatiosEditorPageState extends State<GearRatiosEditorPage> {
  FitnessBikeDefinition get def => widget.definition;

  @override
  void initState() {
    super.initState();
    core.shiftingConfigs.addListener(_onConfigsChanged);
  }

  @override
  void dispose() {
    core.shiftingConfigs.removeListener(_onConfigsChanged);
    super.dispose();
  }

  void _onConfigsChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _updateActive(ShiftingConfig Function(ShiftingConfig) mutate) async {
    final current = core.shiftingConfigs.activeFor(widget.device.trainerKey);
    await core.shiftingConfigs.upsert(mutate(current));
  }

  Future<void> _saveActiveGearRatios(List<double>? ratios) async {
    final current = core.shiftingConfigs.activeFor(widget.device.trainerKey);
    if (ratios == null) {
      await core.shiftingConfigs.upsert(current.copyWith(clearGearRatios: true));
    } else {
      await core.shiftingConfigs.upsert(current.copyWith(gearRatios: ratios));
    }
  }

  Future<void> _resetGearSettings() async {
    final app = core.settings.getTrainerApp();
    final targetMaxGear = app?.virtualGearAmount ?? ShiftingConfig.maxGearDefault;
    def.setMaxGear(targetMaxGear);
    def.setGradeSmoothingEnabled(true);
    def.resetGearRatios();
    await _updateActive(
      (c) => c.copyWith(
        maxGear: targetMaxGear,
        gradeSmoothing: true,
        clearGearRatios: true,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      headers: [
        AppBar(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          leading: [
            IconButton.ghost(
              icon: const Icon(LucideIcons.arrowLeft, size: 24),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
          title: Text(
            AppLocalizations.of(context).gearSettings,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w600, letterSpacing: -0.3),
          ),
          trailing: [
            Button(
              style: ButtonStyle.destructive(size: ButtonSize.small),
              onPressed: _resetGearSettings,
              leading: const Icon(LucideIcons.rotateCcw, size: 12),
              child: Text(AppLocalizations.of(context).reset, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
            ),
          ],
          backgroundColor: cs.background,
        ),
        const Divider(),
      ],
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 800),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: 18,
              children: [
                _intro(context),
                if (!screenshotMode) ...[
                  GearHeroCard(definition: def, simOnly: true),
                  _vsModeCard(),
                  _gradeSmoothingCard(context),
                  _cadenceFilterCard(context),
                ],
                FrontShiftCard(device: widget.device, definition: def),
                _gearCountCard(context),
                _heroCurve(context),
                _presets(context),
                _perGearList(context),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _intro(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Text(
      AppLocalizations.of(context).tuneGearsIntro,
      style: TextStyle(fontSize: 13, color: cs.mutedForeground),
      softWrap: true,
    );
  }

  Widget _heroCurve(BuildContext context) => GearRatioCurve(definition: def);

  Widget _vsModeCard() => VirtualShiftingModeCard(definition: def, device: widget.device);

  Widget _gearCountCard(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final count = def.maxGear;
    final app = core.settings.getTrainerApp();
    final expected = app?.virtualGearAmount;
    final mismatch = app != null && expected != null && expected != count;
    return SettingTile(
      icon: LucideIcons.hash,
      title: AppLocalizations.of(context).gearCount,
      subtitle: AppLocalizations.of(context).gearCountDesc,
      trailing: StepperControl(
        value: count.toDouble(),
        step: 1.0,
        min: ShiftingConfig.maxGearMin.toDouble(),
        max: ShiftingConfig.maxGearMax.toDouble(),
        format: (v) => v.toStringAsFixed(0),
        onChanged: (v) async {
          final next = v.toInt();
          def.setMaxGear(next);
          await _updateActive((c) => c.copyWith(maxGear: next));
        },
      ),
      child: mismatch
          ? Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.amber.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.amber.withValues(alpha: 0.4)),
              ),
              child: Row(
                spacing: 8,
                children: [
                  Icon(LucideIcons.triangleAlert, size: 14, color: Colors.amber.shade700),
                  Expanded(
                    child: Text(
                      AppLocalizations.of(context).gearCountMismatch(app.name, expected, count),
                      style: TextStyle(fontSize: 12, color: cs.foreground),
                    ),
                  ),
                  Button.ghost(
                    onPressed: () async {
                      def.setMaxGear(expected);
                      await _updateActive((c) => c.copyWith(maxGear: expected));
                    },
                    child: Text(AppLocalizations.of(context).useGearCount(expected), style: const TextStyle(fontSize: 12)),
                  ),
                ],
              ),
            )
          : null,
    );
  }

  Widget _gradeSmoothingCard(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: def.gradeSmoothingEnabled,
      builder: (context, enabled, _) => SettingTile(
        icon: LucideIcons.waves,
        title: AppLocalizations.of(context).gradeSmoothing,
        subtitle: AppLocalizations.of(context).gradeSmoothingDesc,
        trailing: Switch(
          value: enabled,
          onChanged: (v) async {
            def.setGradeSmoothingEnabled(v);
            await _updateActive((c) => c.copyWith(gradeSmoothing: v));
          },
        ),
      ),
    );
  }

  Widget _cadenceFilterCard(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: def.cadenceFilterEnabled,
      builder: (context, enabled, _) => SettingTile(
        icon: LucideIcons.filter,
        title: AppLocalizations.of(context).cadenceFilter,
        subtitle: AppLocalizations.of(context).cadenceFilterDesc,
        trailing: Switch(
          value: enabled,
          onChanged: (v) async {
            def.setCadenceFilterEnabled(v);
            await _updateActive((c) => c.copyWith(cadenceFilterEnabled: v));
          },
        ),
      ),
    );
  }

  // ---------- Presets ----------

  static bool _ratiosMatch(List<double> a, List<double> b, {double tol = 0.001}) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if ((a[i] - b[i]).abs() > tol) return false;
    }
    return true;
  }

  Widget _presets(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 8,
      children: [
        Text(
          AppLocalizations.of(context).presetsLabel,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            letterSpacing: 1,
            color: cs.mutedForeground,
          ),
        ),
        ValueListenableBuilder<List<double>>(
          valueListenable: def.gearRatios,
          builder: (context, current, _) {
            return Row(
              spacing: 8,
              children: gearRatioPresets(
                context,
                def.maxGear,
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
        def.setGearRatios(preset.values);
        await _saveActiveGearRatios(preset.values);
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            preset.label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: active ? FontWeight.w700 : FontWeight.w600,
            ),
          ),
          Text(
            preset.range,
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w500,
              color: active ? const Color(0xFFA1A1AA) : cs.mutedForeground,
            ),
          ),
        ],
      ),
    );
  }

  // ---------- Per-gear list ----------

  Widget _perGearList(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 8,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              AppLocalizations.of(context).perGearLabel,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 1,
                color: cs.mutedForeground,
              ),
            ),
            const Text(
              '24 steps',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w500,
                color: Color(0xFFA1A1AA),
              ),
            ),
          ],
        ),
        AnimatedBuilder(
          animation: Listenable.merge([def.gearRatios, def.currentGear]),
          builder: (context, _) {
            final ratios = def.gearRatios.value;
            final current = def.currentGear.value;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: 6,
              // The store board only has to establish that every gear is
              // editable one by one; the rest of the 24 rows would just push
              // the cards above it off the phone.
              children: List<Widget>.generate(screenshotMode ? 3 : ratios.length, (i) {
                final gear = i + 1;
                return _gearRow(context, gear, ratios[gear - 1], ratios, current);
              }),
            );
          },
        ),
      ],
    );
  }

  Widget _gearRow(
    BuildContext context,
    int gear,
    double ratio,
    List<double> ratios,
    int current,
  ) {
    final cs = Theme.of(context).colorScheme;
    final isCurrent = gear == current;
    final isNeutral = gear == def.neutralGear;

    Color bgColor = cs.card;
    Color borderColor = cs.border;
    double borderWidth = 1;
    if (isCurrent) {
      bgColor = const Color(0xFFEFF6FF);
      borderColor = const Color(0xFFBFDBFE);
      borderWidth = 1.5;
    }

    Color badgeBoxBg = cs.muted;
    Color badgeBoxText = cs.foreground;
    if (isNeutral && !isCurrent) {
      badgeBoxBg = const Color(0xFFDBEAFE);
      badgeBoxText = const Color(0xFF1E40AF);
    }
    if (isCurrent) {
      badgeBoxBg = const Color(0xFF2563EB);
      badgeBoxText = Colors.white;
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: borderColor, width: borderWidth),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        spacing: 12,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: badgeBoxBg,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: Text(
                '$gear',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: badgeBoxText,
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
                      AppLocalizations.of(context).gearNumber(gear),
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                    if (isCurrent) _badge(AppLocalizations.of(context).currentBadge, const Color(0xFF2563EB), Colors.white),
                    if (isNeutral && !isCurrent) _badge(AppLocalizations.of(context).neutralBadge, const Color(0xFFDBEAFE), const Color(0xFF1E40AF)),
                  ],
                ),
                Text(
                  _hintFor(context, gear, ratio, ratios, def.neutralGear),
                  style: TextStyle(fontSize: 10, color: cs.mutedForeground),
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
            onChanged: (v) async {
              def.setGearRatio(gear, v);
              await _saveActiveGearRatios(def.gearRatios.value);
            },
          ),
        ],
      ),
    );
  }

  Widget _badge(String text, Color bg, Color fg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: fg),
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

  // Fixed so a "Recommended" tag on one card never makes it taller than its
  // two siblings — see the ambiguity resolution in task-8-brief.md.
  static const double _radioCardContentHeight = 44;

  Widget _vsRadioCard(
    BuildContext context,
    String label,
    VirtualShiftingMode value, {
    required bool recommended,
  }) {
    final supported = definition.supportsVirtualShiftingMode(value);
    return Expanded(
      child: RadioCard<VirtualShiftingMode>(
        value: value,
        enabled: supported,
        child: SizedBox(
          height: _radioCardContentHeight,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                label,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
              ),
              if (recommended) ...[
                const Gap(2),
                Text(AppLocalizations.of(context).vsModeRecommended).xSmall.muted,
              ],
            ],
          ),
        ),
      ),
    );
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
                child: Row(
                  spacing: 6,
                  children: [
                    _vsRadioCard(
                      context,
                      AppLocalizations.of(context).targetPowerMode,
                      VirtualShiftingMode.targetPower,
                      recommended: defaultMode == VirtualShiftingMode.targetPower,
                    ),
                    _vsRadioCard(
                      context,
                      AppLocalizations.of(context).trackResistanceMode,
                      VirtualShiftingMode.trackResistance,
                      recommended: defaultMode == VirtualShiftingMode.trackResistance,
                    ),
                    _vsRadioCard(
                      context,
                      AppLocalizations.of(context).basicMode,
                      VirtualShiftingMode.basicResistance,
                      recommended: defaultMode == VirtualShiftingMode.basicResistance,
                    ),
                  ],
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
