import 'dart:io';

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
      // Check if we're on Windows and have window targeting information
      if (Platform.isWindows && 
          (supportedApp!.windowsProcessName != null || supportedApp!.windowsWindowTitle != null)) {
        await keyPressSimulator.simulateKeyDownToWindow(
          keyPair.physicalKey,
          processName: supportedApp!.windowsProcessName,
          windowTitle: supportedApp!.windowsWindowTitle,
        );
        await keyPressSimulator.simulateKeyUpToWindow(
          keyPair.physicalKey,
          processName: supportedApp!.windowsProcessName,
          windowTitle: supportedApp!.windowsWindowTitle,
        );
        return 'Key pressed to window: ${keyPair.logicalKey?.keyLabel}';
      } else {
        // Fallback to global key simulation
        await keyPressSimulator.simulateKeyDown(keyPair.physicalKey);
        await keyPressSimulator.simulateKeyUp(keyPair.physicalKey);
        return 'Key pressed: ${keyPair.logicalKey?.keyLabel}';
      }
    } else {
      final point = supportedApp!.resolveTouchPosition(action: action, windowInfo: null);
      await keyPressSimulator.simulateMouseClick(point);
      return 'Mouse clicked at: $point';
    }
  }
}
