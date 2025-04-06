import 'package:accessibility/accessibility.dart';
import 'package:swift_control/main.dart';
import 'package:swift_control/utils/actions/base_actions.dart';
import 'package:swift_control/utils/keymap/buttons.dart';

import '../keymap/apps/supported_app.dart';
import '../single_line_exception.dart';

class AndroidActions extends BaseActions {
  WindowEvent? windowInfo;

  @override
  void init(SupportedApp? supportedApp) {
    streamEvents().listen((windowEvent) {
      if (supportedApp != null) {
        windowInfo = windowEvent;
      }
    });
  }

  @override
  Future<String> performAction(ZwiftButton button) async {
    if (windowInfo == null) {
      throw SingleLineException("Could not perform ${button.name}: No window info");
    }
    if (supportedApp == null) {
      throw SingleLineException("Could not perform ${button.name}: No supported app detected");
    }
    final point = supportedApp!.resolveTouchPosition(action: button, windowInfo: windowInfo!);

    accessibilityHandler.performTouch(point.dx, point.dy);
    return "Touch performed at: ${point.dx}, ${point.dy}";
  }
}
