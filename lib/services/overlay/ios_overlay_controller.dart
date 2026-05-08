import 'package:bike_control/services/overlay/overlay_state.dart';
import 'package:bike_control/services/overlay/trainer_overlay_controller.dart';
import 'package:flutter/foundation.dart';
import 'package:prop/emulators/definitions/fitness_bike_definition.dart';

class IosOverlayController implements TrainerOverlayController {
  final ValueNotifier<bool> _showing = ValueNotifier(false);
  @override
  ValueListenable<bool> get isShowing => _showing;
  @override
  Future<OverlayShowResult> show(FitnessBikeDefinition def, Set<OverlayField> fields) async {
    return const OverlayShowResult.fail(OverlayShowFailure.unknown, message: 'not implemented');
  }
  @override
  Future<void> hide() async {}
  @override
  void updateFields(Set<OverlayField> fields) {}
}
