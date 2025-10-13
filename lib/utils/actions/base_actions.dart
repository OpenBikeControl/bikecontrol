import 'package:accessibility/accessibility.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:swift_control/utils/actions/android.dart';
import 'package:swift_control/utils/actions/desktop.dart';
import 'package:swift_control/utils/keymap/buttons.dart';

import '../keymap/apps/supported_app.dart';

enum SupportedMode { keyboard, touch, media }

abstract class BaseActions {
  final List<SupportedMode> supportedModes;

  SupportedApp? supportedApp;

  BaseActions({required this.supportedModes});

  void init(SupportedApp? supportedApp) {
    this.supportedApp = supportedApp;
  }

  Offset resolveTouchPosition({required ControllerButton action, required WindowEvent? windowInfo}) {
    final keyPair = supportedApp!.keymap.getKeyPair(action);
    if (keyPair != null && keyPair.touchPosition != Offset.zero) {
      // convert relative position to absolute position based on window info

      if (windowInfo != null && windowInfo.top > 0) {
        final x = windowInfo.left + (keyPair.touchPosition.dx / 100) * (windowInfo.right - windowInfo.left);
        final y = windowInfo.top + (keyPair.touchPosition.dy / 100) * (windowInfo.bottom - windowInfo.top);

        if (kDebugMode) {
          print("Window info: ${windowInfo.encode()} => Touch at: $x, $y");
        }
        return Offset(x, y);
      } else {
        // TODO support multiple screens
        final display = WidgetsBinding.instance.platformDispatcher.views.first.display;
        final displaySize = display.size;

        late final Size physicalSize;
        if (this is AndroidActions) {
          // display size is already in physical pixels
          physicalSize = displaySize;
        } else if (this is DesktopActions) {
          // display size is in logical pixels, convert to physical pixels
          // TODO on macOS the notch is included here, but it's not part of the usable screen area, so we should exclude it
          physicalSize = displaySize / display.devicePixelRatio;
        } else {
          physicalSize = displaySize;
        }

        final x = (keyPair.touchPosition.dx / 100.0) * physicalSize.width;
        final y = (keyPair.touchPosition.dy / 100.0) * physicalSize.height;

        if (kDebugMode) {
          print("Screen size: $physicalSize => Touch at: $x, $y");
        }
        return Offset(x, y);
      }
    }
    return Offset.zero;
  }

  Future<String> performAction(ControllerButton action, {bool isKeyDown = true, bool isKeyUp = false});
}

class StubActions extends BaseActions {
  StubActions({super.supportedModes = const []});

  @override
  Future<String> performAction(ControllerButton action, {bool isKeyDown = true, bool isKeyUp = false}) {
    return Future.value(action.name);
  }
}
