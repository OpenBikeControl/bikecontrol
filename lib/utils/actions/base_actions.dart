import 'package:swift_control/utils/keymap/buttons.dart';

abstract class BaseActions {
  SupportedApp? supportedApp;

  void init(SupportedApp? supportedApp) {
    this.supportedApp = supportedApp;
  }

  void performAction(ZwiftButton action);
}

class StubActions extends BaseActions {
  @override
  void performAction(ZwiftButton action) {
    print('Decrease gear');
  }
}
