import 'dart:ui';

import 'package:accessibility/accessibility.dart';
import 'package:bike_control/utils/actions/base_actions.dart';
import 'package:bike_control/utils/core.dart';
import 'package:bike_control/utils/keymap/buttons.dart';
import 'package:bike_control/utils/keymap/keymap.dart';

class RemoteActions extends BaseActions {
  RemoteActions({super.supportedModes = const [SupportedMode.touch]});

  @override
  Future<ActionResult> performAction(ControllerButton button, {required bool isKeyDown, required bool isKeyUp}) async {
    final superResult = await super.performAction(button, isKeyDown: isKeyDown, isKeyUp: isKeyUp);
    if (superResult is! NotHandled) {
      return superResult;
    }
    final keyPair = supportedApp!.keymap.getKeyPair(button)!;
    if (!core.remotePairing.isConnected.value) {
      return Error('Not connected to a ${core.settings.getLastTarget()?.name ?? 'remote'} device');
    }

    if (keyPair.physicalKey != null && keyPair.touchPosition == Offset.zero) {
      return Error('Physical key actions are not supported, yet');
    } else {
      return core.remotePairing.sendAction(keyPair, isKeyDown: isKeyDown, isKeyUp: isKeyUp);
    }
  }

  @override
  Future<Offset> resolveTouchPosition({required KeyPair keyPair, required WindowEvent? windowInfo}) async {
    // for remote actions we use the relative position only
    return keyPair.touchPosition;
  }

  @override
  void cleanup() {}
}
