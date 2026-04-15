import 'package:prop/emulators/definitions/fitness_bike_definition.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

class GearHeroCard extends StatelessWidget {
  final FitnessBikeDefinition definition;
  const GearHeroCard({super.key, required this.definition});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        spacing: 12,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                spacing: 6,
                children: [
                  Icon(LucideIcons.cog, size: 14, color: const Color(0xFF94A3B8)),
                  Text(
                    'CURRENT GEAR',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1,
                      color: Color(0xFF94A3B8),
                    ),
                  ),
                ],
              ),
              ValueListenableBuilder<TrainerMode>(
                valueListenable: definition.trainerMode,
                builder: (_, mode, _) => Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E40AF),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    _modeLabel(mode),
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFFDBEAFE),
                    ),
                  ),
                ),
              ),
            ],
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            spacing: 28,
            children: [
              _shiftButton(
                icon: LucideIcons.minus,
                filled: false,
                onTap: () => definition.shiftDown(),
              ),
              ValueListenableBuilder<int>(
                valueListenable: definition.currentGear,
                builder: (_, gear, _) => Column(
                  spacing: 2,
                  children: [
                    Text(
                      '$gear',
                      style: const TextStyle(
                        fontSize: 72,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -2,
                        color: Colors.white,
                      ),
                    ),
                    ValueListenableBuilder<double>(
                      valueListenable: definition.gearRatio,
                      builder: (_, ratio, _) => Text(
                        'of 24  ·  ratio ${ratio.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              _shiftButton(
                icon: LucideIcons.plus,
                filled: true,
                onTap: () => definition.shiftUp(),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _shiftButton({
    required IconData icon,
    required bool filled,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 52,
        height: 52,
        decoration: BoxDecoration(
          color: filled ? const Color(0xFF2563EB) : const Color(0xFF1E293B),
          shape: BoxShape.circle,
          border: filled
              ? null
              : Border.all(color: const Color(0xFF334155), width: 1),
        ),
        child: Icon(icon, size: 22, color: filled ? Colors.white : const Color(0xFFE2E8F0)),
      ),
    );
  }

  String _modeLabel(TrainerMode mode) => switch (mode) {
        TrainerMode.ergMode => 'ERG',
        TrainerMode.simMode => 'SIM',
        TrainerMode.simModeVirtualShifting => 'Virtual Shifting',
      };
}
