import 'package:keypress_simulator/keypress_simulator.dart';
import 'package:swift_control/utils/actions/base_actions.dart';
import 'package:swift_control/utils/keymap/buttons.dart';

class DesktopActions extends BaseActions {
  @override
  Future<String> performAction(ZwiftButton action) async {
    if (supportedApp == null) {
      return ('Supported app is not set');
    }

    final keyPair = supportedApp!.keymap.getKeyPair(action);
    if (keyPair == null) {
      return ('Keymap entry not found for action: $action');
    }

    if (keyPair.physicalKey != null) {
      await keyPressSimulator.simulateKeyDown(keyPair.physicalKey);
      await keyPressSimulator.simulateKeyUp(keyPair.physicalKey);
      return 'Key pressed: ${keyPair.logicalKey?.keyLabel}';
    } else {
      final point = supportedApp!.resolveTouchPosition(action: action, windowInfo: null);
      await keyPressSimulator.simulateMouseClick(point);
      return 'Mouse clicked at: $point';
    }
  }
}
