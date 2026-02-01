import 'package:bike_control/main.dart';
import 'package:bike_control/utils/actions/base_actions.dart';
import 'package:bike_control/utils/core.dart';
import 'package:bike_control/utils/iap/iap_manager.dart';
import 'package:bike_control/utils/keymap/buttons.dart';
import 'package:bike_control/widgets/ui/toast.dart';
import 'package:keypress_simulator/keypress_simulator.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

class DesktopActions extends BaseActions {
  DesktopActions({super.supportedModes = const [SupportedMode.keyboard, SupportedMode.touch, SupportedMode.media]});

  // Track keys that are currently held down in long press mode

  @override
  Future<ActionResult> performAction(ControllerButton button, {required bool isKeyDown, required bool isKeyUp}) async {
    final superResult = await super.performAction(button, isKeyDown: isKeyDown, isKeyUp: isKeyUp);
    if (superResult is! NotHandled) {
      return superResult;
    }
    final keyPair = supportedApp!.keymap.getKeyPair(button)!;

    if (core.settings.getLocalEnabled()) {
      // Handle media keys
      if (keyPair.isSpecialKey) {
        try {
          await keyPressSimulator.simulateMediaKey(keyPair.physicalKey!);
          // Increment command count after successful execution
          await IAPManager.instance.incrementCommandCount();
          return Success('Media key pressed: $keyPair');
        } catch (e) {
          return Error('Failed to simulate media key: $e');
        }
      }

      if (keyPair.physicalKey != null) {
        // Increment command count after successful execution
        await IAPManager.instance.incrementCommandCount();
        if (keyPair.logicalKey != null && navigatorKey.currentContext?.mounted == true) {
          final label = keyPair.logicalKey!.keyLabel;
          final keyName = label.isNotEmpty ? label : keyPair.logicalKey!.debugName ?? 'Key';
          buildToast(
            navigatorKey.currentContext!,

            location: ToastLocation.bottomLeft,
            title:
                '${isKeyDown
                    ? "↓"
                    : isKeyUp
                    ? "↑"
                    : "•"} $keyName',
          );
        }

        if (isKeyDown && isKeyUp) {
          await keyPressSimulator.simulateKeyDown(keyPair.physicalKey, keyPair.modifiers);
          await keyPressSimulator.simulateKeyUp(keyPair.physicalKey, keyPair.modifiers);

          return Success('Key clicked: $keyPair');
        } else if (isKeyDown) {
          await keyPressSimulator.simulateKeyDown(keyPair.physicalKey, keyPair.modifiers);
          return Success('Key pressed: $keyPair');
        } else {
          await keyPressSimulator.simulateKeyUp(keyPair.physicalKey, keyPair.modifiers);
          return Success('Key released: $keyPair');
        }
      } else {
        final point = await resolveTouchPosition(keyPair: keyPair, windowInfo: null);
        if (point != Offset.zero) {
          // Increment command count after successful execution
          await IAPManager.instance.incrementCommandCount();
          if (isKeyDown && isKeyUp) {
            await keyPressSimulator.simulateMouseClickDown(point);
            // slight move to register clicks on some apps, see issue #116
            await keyPressSimulator.simulateMouseClickUp(point);
            return Success('Mouse clicked at: ${point.dx.toInt()} ${point.dy.toInt()}');
          } else if (isKeyDown) {
            await keyPressSimulator.simulateMouseClickDown(point);
            return Success('Mouse down at: ${point.dx.toInt()} ${point.dy.toInt()}');
          } else {
            await keyPressSimulator.simulateMouseClickUp(point);
            return Success('Mouse up at: ${point.dx.toInt()} ${point.dy.toInt()}');
          }
        }
      }
    }
    return NotHandled('Action not handled for button: $button');
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

  @override
  void cleanup() {}
}
