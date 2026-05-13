import 'dart:io' show Platform;

import 'package:bike_control/services/overlay/android_overlay_controller.dart';
import 'package:bike_control/services/overlay/desktop_overlay_controller.dart';
import 'package:bike_control/services/overlay/ios_overlay_controller.dart';
import 'package:bike_control/services/overlay/trainer_overlay_controller.dart';
import 'package:flutter/foundation.dart';

class TrainerOverlayService {
  TrainerOverlayService._();
  static TrainerOverlayController? _instance;

  static TrainerOverlayController forCurrentPlatform() {
    return _instance ??= _build();
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
}
