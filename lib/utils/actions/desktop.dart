import 'package:keypress_simulator/keypress_simulator.dart';
import 'package:swift_control/utils/actions/base_actions.dart';
import 'package:swift_control/utils/keymap/buttons.dart';
import 'package:swift_control/utils/single_line_exception.dart';

class DesktopActions extends BaseActions {
  @override
  Future<void> performAction(ZwiftButton action) async {
    if (supportedApp == null) {
      throw SingleLineException('Supported app is not set');
    }

    final key = supportedApp!.keymap.getPhysicalKey(action);
    if (key == null) {
      throw SingleLineException('Keymap entry not found for action: $action');
    }

    await keyPressSimulator.simulateKeyDown(key);
    await keyPressSimulator.simulateKeyUp(key);
  }
}
