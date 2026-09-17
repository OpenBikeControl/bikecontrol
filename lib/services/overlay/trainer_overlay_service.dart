import 'dart:io' show Platform;

import 'package:bike_control/bluetooth/devices/proxy/proxy_device.dart';
import 'package:bike_control/services/overlay/android_overlay_controller.dart';
import 'package:bike_control/services/overlay/desktop_overlay_controller.dart';
import 'package:bike_control/services/overlay/ios_overlay_controller.dart';
import 'package:bike_control/services/overlay/trainer_overlay_controller.dart';
import 'package:bike_control/utils/core.dart';
import 'package:flutter/foundation.dart';

class TrainerOverlayService {
  TrainerOverlayService._();
  static TrainerOverlayController? _instance;

  static TrainerOverlayController forCurrentPlatform() {
    return _instance ??= _build();
  }

  /// Whether this platform can draw an overlay at all — i.e. whether
  /// [forCurrentPlatform] would hand back something other than a no-op.
  /// Answered without building a controller, so callers on a hot path (the
  /// home screen rebuilds on every BLE event) don't spin up platform channels
  /// just to ask.
  static bool get isSupportedPlatform {
    if (kIsWeb) return false;
    return Platform.isAndroid || Platform.isIOS || Platform.isMacOS || Platform.isWindows;
  }

  static TrainerOverlayController _build() {
    if (kIsWeb) return NoOpOverlayController();
    if (Platform.isAndroid) return AndroidOverlayController();
    if (Platform.isIOS) return IosOverlayController();
    if (Platform.isMacOS || Platform.isWindows) return DesktopOverlayController();
    return NoOpOverlayController();
  }

  @visibleForTesting
  static void resetForTest() {
    _instance = null;
  }

  /// Stands a fake controller in for the platform one, so [enableTrainerOverlay]
  /// can be exercised without a real window, Live Activity or draw-over grant.
  @visibleForTesting
  static void setForTest(TrainerOverlayController controller) {
    _instance = controller;
  }
}

/// Puts the gear overlay on screen for [device] and persists the choice.
///
/// The one enable path in the app: the Overlay section's switch and the home
/// screen's gear-overlay step both run it, so they cannot drift on what
/// "enabled" means. The persisted flag is written only when the platform actually put
/// something on screen — on Android [TrainerOverlayController.show] asks for
/// the draw-over permission first, and a rider who declines must not end up
/// with a setting that claims an overlay they cannot see.
Future<OverlayShowResult> enableTrainerOverlay(ProxyDevice device) async {
  // No Virtual Shifting session means no BikeControl-computed gear, so there
  // is nothing to draw. Callers gate on this too; this is the backstop.
  final definition = device.fitnessBike;
  if (definition == null) {
    return const OverlayShowResult.fail(OverlayShowFailure.unknown);
  }

  final result = await TrainerOverlayService.forCurrentPlatform().show(
    definition,
    core.settings.getOverlayFields(),
    liveDef: () => device.fitnessBike,
  );
  if (result.ok) await core.settings.setOverlayEnabled(true);
  return result;
}
