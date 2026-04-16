import 'package:bike_control/pages/proxy_device_details/gear_ratios_editor_page.dart';
import 'package:bike_control/utils/i18n_extension.dart';
import 'package:prop/emulators/definitions/fitness_bike_definition.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

class GearRatiosCard extends StatelessWidget {
  final FitnessBikeDefinition definition;
  const GearRatiosCard({super.key, required this.definition});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cs.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 12,
        children: [
          _header(context),
          _sparkline(context),
          _footer(context),
        ],
      ),
    );
  }

  Widget _header(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: 2,
          children: [
            const Text(
              'Gear Ratios',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
            Text(
              '24-step virtual shifter table',
              style: TextStyle(fontSize: 12, color: cs.mutedForeground),
            ),
          ],
        ),
        Button.ghost(
          onPressed: () => context.push(GearRatiosEditorPage(definition: definition)),
          trailing: Icon(LucideIcons.chevronRight, size: 12),
          child: const Text('Customize', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
        ),
      ],
    );
  }

  Widget _sparkline(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return AnimatedBuilder(
      animation: Listenable.merge([definition.gearRatios, definition.currentGear]),
      builder: (context, _) {
        final ratios = definition.gearRatios.value;
        final current = definition.currentGear.value;
        return SizedBox(
          width: double.infinity,
          height: 42,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            spacing: 3,
            children: List<Widget>.generate(ratios.length, (i) {
              final ratio = ratios[i];
              final isCurrent = (i + 1) == current;
              final h = (6 + (ratio - 0.75) / (5.49 - 0.75) * 36).clamp(4.0, 42.0);
              final color = isCurrent
                  ? cs.primary
                  : (i < 8
                      ? const Color(0xFFE4E4E7)
                      : (i < 16 ? const Color(0xFFA1A1AA) : const Color(0xFF3F3F46)));
              return Expanded(
                child: Container(
                  height: h,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(1),
                  ),
                ),
              );
            }),
          ),
        );
      },
    );
  }

  Widget _footer(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return AnimatedBuilder(
      animation: Listenable.merge([definition.gearRatios, definition.currentGear]),
      builder: (context, _) {
        final ratios = definition.gearRatios.value;
        final current = definition.currentGear.value;
        final currentRatio = ratios[current - 1];
        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              ratios.first.toStringAsFixed(2),
              style: TextStyle(fontSize: 10, color: cs.mutedForeground),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: const Color(0xFFDBEAFE),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                spacing: 4,
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration: const BoxDecoration(
                      color: Color(0xFF2563EB),
                      shape: BoxShape.circle,
                    ),
                  ),
                  Text(
                    'gear $current \u00B7 ${currentRatio.toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1E40AF),
                    ),
                  ),
                ],
              ),
            ),
            Text(
              ratios.last.toStringAsFixed(2),
              style: TextStyle(fontSize: 10, color: cs.mutedForeground),
            ),
          ],
        );
      },
    );
  }
}
