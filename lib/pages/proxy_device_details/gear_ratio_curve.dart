import 'package:prop/emulators/definitions/fitness_bike_definition.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

class GearRatioCurve extends StatelessWidget {
  final FitnessBikeDefinition definition;
  const GearRatioCurve({super.key, required this.definition});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([definition.gearRatios, definition.currentGear]),
      builder: (context, _) {
        final ratios = definition.gearRatios.value;
        final current = definition.currentGear.value;
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
                        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Color(0xFF64748B)),
                      ),
                      const Icon(LucideIcons.arrowRight, size: 10, color: Color(0xFF475569)),
                      Text(
                        ratios.last.toStringAsFixed(2),
                        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Color(0xFF64748B)),
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
                                      : (i < 20 ? const Color(0xFF64748B) : const Color(0xFFCBD5E1)))));
                      return Expanded(
                        child: Container(
                          height: h,
                          decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2)),
                        ),
                      );
                    }),
                  ),
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Row(
                    mainAxisSize: MainAxisSize.min,
                    spacing: 4,
                    children: [
                      Icon(LucideIcons.circleChevronLeft, size: 12, color: Color(0xFF94A3B8)),
                      Text('Easier', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Color(0xFF94A3B8))),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(color: const Color(0xFF1E40AF), borderRadius: BorderRadius.circular(999)),
                    child: Text(
                      'Gear $current \u00B7 ${currentRatio.toStringAsFixed(2)}',
                      style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFFDBEAFE)),
                    ),
                  ),
                  const Row(
                    mainAxisSize: MainAxisSize.min,
                    spacing: 4,
                    children: [
                      Text('Harder', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Color(0xFF94A3B8))),
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
}
