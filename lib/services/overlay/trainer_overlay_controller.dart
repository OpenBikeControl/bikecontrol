import 'package:bike_control/services/overlay/overlay_state.dart';
import 'package:flutter/foundation.dart';
import 'package:prop/emulators/definitions/fitness_bike_definition.dart';

/// Reasons `show()` may return `false`.
enum OverlayShowFailure {
  permissionDenied,
  systemDisabled,
  unknown,
}

class OverlayShowResult {
  final bool ok;
  final OverlayShowFailure? failure;
  final String? message;
  const OverlayShowResult.ok()
      : ok = true,
        failure = null,
        message = null;
  const OverlayShowResult.fail(this.failure, {this.message}) : ok = false;
}

/// Looks up the current live [FitnessBikeDefinition] for the active trainer.
/// The emulator rebinds a fresh definition each time its transport starts,
/// so the controller can't cache the def captured at show() time — action
/// handlers must re-resolve it on every call or buttons silently no-op
/// against a stale instance.
typedef LiveDefinitionLookup = FitnessBikeDefinition? Function();

abstract class TrainerOverlayController {
  ValueListenable<bool> get isShowing;
  Future<OverlayShowResult> show(
    FitnessBikeDefinition def,
    Set<OverlayField> fields, {
    LiveDefinitionLookup? liveDef,
  });
  Future<void> hide();
  void updateFields(Set<OverlayField> fields);
}

class NoOpOverlayController implements TrainerOverlayController {
  final ValueNotifier<bool> _showing = ValueNotifier(false);
  @override
  ValueListenable<bool> get isShowing => _showing;
  @override
  Future<OverlayShowResult> show(
    FitnessBikeDefinition def,
    Set<OverlayField> fields, {
    LiveDefinitionLookup? liveDef,
  }) async {
    return const OverlayShowResult.fail(OverlayShowFailure.systemDisabled,
        message: 'Overlay not supported on this platform');
  }
  @override
  Future<void> hide() async {}
  @override
  void updateFields(Set<OverlayField> fields) {}
}
