import 'package:keypress_simulator/keypress_simulator.dart';
import 'package:swift_control/utils/actions/base_actions.dart';
import 'package:swift_control/utils/keymap/buttons.dart';

class DesktopActions extends BaseActions {
  // Track keys that are currently held down in long press mode
  final Set<ZwiftButton> _heldKeys = <ZwiftButton>{};

  @override
  Future<String> performAction(ZwiftButton action, {bool isPressed = true, bool isRepeated = false}) async {
    if (supportedApp == null) {
      return ('Supported app is not set');
    }

    final keyPair = supportedApp!.keymap.getKeyPair(action);
    if (keyPair == null) {
      return ('Keymap entry not found for action: $action');
    }

    // Handle long press mode
    if (keyPair.isLongPress && keyPair.physicalKey != null) {
      if (isPressed && !isRepeated) {
        // Key press: start long press
        if (!_heldKeys.contains(action)) {
          _heldKeys.add(action);
          await keyPressSimulator.simulateKeyDown(keyPair.physicalKey);
          return 'Long press started: ${keyPair.logicalKey?.keyLabel}';
        }
      } else if (!isPressed) {
        // Key release: end long press
        if (_heldKeys.contains(action)) {
          _heldKeys.remove(action);
          await keyPressSimulator.simulateKeyUp(keyPair.physicalKey);
          return 'Long press ended: ${keyPair.logicalKey?.keyLabel}';
        }
      }
      // Ignore repeated presses in long press mode
      return 'Long press active: ${keyPair.logicalKey?.keyLabel}';
    }

    // Handle regular key press mode (existing behavior)
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

  // Release all held keys (useful for cleanup)
  Future<void> releaseAllHeldKeys() async {
    for (final action in _heldKeys.toList()) {
      final keyPair = supportedApp?.keymap.getKeyPair(action);
      if (keyPair?.physicalKey != null) {
        await keyPressSimulator.simulateKeyUp(keyPair!.physicalKey);
      }
    }
    _heldKeys.clear();
  }
}
