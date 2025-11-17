import 'dart:ui';

import 'package:keypress_simulator/keypress_simulator.dart';
import 'package:swift_control/utils/actions/base_actions.dart';
import 'package:swift_control/utils/keymap/buttons.dart';
import 'package:swift_control/widgets/keymap_explanation.dart';

class DesktopActions extends BaseActions {
  DesktopActions({super.supportedModes = const [SupportedMode.keyboard, SupportedMode.touch, SupportedMode.media]});

  // Track keys that are currently held down in long press mode

  @override
  Future<String> performAction(ControllerButton action, {bool isKeyDown = true, bool isKeyUp = false}) async {
    if (supportedApp == null) {
      return ('Supported app is not set');
    }

    final keyPair = supportedApp!.keymap.getKeyPair(action);
    if (keyPair == null) {
      return ('Keymap entry not found for action: ${action.toString().splitByUpperCase()}');
    }

    final directConnectHandled = await handleDirectConnect(keyPair);

    if (directConnectHandled != null) {
      return directConnectHandled;
    } else if (keyPair.physicalKey != null) {
      if (isKeyDown && isKeyUp) {
        await keyPressSimulator.simulateKeyDown(keyPair.physicalKey, keyPair.modifiers);
        await keyPressSimulator.simulateKeyUp(keyPair.physicalKey, keyPair.modifiers);
        return 'Key clicked: $keyPair';
      } else if (isKeyDown) {
        await keyPressSimulator.simulateKeyDown(keyPair.physicalKey, keyPair.modifiers);
        return 'Key pressed: $keyPair';
      } else {
        await keyPressSimulator.simulateKeyUp(keyPair.physicalKey, keyPair.modifiers);
        return 'Key released: $keyPair';
      }
    } else {
      final point = await resolveTouchPosition(keyPair: keyPair, windowInfo: null);
      if (point != Offset.zero) {
        if (isKeyDown && isKeyUp) {
          await keyPressSimulator.simulateMouseClickDown(point);
          // slight move to register clicks on some apps, see issue #116
          await keyPressSimulator.simulateMouseClickUp(point);
          return 'Mouse clicked at: ${point.dx.toInt()} ${point.dy.toInt()}';
        } else if (isKeyDown) {
          await keyPressSimulator.simulateMouseClickDown(point);
          return 'Mouse down at: ${point.dx.toInt()} ${point.dy.toInt()}';
        } else {
          await keyPressSimulator.simulateMouseClickUp(point);
          return 'Mouse up at: ${point.dx.toInt()} ${point.dy.toInt()}';
        }
      } else {
        return 'No action assigned';
      }
    }
  }

  // Release all held keys (useful for cleanup)
  Future<void> releaseAllHeldKeys(List<ControllerButton> list) async {
    for (final action in list) {
      final keyPair = supportedApp?.keymap.getKeyPair(action);
      if (keyPair?.physicalKey != null) {
        await keyPressSimulator.simulateKeyUp(keyPair!.physicalKey);
      }
    }
  }
}
