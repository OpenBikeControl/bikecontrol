import 'package:bike_control/services/overlay/overlay_state.dart';
import 'package:bike_control/services/overlay/trainer_overlay_controller.dart';
import 'package:flutter/foundation.dart';
import 'package:prop/emulators/definitions/fitness_bike_definition.dart';

/// A platform overlay that "shows" without a window, Live Activity or
/// draw-over grant, so the pages that switch it on can be driven in a test.
class FakeOverlayController implements TrainerOverlayController {
  FakeOverlayController({this.result = const OverlayShowResult.ok()});

  final OverlayShowResult result;
  int shows = 0;
  Set<OverlayField>? fields;

  final ValueNotifier<bool> _showing = ValueNotifier(false);

  @override
  ValueListenable<bool> get isShowing => _showing;

  @override
  Future<OverlayShowResult> show(
    FitnessBikeDefinition def,
    Set<OverlayField> fields, {
    LiveDefinitionLookup? liveDef,
  }) async {
    shows++;
    this.fields = fields;
    _showing.value = result.ok;
    return result;
  }

  @override
  Future<void> hide() async => _showing.value = false;

  @override
  void updateFields(Set<OverlayField> fields) => this.fields = fields;

  @override
  void updateOpacity(double opacity) {}

  @override
  Future<void> reassert() async {}
}
