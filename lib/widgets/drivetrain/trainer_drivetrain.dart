import 'package:bike_control/main.dart' show screenshotMotionPinned;
import 'package:bike_control/widgets/drivetrain/drivetrain_view.dart';
import 'package:prop/emulators/definitions/fitness_bike_definition.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

/// [DrivetrainView] bound to a live trainer — a thin binding around the view,
/// which holds the actual drawing.
///
/// The chain only marches while the trainer reports cadence, so a bike standing
/// still on screen means a bike standing still in the room.
class TrainerDrivetrain extends StatelessWidget {
  const TrainerDrivetrain({
    super.key,
    required this.definition,
    this.dim = false,
    this.showGear = true,
    this.framed = true,
  });

  final FitnessBikeDefinition definition;

  /// Paired, but not carrying gears right now.
  final bool dim;

  final bool showGear;

  /// See [DrivetrainView.framed].
  final bool framed;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      // gearRatios carries the gear *count* as well, so a rider editing their
      // cassette resizes the stack without a rebuild from anywhere else.
      animation: Listenable.merge([
        definition.currentGear,
        definition.gearRatios,
        definition.frontRing,
        definition.cadenceRpm,
      ]),
      builder: (context, _) {
        final cadence = definition.cadenceRpm.value ?? 0;
        // A chain that never stops moving is a screenshot that never looks the
        // same twice — and a golden test that never settles.
        final pedalling = cadence > 0 && !screenshotMotionPinned;
        return DrivetrainView(
          gear: definition.currentGear.value,
          gearCount: definition.maxGear,
          frontShift: definition.frontShiftEnabled,
          largeRingActive: definition.frontRing.value == FrontRing.large,
          smallChainringTeeth: definition.smallChainringTeeth,
          largeChainringTeeth: definition.largeChainringTeeth,
          moving: pedalling,
          cadence: cadence,
          dim: dim,
          showGear: showGear,
          framed: framed,
        );
      },
    );
  }
}
