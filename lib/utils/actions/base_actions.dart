import 'package:accessibility/accessibility.dart';
import 'package:flutter/material.dart';
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

  Offset resolveTouchPosition({required ZwiftButton action, required WindowEvent? windowInfo}) {
    final keyPair = supportedApp!.keymap.getKeyPair(action);
    if (keyPair != null && keyPair.touchPosition != Offset.zero) {
      // convert relative position to absolute position based on window info
      if (windowInfo != null && windowInfo.right != 0) {
        final x = windowInfo.left + (keyPair.touchPosition.dx / 100) * (windowInfo.right - windowInfo.left);
        final y = windowInfo.top + (keyPair.touchPosition.dy / 100) * (windowInfo.bottom - windowInfo.top);
        return Offset(x, y);
      } else {
        final screenSize = WidgetsBinding.instance.platformDispatcher.views.first.display.size;
        print('Screen size: $screenSize');
        final x = (keyPair.touchPosition.dx / 100) * screenSize.width;
        final y = (keyPair.touchPosition.dy / 100) * screenSize.height;
        return Offset(x, y);
      }
    }
    return Offset.zero;
  }

  Future<String> performAction(ZwiftButton action, {bool isKeyDown = true, bool isKeyUp = false});
}

class StubActions extends BaseActions {
  StubActions({super.supportedModes = const []});

  @override
  Future<String> performAction(ZwiftButton action, {bool isKeyDown = true, bool isKeyUp = false}) {
    return Future.value(action.name);
  }
}
