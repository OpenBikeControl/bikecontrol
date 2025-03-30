import 'dart:ui';

import 'package:accessibility/accessibility.dart';
import 'package:swift_control/main.dart';
import 'package:swift_control/utils/actions/base_actions.dart';
import 'package:swift_control/utils/keymap/keymap.dart';

class AndroidActions extends BaseActions {
  static const MYWHOOSH_APP_PACKAGE = "com.mywhoosh.whooshgame";
  static const TRAININGPEAKS_APP_PACKAGE = "com.indieVelo.client";
  static const validPackageNames = [MYWHOOSH_APP_PACKAGE, TRAININGPEAKS_APP_PACKAGE];

  WindowEvent? windowInfo;
  Offset? _gearUpTouchPosition;
  Offset? _gearDownTouchPosition;

  @override
  Offset? get gearUpTouchPosition => _gearUpTouchPosition;

  @override
  Offset? get gearDownTouchPosition => _gearDownTouchPosition;

  @override
  void init(Keymap? keymap) {
    streamEvents().listen((windowEvent) {
      if (validPackageNames.contains(windowEvent.packageName)) {
        windowInfo = windowEvent;
      }
    });
  }

  @override
  void decreaseGear() {
    if (_gearDownTouchPosition == null) {
      if (windowInfo == null) {
        throw Exception("Increasing gear: No window info");
      }
      final point = switch (windowInfo!.packageName) {
        MYWHOOSH_APP_PACKAGE => Offset(windowInfo!.windowWidth * 0.80, windowInfo!.windowHeight * 0.94),
        TRAININGPEAKS_APP_PACKAGE => Offset(windowInfo!.windowWidth / 2 * 1.15, windowInfo!.windowHeight * 0.74),
        _ => throw UnimplementedError("Decreasing gear not supported for ${windowInfo!.packageName}"),
      };

      accessibilityHandler.performTouch(point.dx, point.dy);
    } else {
      accessibilityHandler.performTouch(_gearDownTouchPosition!.dx, _gearDownTouchPosition!.dy);
    }
  }

  @override
  void increaseGear() {
    if (_gearUpTouchPosition == null) {
      if (windowInfo == null) {
        throw Exception("Increasing gear: No window info");
      }
      final point = switch (windowInfo!.packageName) {
        MYWHOOSH_APP_PACKAGE => Offset(windowInfo!.windowWidth * 0.98, windowInfo!.windowHeight * 0.94),
        TRAININGPEAKS_APP_PACKAGE => Offset(windowInfo!.windowWidth / 2 * 1.32, windowInfo!.windowHeight * 0.74),
        _ => throw UnimplementedError("Increasing gear not supported for ${windowInfo!.packageName}"),
      };

      accessibilityHandler.performTouch(point.dx, point.dy);
    } else {
      accessibilityHandler.performTouch(_gearUpTouchPosition!.dx, _gearUpTouchPosition!.dy);
    }
  }

  @override
  void controlMedia(MediaAction action) {
    accessibilityHandler.controlMedia(action);
  }

  @override
  void updateTouchPositions(Offset gearUp, Offset gearDown) {
    _gearUpTouchPosition = gearUp;
    _gearDownTouchPosition = gearDown;
  }
}
