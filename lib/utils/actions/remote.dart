import 'dart:ui';

import 'package:accessibility/accessibility.dart';
import 'package:flutter/foundation.dart';
import 'package:swift_control/utils/actions/base_actions.dart';
import 'package:swift_control/utils/core.dart';
import 'package:swift_control/utils/keymap/buttons.dart';
import 'package:swift_control/utils/keymap/keymap.dart';

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
      final point = await resolveTouchPosition(keyPair: keyPair, windowInfo: null);
      final point2 = point; //Offset(100, 99.0);
      await sendAbsMouseReport(0, point2.dx.toInt(), point2.dy.toInt());
      await sendAbsMouseReport(1, point2.dx.toInt(), point2.dy.toInt());
      await sendAbsMouseReport(0, point2.dx.toInt(), point2.dy.toInt());

      return Success('Mouse clicked at: ${point2.dx.toInt()} ${point2.dy.toInt()}');
    }
  }

  @override
  Future<Offset> resolveTouchPosition({required KeyPair keyPair, required WindowEvent? windowInfo}) async {
    // for remote actions we use the relative position only
    return keyPair.touchPosition;
  }

  Uint8List absMouseReport(int buttons3bit, int x, int y) {
    final b = buttons3bit & 0x07;
    final xi = x.clamp(0, 100);
    final yi = y.clamp(0, 100);
    return Uint8List.fromList([b, xi, yi]);
  }

  // Send a relative mouse move + button state as 3-byte report: [buttons, dx, dy]
  Future<void> sendAbsMouseReport(int buttons, int dx, int dy) async {
    final bytes = absMouseReport(buttons, dx, dy);
    if (kDebugMode) {
      print('Preparing to send abs mouse report: buttons=$buttons, dx=$dx, dy=$dy');
      print('Sending abs mouse report: ${bytes.map((e) => e.toRadixString(16).padLeft(2, '0'))}');
    }

    await core.remotePairing.notifyCharacteristic(bytes);

    // we don't want to overwhelm the target device
    await Future.delayed(Duration(milliseconds: 10));
  }
}
