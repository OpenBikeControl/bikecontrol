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
import '../iap/iap_manager.dart';

class RemoteActions extends BaseActions {
  RemoteActions({super.supportedModes = const [SupportedMode.touch, SupportedMode.keyboard]});

  @override
  Future<ActionResult> performAction(
    ControllerButton button, {
    required bool isKeyDown,
    required bool isKeyUp,
    ButtonTrigger trigger = ButtonTrigger.singleClick,
  }) async {
    final app = supportedApp;
    if (app == null) {
      // The keymap pref ('app') can be missing while a trainer app ('trainer_app')
      // is selected — never dereference it, report it like BaseActions does.
      return Error(
        AppLocalizations.current.couldNotPerformButtonnamesplitbyuppercaseNoKeymapSet(button.name.splitByUpperCase()),
        type: ErrorType.noKeymapSet,
        button: button,
      );
    }

    final keyPair = app.keymap.getKeyPair(button, trigger: trigger);

    if (keyPair == null || keyPair.hasNoAction) {
      return Error(
        AppLocalizations.current.noActionAssignedForButton(button.name.splitByUpperCase()),
        button: keyPair?.buttons.firstOrNull ?? button,
      );
    }

    final guard = proGuard(button: button, trigger: trigger, keyPair: keyPair);
    if (guard is! NotHandled) {
      return guard;
    }

    if (defaultTargetPlatform == TargetPlatform.iOS && keyPair.command?.trim().isNotEmpty == true) {
      if (!isKeyDown) {
        return Ignored(
          'Shortcut launch only runs on key down',
          button: keyPair.buttons.firstOrNull,
        );
      }
      final shortcutName = Uri.encodeQueryComponent(keyPair.command!.trim());
      final launched = await launchUrlString('shortcuts://run-shortcut?name=$shortcutName');
      if (!launched) {
        return Error(
          'Failed to launch shortcut: ${keyPair.command}',
          button: keyPair.buttons.firstOrNull,
        );
      }
      await IAPManager.instance.incrementCommandCount();
      return Success(
        'Shortcut launched: ${keyPair.command}',
        button: keyPair.buttons.firstOrNull,
      );
    }

    final superResult = await super.performAction(button, isKeyDown: isKeyDown, isKeyUp: isKeyUp, trigger: trigger);
    if (superResult is! NotHandled) {
      return superResult;
    }

    if (core.remotePairing.isStarted.value && core.remotePairing.isConnected.value) {
      if (keyPair.touchPosition == Offset.zero) {
        return Error(
          'Key $keyPair does not have a valid touch position',
          button: keyPair.buttons.firstOrNull,
        );
      }
      return core.remotePairing.sendAction(keyPair, isKeyDown: isKeyDown, isKeyUp: isKeyUp);
    } else if (core.remoteKeyboardPairing.isStarted.value && core.remoteKeyboardPairing.isConnected.value) {
      if (keyPair.physicalKey == null) {
        return Error(
          'Key $keyPair does not have a valid physical key for keyboard actions',
          button: keyPair.buttons.firstOrNull,
        );
      }
      return core.remoteKeyboardPairing.sendAction(keyPair, isKeyDown: isKeyDown, isKeyUp: isKeyUp);
    } else if (core.remoteKeyboardPairing.isStarted.value || core.remotePairing.isStarted.value) {
      return Error(
        'Not connected to a ${core.settings.getLastTarget()?.name ?? 'remote'} device',
        button: keyPair.buttons.firstOrNull,
      );
    } else if (keyPair.physicalKey != null || keyPair.touchPosition != Offset.zero) {
      // A trainer app can be connected (e.g. over OpenBikeControl) — only the
      // method this keyboard key / touch needs is off, so name that one.
      final method = keyPair.physicalKey != null
          ? AppLocalizations.current.actAsBluetoothKeyboard
          : AppLocalizations.current.enablePairingProcess;
      return NotHandled(
        AppLocalizations.current.connectionMethodNotActiveForButton(button.name.splitByUpperCase(), method),
        button: keyPair.buttons.firstOrNull,
      );
    } else {
      return NotHandled('No connection method active', button: keyPair.buttons.firstOrNull);
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
