import 'package:bluetooth_low_energy/bluetooth_low_energy.dart';
import 'package:swift_control/utils/keymap/buttons.dart';

import '../keymap/apps/supported_app.dart';

abstract class BaseActions {
  SupportedApp? supportedApp;

  void init(SupportedApp? supportedApp) {
    this.supportedApp = supportedApp;
  }

  Future<String> performAction(ZwiftButton action, {bool isKeyDown = true, bool isKeyUp = false});
}

abstract class AccessibilityActions extends BaseActions {
  Central? connectedCentral;
  GATTCharacteristic? connectedCharacteristic;

  void setConnectedCentral(Central? central, GATTCharacteristic? gattCharacteristic) {
    connectedCentral = central;
    connectedCharacteristic = gattCharacteristic;
  }

  bool get isConnected => connectedCentral != null;
}

class StubActions extends BaseActions {
  @override
  Future<String> performAction(ZwiftButton action, {bool isKeyDown = true, bool isKeyUp = false}) {
    return Future.value(action.name);
  }
}
