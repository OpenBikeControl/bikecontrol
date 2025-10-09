import 'package:bluetooth_low_energy/bluetooth_low_energy.dart';
import 'package:flutter/foundation.dart';
import 'package:swift_control/bluetooth/devices/zwift_click.dart';
import 'package:swift_control/main.dart';
import 'package:swift_control/utils/actions/base_actions.dart';
import 'package:swift_control/utils/keymap/buttons.dart';
import 'package:swift_control/widgets/keymap_explanation.dart';
import 'package:universal_ble/universal_ble.dart';

import '../requirements/remote.dart';

class RemoteActions extends BaseActions {
  @override
  Future<String> performAction(ZwiftButton action, {bool isKeyDown = true, bool isKeyUp = false}) async {
    if (supportedApp == null) {
      return 'Supported app is not set';
    }

    final keyPair = supportedApp!.keymap.getKeyPair(action);
    if (keyPair == null) {
      return 'Keymap entry not found for action: ${action.toString().splitByUpperCase()}';
    }

    if (!(actionHandler as RemoteActions).isConnected) {
      return 'Not connected to a device';
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
      final point2 = point; //Offset(100, 99.0);
      await sendAbsMouseReport(0, point2.dx.toInt(), point2.dy.toInt());
      await sendAbsMouseReport(1, point2.dx.toInt(), point2.dy.toInt());
      await sendAbsMouseReport(0, point2.dx.toInt(), point2.dy.toInt());
      return 'Mouse clicked at: ${point2.dx} ${point2.dy}';
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
    final bytes = absMouseReport(buttons, dx, dy);
    if (kDebugMode) {
      print('Preparing to send abs mouse report: buttons=$buttons, dx=$dx, dy=$dy');
      print('Sending abs mouse report: ${bytes.map((e) => e.toRadixString(16).padLeft(2, '0'))}');
    }

    await peripheralManager.notifyCharacteristic(connectedCentral!, connectedCharacteristic!, value: bytes);
  }

  Central? connectedCentral;
  GATTCharacteristic? connectedCharacteristic;

  void setConnectedCentral(Central? central, GATTCharacteristic? gattCharacteristic) {
    connectedCentral = central;
    connectedCharacteristic = gattCharacteristic;

    connection.signalChange(ZwiftClick(BleDevice(deviceId: 'deviceId', name: 'name')));
  }

  bool get isConnected => connectedCentral != null;
}
