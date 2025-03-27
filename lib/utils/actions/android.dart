import 'dart:ui';

import 'package:accessibility/accessibility.dart';
import 'package:swift_control/main.dart';
import 'package:swift_control/utils/actions/base_actions.dart';
import 'package:swift_control/utils/keymap/keymap.dart';

class AndroidActions extends BaseActions {
  static const MYWHOOSH_APP_PACKAGE = "com.mywhoosh.whooshgame";
  static const TRAININGPEAKS_APP_PACKAGE = "com.indieVelo.client";

  WindowEvent? windowInfo;

  @override
  void init(Keymap? keymap) {
    streamEvents().listen((windowEvent) {
      windowInfo = windowEvent;
    });
  }

  @override
  void decreaseGear() {
    if (windowInfo == null) {
      throw Exception("Decrease gear: No window info");
    } else {
      final point = switch (windowInfo!.packageName) {
        MYWHOOSH_APP_PACKAGE => Offset(windowInfo!.windowWidth * 0.80, windowInfo!.windowHeight * 0.94),
        TRAININGPEAKS_APP_PACKAGE => Offset(windowInfo!.windowWidth / 2 * 1.15, windowInfo!.windowHeight * 0.74),
        _ => throw UnimplementedError("Decreasing gear not supported for ${windowInfo!.packageName}"),
      };

      accessibilityHandler.performTouch(point.dx, point.dy);
    }
  }

  @override
  void increaseGear() {
    if (windowInfo == null) {
      throw Exception("Increasing gear: No window info");
    } else {
      final point = switch (windowInfo!.packageName) {
        MYWHOOSH_APP_PACKAGE => Offset(windowInfo!.windowWidth * 0.98, windowInfo!.windowHeight * 0.94),
        TRAININGPEAKS_APP_PACKAGE => Offset(windowInfo!.windowWidth / 2 * 1.32, windowInfo!.windowHeight * 0.74),
        _ => throw UnimplementedError("Increasing gear not supported for ${windowInfo!.packageName}"),
      };

      accessibilityHandler.performTouch(point.dx, point.dy);
    }
  }
}
