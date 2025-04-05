import 'dart:ui';

import 'package:accessibility/accessibility.dart';
import 'package:dartx/dartx.dart';
import 'package:swift_control/main.dart';
import 'package:swift_control/utils/actions/base_actions.dart';
import 'package:swift_control/utils/keymap/buttons.dart';

import '../single_line_exception.dart';

class AndroidActions extends BaseActions {
  WindowEvent? windowInfo;
  SupportedApp? supportedApp;
  Offset? _gearUpTouchPosition;
  Offset? _gearDownTouchPosition;

  @override
  Offset? get gearUpTouchPosition => _gearUpTouchPosition;

  @override
  Offset? get gearDownTouchPosition => _gearDownTouchPosition;

  @override
  void init(SupportedApp? supportedApp) {
    streamEvents().listen((windowEvent) {
      supportedApp = SupportedApp.supportedApps.firstOrNullWhere((e) => e.packageName == windowEvent.packageName);
      if (supportedApp != null) {
        windowInfo = windowEvent;
      }
    });
  }

  @override
  Future<void> performAction(ZwiftButton button) async {
    if (_gearDownTouchPosition == null) {
      if (windowInfo == null) {
        throw SingleLineException("Could not perform ${button.name}: No window info");
      }
      if (supportedApp == null) {
        throw SingleLineException("Could not perform ${button.name}: No supported app detected");
      }
      final point = supportedApp!.resolveTouchPosition(action: button, windowInfo: windowInfo!);

      accessibilityHandler.performTouch(point.dx, point.dy);
    } else {
      accessibilityHandler.performTouch(_gearDownTouchPosition!.dx, _gearDownTouchPosition!.dy);
    }
  }

  @override
  void updateTouchPositions(Offset gearUp, Offset gearDown) {
    _gearUpTouchPosition = gearUp;
    _gearDownTouchPosition = gearDown;
  }
}
