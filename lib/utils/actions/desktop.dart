import 'package:keypress_simulator/keypress_simulator.dart';
import 'package:swift_control/utils/actions/base_actions.dart';
import 'package:swift_control/utils/keymap/buttons.dart';
import 'package:swift_control/widgets/keymap_explanation.dart';

class DesktopActions extends BaseActions {
  // Track keys that are currently held down in long press mode

  @override
  Future<String> performAction(ZwiftButton action, {bool isKeyDown = true, bool isKeyUp = false}) async {
    if (supportedApp == null) {
      return ('Supported app is not set');
    }

    final keyPair = supportedApp!.keymap.getKeyPair(action);
    if (keyPair == null) {
      return ('Keymap entry not found for action: ${action.toString().splitByUpperCase()}');
    }

    // Handle regular key press mode (existing behavior)
    if (keyPair.physicalKey != null) {
      if (isKeyDown) {
        await keyPressSimulator.simulateKeyDown(keyPair.physicalKey);
        return 'Key pressed: $keyPair';
      } else if (isKeyUp) {
        await keyPressSimulator.simulateKeyUp(keyPair.physicalKey);
        return 'Key released: $keyPair';
      } else {
        await keyPressSimulator.simulateKeyDown(keyPair.physicalKey);
        await keyPressSimulator.simulateKeyUp(keyPair.physicalKey);
        return 'Key clicked: $keyPair';
      }
    } else {
      final point = supportedApp!.resolveTouchPosition(action: action, windowInfo: null);
      if (isKeyDown) {
        await keyPressSimulator.simulateMouseClickDown(point);
        return 'Mouse down at: ${point.dx} ${point.dy}';
      } else if (isKeyUp) {
        await keyPressSimulator.simulateMouseClickUp(point);
        return 'Mouse up at: ${point.dx} ${point.dy}';
      } else {
        await keyPressSimulator.simulateMouseClickDown(point);
        await keyPressSimulator.simulateMouseClickUp(point);
      }
      return 'Mouse clicked at: ${point.dx} ${point.dy}';
    }
  }

  // Release all held keys (useful for cleanup)
  Future<void> releaseAllHeldKeys(List<ZwiftButton> list) async {
    for (final action in list) {
      final keyPair = supportedApp?.keymap.getKeyPair(action);
      if (keyPair?.physicalKey != null) {
        await keyPressSimulator.simulateKeyUp(keyPair!.physicalKey);
      }
    }
  }
}
