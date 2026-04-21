import 'dart:ui';

import 'package:bike_control/bluetooth/devices/proxy/proxy_device.dart';
import 'package:bike_control/models/shifting_config.dart';
import 'package:bike_control/pages/proxy_device_details/gear_ratio_curve.dart';
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
          title: const Text(
            'Gear Settings',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600, letterSpacing: -0.3),
          ),
          trailing: [
            Button(
              style: ButtonStyle.destructive(size: ButtonSize.small),
              onPressed: _resetGearSettings,
              leading: const Icon(LucideIcons.rotateCcw, size: 12),
              child: const Text('Reset', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
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
                _gradeSmoothingCard(context),
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
      'Tune each virtual gear to match your ride feel. Changes apply instantly.',
      style: TextStyle(fontSize: 13, color: cs.mutedForeground),
      softWrap: true,
    );
  }

  Widget _heroCurve(BuildContext context) => GearRatioCurve(definition: def);

  Widget _gearCountCard(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final count = def.maxGear;
    final app = core.settings.getTrainerApp();
    final expected = app?.virtualGearAmount;
    final mismatch = app != null && expected != null && expected != count;
    return SettingTile(
      icon: LucideIcons.hash,
      title: 'Gear Count',
      subtitle: 'Size of the virtual shifter',
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
                      '${app.name} uses $expected gears, this config uses $count. '
                      'The gear displayed in ${app.name} may not match.',
                      style: TextStyle(fontSize: 12, color: cs.foreground),
                    ),
                  ),
                  Button.ghost(
                    onPressed: () async {
                      def.setMaxGear(expected);
                      await _updateActive((c) => c.copyWith(maxGear: expected));
                    },
                    child: Text('Use $expected', style: const TextStyle(fontSize: 12)),
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
        title: 'Grade Smoothing',
        subtitle: 'Averages sudden slope changes',
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

  // ---------- Presets ----------

  static List<double> _evenSteps(double lo, double hi, int count) =>
      List<double>.generate(count, (i) => lerpDouble(lo, hi, count == 1 ? 0.0 : i / (count - 1))!);

  List<_Preset> _presetsForCount(int count) => [
    _Preset(
      label: 'Default',
      range: '0.75–5.49',
      values: List<double>.unmodifiable(FitnessBikeDefinition.defaultGearRatiosFor(count)),
    ),
    _Preset(
      label: 'Compact',
      range: '1.00–4.00',
      values: List<double>.unmodifiable(_evenSteps(1.00, 4.00, count)),
    ),
    _Preset(
      label: 'Wide',
      range: '0.50–6.50',
      values: List<double>.unmodifiable(_evenSteps(0.50, 6.50, count)),
    ),
    _Preset(
      label: '1\u00D7',
      range: '2.20–4.20',
      values: List<double>.unmodifiable(_evenSteps(2.20, 4.20, count)),
    ),
  ];

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
          'PRESETS',
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
              children: _presetsForCount(
                def.maxGear,
              ).map((p) => Expanded(child: _presetButton(context, p, current))).toList(),
            );
          },
        ),
      ],
    );
  }

  Widget _presetButton(BuildContext context, _Preset preset, List<double> current) {
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
              'PER-GEAR',
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
              children: List<Widget>.generate(ratios.length, (i) {
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
                      'Gear $gear',
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                    if (isCurrent) _badge('CURRENT', const Color(0xFF2563EB), Colors.white),
                    if (isNeutral && !isCurrent) _badge('NEUTRAL', const Color(0xFFDBEAFE), const Color(0xFF1E40AF)),
                  ],
                ),
                Text(
                  _hintFor(gear, ratio, ratios, def.neutralGear),
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

String _hintFor(int gear, double ratio, List<double> ratios, int neutralGear) {
  if (gear == neutralGear) {
    return 'Reference \u2014 base ratio';
  }
  final neutral = ratios[neutralGear - 1];
  final delta = ratio - neutral;
  if (delta.abs() < 0.05) return 'close to neutral';
  final mag = delta.abs().toStringAsFixed(2);
  if (delta > 0) return '+$mag harder than neutral';
  return '\u2212$mag easier than neutral';
}

class _Preset {
  final String label;
  final String range;
  final List<double> values;
  _Preset({required this.label, required this.range, required this.values});
}
