import 'package:bike_control/gen/l10n.dart';
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
  const OverlayShowResult.ok() : ok = true, failure = null, message = null;
  const OverlayShowResult.fail(this.failure, {this.message}) : ok = false;

  /// What to tell the rider about a failed show. [message] is diagnostic
  /// detail for the log (often a raw exception) and is never shown.
  String riderMessage(AppLocalizations l10n) => switch (failure) {
    OverlayShowFailure.permissionDenied => l10n.overlayPermissionExplain,
    OverlayShowFailure.systemDisabled => l10n.overlayLowPowerMode,
    OverlayShowFailure.unknown || null => l10n.overlayCouldNotStart,
  };
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

  /// Live-update the overlay window opacity in `[0.2, 1.0]`. Desktop-only;
  /// no-op on platforms whose overlay has no adjustable window alpha.
  void updateOpacity(double opacity);

  /// Re-assert the overlay's position at the top of the system window stack
  /// without tearing down its Dart state.
  ///
  /// Android-only in practice: the overlay is a `TYPE_APPLICATION_OVERLAY`
  /// window added while BikeControl is in the foreground, and it ends up buried
  /// beneath a trainer app (e.g. Rouvy) that comes to the foreground afterwards
  /// — it stays hidden until the window is re-added. Callers invoke this on the
  /// rising edge of "a trainer app connected to the proxy" so the overlay
  /// re-tops itself the moment the trainer app grabs the virtual trainer. A
  /// no-op when nothing is showing, and on platforms whose overlay is not a
  /// re-stackable system window (iOS Live Activity, the desktop floating
  /// window, which handle fullscreen elevation their own way).
  Future<void> reassert();
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
    return const OverlayShowResult.fail(
      OverlayShowFailure.systemDisabled,
      message: 'Overlay not supported on this platform',
    );
  }

  @override
  Future<void> hide() async {}
  @override
  void updateFields(Set<OverlayField> fields) {}
  @override
  void updateOpacity(double opacity) {}
  @override
  Future<void> reassert() async {}
}
