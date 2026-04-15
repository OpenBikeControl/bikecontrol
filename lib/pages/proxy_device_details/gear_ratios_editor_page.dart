import 'dart:ui';

import 'package:bike_control/utils/core.dart';
import 'package:bike_control/widgets/ui/stepper_control.dart';
import 'package:prop/emulators/definitions/fitness_bike_definition.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

class GearRatiosEditorPage extends StatefulWidget {
  final FitnessBikeDefinition definition;
  const GearRatiosEditorPage({super.key, required this.definition});

  @override
  State<GearRatiosEditorPage> createState() => _GearRatiosEditorPageState();
}

class _GearRatiosEditorPageState extends State<GearRatiosEditorPage> {
  FitnessBikeDefinition get def => widget.definition;

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
            'Gear Ratios',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600, letterSpacing: -0.3),
          ),
          trailing: [
            GestureDetector(
              onTap: () async {
                def.resetGearRatios();
                await core.settings.clearProxyGearRatios();
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF2F2),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  spacing: 4,
                  children: const [
                    Icon(LucideIcons.rotateCcw, size: 12, color: Color(0xFFB91C1C)),
                    Text(
                      'Reset',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFFB91C1C),
                      ),
                    ),
                  ],
                ),
              ),
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

  Widget _heroCurve(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([def.gearRatios, def.currentGear]),
      builder: (context, _) {
        final ratios = def.gearRatios.value;
        final current = def.currentGear.value;
        final minR = ratios.reduce((a, b) => a < b ? a : b);
        final maxR = ratios.reduce((a, b) => a > b ? a : b);
        final span = (maxR - minR).abs() < 0.0001 ? 1.0 : (maxR - minR);
        final currentRatio = ratios[current - 1];
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
            ),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            spacing: 10,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'RATIO CURVE',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1,
                      color: Color(0xFF94A3B8),
                    ),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    spacing: 6,
                    children: [
                      Text(
                        ratios.first.toStringAsFixed(2),
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF64748B),
                        ),
                      ),
                      const Icon(LucideIcons.arrowRight, size: 10, color: Color(0xFF475569)),
                      Text(
                        ratios.last.toStringAsFixed(2),
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              SizedBox(
                width: double.infinity,
                height: 80,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    spacing: 4,
                    children: List<Widget>.generate(ratios.length, (i) {
                      final r = ratios[i];
                      final isCurrent = (i + 1) == current;
                      final h = (12 + (r - minR) / span * 68).clamp(4.0, 80.0);
                      final color = isCurrent
                          ? const Color(0xFF2563EB)
                          : (i + 1 == 24
                              ? const Color(0xFFFFFFFF)
                              : (i < 8
                                  ? const Color(0xFF334155)
                                  : (i < 16
                                      ? const Color(0xFF475569)
                                      : (i < 20
                                          ? const Color(0xFF64748B)
                                          : const Color(0xFFCBD5E1)))));
                      return Expanded(
                        child: Container(
                          height: h,
                          decoration: BoxDecoration(
                            color: color,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      );
                    }),
                  ),
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    spacing: 4,
                    children: const [
                      Icon(LucideIcons.circleChevronLeft, size: 12, color: Color(0xFF94A3B8)),
                      Text(
                        'Easier',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF94A3B8),
                        ),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E40AF),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      'Gear $current \u00B7 ${currentRatio.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFFDBEAFE),
                      ),
                    ),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    spacing: 4,
                    children: const [
                      Text(
                        'Harder',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF94A3B8),
                        ),
                      ),
                      Icon(LucideIcons.circleChevronRight, size: 12, color: Color(0xFF94A3B8)),
                    ],
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  // ---------- Presets ----------

  static List<double> _evenSteps(double lo, double hi) =>
      List<double>.generate(24, (i) => lerpDouble(lo, hi, i / 23)!);

  static final List<_Preset> _presetList = [
    _Preset(
      label: 'Default',
      range: '0.75–5.49',
      values: List<double>.unmodifiable(FitnessBikeDefinition.defaultGearRatios),
    ),
    _Preset(
      label: 'Compact',
      range: '1.00–4.00',
      values: List<double>.unmodifiable(_evenSteps(1.00, 4.00)),
    ),
    _Preset(
      label: 'Wide',
      range: '0.50–6.50',
      values: List<double>.unmodifiable(_evenSteps(0.50, 6.50)),
    ),
    _Preset(
      label: '1\u00D7',
      range: '2.20–4.20',
      values: List<double>.unmodifiable(_evenSteps(2.20, 4.20)),
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
              children: _presetList
                  .map((p) => Expanded(child: _presetButton(context, p, current)))
                  .toList(),
            );
          },
        ),
      ],
    );
  }

  Widget _presetButton(BuildContext context, _Preset preset, List<double> current) {
    final cs = Theme.of(context).colorScheme;
    final active = _ratiosMatch(preset.values, current);
    return GestureDetector(
      onTap: () async {
        def.setGearRatios(preset.values);
        await core.settings.setProxyGearRatios(preset.values);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(
          color: active ? const Color(0xFF09090B) : cs.card,
          borderRadius: BorderRadius.circular(8),
          border: active ? null : Border.all(color: cs.border),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              preset.label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: active ? FontWeight.w700 : FontWeight.w600,
                color: active ? Colors.white : cs.foreground,
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
    final isNeutral = gear == FitnessBikeDefinition.neutralGear;

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
                    if (isNeutral && !isCurrent)
                      _badge('NEUTRAL', const Color(0xFFDBEAFE), const Color(0xFF1E40AF)),
                  ],
                ),
                Text(
                  _hintFor(gear, ratio, ratios),
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
              await core.settings.setProxyGearRatios(def.gearRatios.value);
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

String _hintFor(int gear, double ratio, List<double> ratios) {
  if (gear == FitnessBikeDefinition.neutralGear) {
    return 'Reference \u2014 base ratio';
  }
  final neutral = ratios[FitnessBikeDefinition.neutralGear - 1];
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
