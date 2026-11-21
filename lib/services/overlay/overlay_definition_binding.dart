import 'package:bike_control/services/overlay/trainer_overlay_controller.dart';
import 'package:flutter/foundation.dart';
import 'package:prop/emulators/definitions/fitness_bike_definition.dart';

/// The [FitnessBikeDefinition] an overlay shows, kept on the trainer's current
/// one.
///
/// Every trainer (re)connect builds a fresh definition and the previous one
/// goes silent. An overlay that stays on the definition it was shown with
/// freezes while shifting keeps working, so this follows the trainer's
/// [LiveDefinition] and moves the display along with it.
class OverlayDefinitionBinding {
  OverlayDefinitionBinding({required this.onChange, required this.onSwap});

  /// A value the overlay shows changed on [current].
  final VoidCallback onChange;

  /// [current] was replaced by a new definition; push its state right away.
  final VoidCallback onSwap;

  FitnessBikeDefinition? _def;
  LiveDefinition? _live;
  Listenable? _bound;
  int _generation = 0;

  /// The definition to display and to shift. Null while detached.
  FitnessBikeDefinition? get current => _def;

  /// Changes on every [attach] and [detach], not when the trainer swaps the
  /// definition: lets a caller tell whether its own show is still the latest.
  int get generation => _generation;

  /// Show [def] and follow [live] from here on.
  void attach(FitnessBikeDefinition def, {LiveDefinition? live}) {
    _generation++;
    if (!identical(_live, live)) {
      _live?.removeListener(_onLiveChanged);
      _live = live;
      _live?.addListener(_onLiveChanged);
    }
    _bindTo(def);
  }

  void detach() {
    _generation++;
    _live?.removeListener(_onLiveChanged);
    _live = null;
    _bound?.removeListener(onChange);
    _bound = null;
    _def = null;
  }

  void _onLiveChanged() {
    final next = _live?.value;
    // No trainer for now: keep the last reading up rather than blanking it.
    if (next == null || identical(next, _def)) return;
    _bindTo(next);
    onSwap();
  }

  void _bindTo(FitnessBikeDefinition def) {
    _def = def;
    _bound?.removeListener(onChange);
    _bound = Listenable.merge([
      def.currentGear,
      def.gearRatio,
      def.trainerMode,
      def.powerW,
      def.cadenceRpm,
      def.ergTargetPower,
    ])..addListener(onChange);
  }
}
