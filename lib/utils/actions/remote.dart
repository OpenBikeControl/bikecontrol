import 'dart:ui';

import 'package:accessibility/accessibility.dart';
import 'package:bike_control/utils/actions/base_actions.dart';
import 'package:bike_control/utils/core.dart';
import 'package:bike_control/utils/keymap/buttons.dart';
import 'package:bike_control/utils/keymap/keymap.dart';
import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher_string.dart';

import '../../gen/l10n.dart';
import '../../widgets/keymap_explanation.dart';

class RemoteActions extends BaseActions {
  RemoteActions({super.supportedModes = const [SupportedMode.touch, SupportedMode.keyboard]});

  @override
  Future<ActionResult> performAction(ControllerButton button, {required bool isKeyDown, required bool isKeyUp}) async {
    final keyPair = supportedApp!.keymap.getKeyPair(button);

    if (keyPair == null || keyPair.hasNoAction) {
      return Error(AppLocalizations.current.noActionAssignedForButton(button.name.splitByUpperCase()));
    }

    if (defaultTargetPlatform == TargetPlatform.iOS && keyPair.shortcutName?.trim().isNotEmpty == true) {
      if (!isKeyDown) {
        return Ignored('Shortcut launch only runs on key down');
      }
      final shortcutName = Uri.encodeQueryComponent(keyPair.shortcutName!.trim());
      final launched = await launchUrlString('shortcuts://run-shortcut?name=$shortcutName');
      if (!launched) {
        return Error('Failed to launch shortcut: ${keyPair.shortcutName}');
      }
      return Success('Shortcut launched: ${keyPair.shortcutName}');
    }

    final superResult = await super.performAction(button, isKeyDown: isKeyDown, isKeyUp: isKeyUp);
    if (superResult is! NotHandled) {
      return superResult;
    }

    if (!core.remotePairing.isConnected.value && !core.remoteKeyboardPairing.isConnected.value) {
      return Error('Not connected to a ${core.settings.getLastTarget()?.name ?? 'remote'} device');
    }

    if (core.remotePairing.isConnected.value) {
      if (keyPair.touchPosition == Offset.zero) {
        return Error('Key $keyPair does not have a valid touch position');
      }
      return core.remotePairing.sendAction(keyPair, isKeyDown: isKeyDown, isKeyUp: isKeyUp);
    } else if (core.remoteKeyboardPairing.isConnected.value) {
      if (keyPair.physicalKey == null) {
        return Error('Key $keyPair does not have a valid physical key for keyboard actions');
      }
      return core.remoteKeyboardPairing.sendAction(keyPair, isKeyDown: isKeyDown, isKeyUp: isKeyUp);
    } else {
      return Error('Not connected to a ${core.settings.getLastTarget()?.name ?? 'remote'} device');
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
