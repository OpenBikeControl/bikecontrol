import 'package:bike_control/utils/i18n_extension.dart';
import 'package:bike_control/widgets/home/virtual_shifting_card.dart' show RideStat;
import 'package:prop/emulators/definitions/fitness_bike_definition.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

/// Key of the gear figure, for tests.
const Key trainerMetricGearKey = ValueKey('trainer-metric-gear');

/// The Devices trainer row's live numbers: power, cadence and the gear
/// BikeControl is on ("12 / 24"), or the ERG target while in ERG. Rebuilds
/// only itself as the numbers move.
class TrainerMetricsStrip extends StatelessWidget {
  const TrainerMetricsStrip({super.key, required this.definition});

  final FitnessBikeDefinition definition;

  @override
  Widget build(BuildContext context) {
    final l = context.i18n;
    return AnimatedBuilder(
      animation: Listenable.merge([
        definition.powerW,
        definition.cadenceRpm,
        definition.currentGear,
        definition.trainerMode,
        definition.ergTargetPower,
      ]),
      builder: (context, _) {
        final erg = definition.trainerMode.value == TrainerMode.ergMode;
        final power = definition.powerW.value;
        final cadence = definition.cadenceRpm.value;
        return Row(
          children: [
            Expanded(
              child: RideStat(
                value: power?.toString() ?? '--',
                unit: 'W',
                label: l.sensorQuantityPower,
                scale: 0.85,
              ),
            ),
            Expanded(
              child: RideStat(
                value: cadence?.toString() ?? '--',
                unit: 'rpm',
                label: l.sensorQuantityCadence,
                scale: 0.85,
              ),
            ),
            Expanded(
              child: erg
                  ? RideStat(
                      value: definition.ergTargetPower.value?.toString() ?? '--',
                      unit: 'W',
                      label: 'ERG',
                      scale: 0.85,
                    )
                  : RideStat(
                      key: trainerMetricGearKey,
                      value: '${definition.currentGear.value}',
                      unit: '/ ${definition.maxGear}',
                      label: l.rideGear,
                      scale: 0.85,
                    ),
            ),
          ],
        );
      },
    );
  }
}
