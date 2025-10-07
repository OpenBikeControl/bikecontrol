import 'dart:math';

import 'package:bluetooth_low_energy/bluetooth_low_energy.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:swift_control/utils/actions/base_actions.dart';
import 'package:swift_control/utils/keymap/buttons.dart';
import 'package:swift_control/widgets/keymap_explanation.dart';

import '../keymap/apps/supported_app.dart';
import '../requirements/ios.dart';

class IosActions extends BaseActions {
  Central? _connectedCentral;
  GATTCharacteristic? _connectedCharacteristic;

  late final Size screenSize;

  @override
  void init(SupportedApp? supportedApp) {
    super.init(supportedApp);

    final flutterView = WidgetsBinding.instance.platformDispatcher.views.first;
    screenSize = flutterView.physicalSize;
  }

  @override
  Future<String> performAction(ZwiftButton action, {bool isKeyDown = true, bool isKeyUp = false}) async {
    if (supportedApp == null) {
      return ('Supported app is not set');
    }

    final keyPair = supportedApp!.keymap.getKeyPair(action);
    if (keyPair == null) {
      return ('Keymap entry not found for action: ${action.toString().splitByUpperCase()}');
    }

    if (keyPair.physicalKey != null) {
      return ('Physical key actions are not supported on iOS');
    } else {
      final point = supportedApp!.resolveTouchPosition(action: action, windowInfo: null);
      /*if (isKeyDown && isKeyUp) {
        await keyPressSimulator.simulateMouseClickDown(point);
        await keyPressSimulator.simulateMouseClickUp(point);
        return 'Mouse clicked at: ${point.dx} ${point.dy}';
      } else if (isKeyDown) {
        await keyPressSimulator.simulateMouseClickDown(point);
        return 'Mouse down at: ${point.dx} ${point.dy}';
      } else {
        await keyPressSimulator.simulateMouseClickUp(point);
        return 'Mouse up at: ${point.dx} ${point.dy}';
      }*/
      await sendAbsMouseReport(0, point.dx.toInt(), point.dy.toInt());
      await sendAbsMouseReport(1, point.dx.toInt(), point.dy.toInt());
      await sendAbsMouseReport(0, point.dx.toInt(), point.dy.toInt());
      return 'Mouse moved to: ${point.dx} ${point.dy}';
    }
  }

  Uint8List absMouseReport(int buttons3bit, int x, int y) {
    final b = buttons3bit & 0x07;
    final xi = x.clamp(0, 100);
    final yi = y.clamp(0, 100);
    return Uint8List.fromList([b, xi, yi]);
  }

  // Send a relative mouse move + button state as 3-byte report: [buttons, dx, dy]
  Future<void> sendAbsMouseReport(int buttons, int dx, int dy) async {
    int toX100(int v) => ((v / max(screenSize.width, screenSize.height)) * 100).toInt();
    int toY100(int v) => ((v / min(screenSize.width, screenSize.height)) * 100).toInt();

    final x100 = toX100(dx);
    final y100 = toY100(dy);

    print(
      'Preparing to send abs mouse report: buttons=$buttons, dx=$dx, dy=$dy => x100=$x100, y100=$y100 per screen size: $screenSize',
    );

    final bytes = absMouseReport(buttons, x100, y100);
    print('Sending abs mouse report: ${bytes.map((e) => e.toRadixString(16).padLeft(2, '0'))}');
    await peripheralManager.notifyCharacteristic(_connectedCentral!, _connectedCharacteristic!, value: bytes);
  }

  void setConnectedCentral(Central? central, GATTCharacteristic? gattCharacteristic) {
    _connectedCentral = central;
    _connectedCharacteristic = gattCharacteristic;
  }

  bool get isConnected => _connectedCentral != null;
}
