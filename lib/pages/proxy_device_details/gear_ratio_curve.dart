import 'package:bike_control/gen/l10n.dart';
import 'package:bike_control/widgets/ui/type_scale.dart';
import 'package:prop/emulators/definitions/fitness_bike_definition.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

/// The live ratio curve of [definition] — a thin binding around
/// [GearRatioCurveView], which holds the actual drawing.
class GearRatioCurve extends StatelessWidget {
  final FitnessBikeDefinition definition;
  const GearRatioCurve({super.key, required this.definition});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([definition.gearRatios, definition.currentGear]),
      builder: (context, _) => GearRatioCurveView(
        ratios: definition.gearRatios.value,
        currentGear: definition.currentGear.value,
      ),
    );
  }
}

/// The ratio curve drawn from plain values: one bar per gear, the current one
/// picked out in the accent colour, with the span and the selected ratio
/// spelled out around it.
///
/// Split from [GearRatioCurve] so the onboarding preview can drive the same
/// widget through a canned set of ratios — riders see the real thing before
/// they own a trainer, and there is only one curve to keep in style.
class GearRatioCurveView extends StatelessWidget {
  final List<double> ratios;
  final int currentGear;

  /// Animates bar heights when [ratios] change. The live card leaves this off:
  /// its values only move when the rider edits them, and each edit already
  /// redraws instantly.
  final bool animated;

  const GearRatioCurveView({
    super.key,
    required this.ratios,
    required this.currentGear,
    this.animated = false,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context);
    // No ratios means no curve to draw — the open-source trainer stub reports
    // an empty list until a real definition is attached.
    if (ratios.isEmpty) return const SizedBox.shrink();
    final gear = currentGear.clamp(1, ratios.length);
    final minR = ratios.reduce((a, b) => a < b ? a : b);
    final maxR = ratios.reduce((a, b) => a > b ? a : b);
    final span = (maxR - minR).abs() < 0.0001 ? 1.0 : (maxR - minR);
    final currentRatio = ratios[gear - 1];
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
      decoration: BoxDecoration(
        color: cs.muted,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cs.border),
      ),
      child: Column(
        spacing: 10,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                l10n.ratioCurveLabel,
                style: context.typography.caption.copyWith(
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1,
                  color: cs.mutedForeground,
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                spacing: 6,
                children: [
                  Text(
                    ratios.first.toStringAsFixed(2),
                    style: context.typography.caption.copyWith(fontWeight: FontWeight.w600, color: cs.mutedForeground),
                  ),
                  Icon(LucideIcons.arrowRight, size: 10, color: cs.mutedForeground),
                  Text(
                    ratios.last.toStringAsFixed(2),
                    style: context.typography.caption.copyWith(fontWeight: FontWeight.w600, color: cs.mutedForeground),
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
                  final isCurrent = (i + 1) == gear;
                  final h = (12 + (r - minR) / span * 68).clamp(4.0, 80.0);
                  final t = ratios.length == 1 ? 1.0 : i / (ratios.length - 1);
                  final color = isCurrent ? cs.primary : Color.lerp(cs.border, cs.foreground, t)!;
                  final bar = animated
                      ? AnimatedContainer(
                          duration: const Duration(milliseconds: 500),
                          curve: Curves.easeOutCubic,
                          height: h,
                          decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2)),
                        )
                      : Container(
                          height: h,
                          decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2)),
                        );
                  return Expanded(child: bar);
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
                children: [
                  Icon(LucideIcons.circleChevronLeft, size: 12, color: cs.mutedForeground),
                  Text(
                    l10n.easier,
                    style: context.typography.caption.copyWith(fontWeight: FontWeight.w600, color: cs.mutedForeground),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: cs.primary, borderRadius: BorderRadius.circular(999)),
                child: Text(
                  '${l10n.gearNumber(gear)} · ${currentRatio.toStringAsFixed(2)}',
                  style: context.typography.caption.copyWith(fontWeight: FontWeight.w700, color: cs.primaryForeground),
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                spacing: 4,
                children: [
                  Text(
                    l10n.harder,
                    style: context.typography.caption.copyWith(fontWeight: FontWeight.w600, color: cs.mutedForeground),
                  ),
                  Icon(LucideIcons.circleChevronRight, size: 12, color: cs.mutedForeground),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}
