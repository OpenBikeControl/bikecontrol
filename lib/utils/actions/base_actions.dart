import 'dart:ui';

import 'package:swift_control/utils/keymap/buttons.dart';

abstract class BaseActions {
  SupportedApp? supportedApp;

  Offset? get gearUpTouchPosition => null;
  Offset? get gearDownTouchPosition => null;

  void init(SupportedApp? supportedApp) {
    this.supportedApp = supportedApp;
  }

  void performAction(ZwiftButton action);

  void updateTouchPositions(Offset gearUp, Offset gearDown) {}
}

class StubActions extends BaseActions {
  @override
  void performAction(ZwiftButton action) {
    print('Decrease gear');
  }
}
