import 'package:accessibility/accessibility.dart';
import 'package:flutter/services.dart';
import 'package:swift_control/main.dart';
import 'package:swift_control/utils/actions/base_actions.dart';
import 'package:swift_control/utils/keymap/apps/custom_app.dart';
import 'package:swift_control/utils/keymap/buttons.dart';

import '../keymap/apps/supported_app.dart';
import '../single_line_exception.dart';

class AndroidActions extends BaseActions {
  WindowEvent? windowInfo;

  @override
  void init(SupportedApp? supportedApp) {
    super.init(supportedApp);
    streamEvents().listen((windowEvent) {
      if (supportedApp != null) {
        windowInfo = windowEvent;
      }
    });
  }

  @override
  Future<String> performAction(ZwiftButton button) async {
    if (supportedApp == null) {
      return ("Could not perform ${button.name}: No keymap set");
    }

    if (supportedApp is CustomApp) {
      final keyPair = supportedApp!.keymap.getKeyPair(button);
      if (keyPair != null && keyPair.isSpecialKey) {
        await accessibilityHandler.controlMedia(switch (keyPair.physicalKey) {
          PhysicalKeyboardKey.mediaTrackNext => MediaAction.next,
          PhysicalKeyboardKey.mediaPlayPause => MediaAction.playPause,
          PhysicalKeyboardKey.audioVolumeUp => MediaAction.volumeUp,
          PhysicalKeyboardKey.audioVolumeDown => MediaAction.volumeDown,
          _ => throw SingleLineException("No action for key: ${keyPair.physicalKey}"),
        });
        return "Key pressed: ${keyPair.toString()}";
      }
    }
    final point = supportedApp!.resolveTouchPosition(action: button, windowInfo: windowInfo);
    if (point != Offset.zero) {
      accessibilityHandler.performTouch(point.dx, point.dy);
    }
    return "Touch performed at: ${point.dx.toInt()}, ${point.dy.toInt()}";
  }
}
