import 'package:keypress_simulator/keypress_simulator.dart';
import 'package:swift_control/utils/actions/base_actions.dart';
import 'package:swift_control/utils/keymap/buttons.dart';
import 'package:swift_control/widgets/keymap_explanation.dart';

class DesktopActions extends BaseActions {
  // Track keys that are currently held down in long press mode
  final Set<ZwiftButton> _heldKeys = <ZwiftButton>{};

  @override
  Future<String> performAction(ZwiftButton action, {bool isKeyDown = true, bool isKeyUp = false}) async {
    if (supportedApp == null) {
      return ('Supported app is not set');
    }

    final keyPair = supportedApp!.keymap.getKeyPair(action);
    if (keyPair == null) {
      return ('Keymap entry not found for action: ${action.toString().splitByUpperCase()}');
    }

    // Handle long press mode
    if (keyPair.isLongPress) {
      if (isKeyDown && !isKeyUp) {
        // Key press: start long press
        if (!_heldKeys.contains(action)) {
          _heldKeys.add(action);
          if (keyPair.physicalKey != null) {
            await keyPressSimulator.simulateKeyDown(keyPair.physicalKey);
            return 'Long press started: ${keyPair.logicalKey?.keyLabel}';
          } else {
            final point = supportedApp!.resolveTouchPosition(action: action, windowInfo: null);
            await keyPressSimulator.simulateMouseClickDown(point);
            return 'Long Mouse click started at: $point';
          }
        }
      } else if (isKeyUp && !isKeyDown) {
        // Key release: end long press
        if (_heldKeys.contains(action)) {
          _heldKeys.remove(action);
          if (keyPair.physicalKey != null) {
            await keyPressSimulator.simulateKeyUp(keyPair.physicalKey);
            return 'Long press ended: ${keyPair.logicalKey?.keyLabel}';
          } else {
            final point = supportedApp!.resolveTouchPosition(action: action, windowInfo: null);
            await keyPressSimulator.simulateMouseClickUp(point);
            return 'Long Mouse click ended at: $point';
          }
        }
      }
      // Ignore other combinations in long press mode
      return 'Long press active';
    } else {
      // Handle regular key press mode (existing behavior)
      if (keyPair.physicalKey != null) {
        await keyPressSimulator.simulateKeyDown(keyPair.physicalKey);
        await keyPressSimulator.simulateKeyUp(keyPair.physicalKey);
        return 'Key pressed: $keyPair';
      } else {
        final point = supportedApp!.resolveTouchPosition(action: action, windowInfo: null);
        await keyPressSimulator.simulateMouseClickDown(point);
        await keyPressSimulator.simulateMouseClickUp(point);
        return 'Mouse clicked at: $point';
      }
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
