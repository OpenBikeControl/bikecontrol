import 'package:swift_control/utils/keymap/buttons.dart';

import '../keymap/apps/supported_app.dart';

abstract class BaseActions {
  SupportedApp? supportedApp;

  void init(SupportedApp? supportedApp) {
    this.supportedApp = supportedApp;
  }

  Future<String> performAction(ZwiftButton action, {bool isPressed = true, bool isRepeated = false});
}

class StubActions extends BaseActions {
  @override
  Future<String> performAction(ZwiftButton action, {bool isPressed = true, bool isRepeated = false}) {
    return Future.value(action.name);
  }
}
