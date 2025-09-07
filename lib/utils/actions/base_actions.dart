import 'package:swift_control/utils/keymap/buttons.dart';

import '../keymap/apps/supported_app.dart';

abstract class BaseActions {
  SupportedApp? supportedApp;

  void init(SupportedApp? supportedApp) {
    this.supportedApp = supportedApp;
  }

  Future<String> performAction(ZwiftButton action, {bool isKeyDown = true, bool isKeyUp = false});
}

class StubActions extends BaseActions {
  @override
  Future<String> performAction(ZwiftButton action, {bool isKeyDown = true, bool isKeyUp = false}) {
    return Future.value(action.name);
  }
}
