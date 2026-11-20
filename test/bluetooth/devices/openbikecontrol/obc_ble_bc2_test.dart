import 'package:bike_control/bluetooth/devices/openbikecontrol/obc_ble_emulator.dart';
import 'package:bike_control/bluetooth/peripheral_server.dart';
import 'package:bike_control/utils/actions/base_actions.dart';
import 'package:bike_control/utils/keymap/buttons.dart';
import 'package:bike_control/utils/keymap/keymap.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prop/prop.dart';

import '../../../integration/harness/test_env.dart';

class _RecordingPeripheralServer extends PeripheralServer {
  final notified = <(String, Uint8List, String?)>[];

  @override
  Future<void> notify({required String characteristicId, required Uint8List value, String? deviceId}) async {
    notified.add((characteristicId, value, deviceId));
  }
}

KeyPair _pair(InGameAction action) => KeyPair(
  buttons: [ControllerButton('bc2Test${action.name}', action: action)],
  physicalKey: null,
  logicalKey: null,
  inGameAction: action,
);

Future<void> main() async {
  await IntegrationEnv.setUp();

  late _RecordingPeripheralServer server;
  late OpenBikeControlBluetoothEmulator emulator;

  setUp(() {
    server = _RecordingPeripheralServer();
    emulator = OpenBikeControlBluetoothEmulator(server: server)..servesBc2 = true;
  });

  test('subscribing connects the app and sends one frame', () async {
    expect(emulator.isConnected.value, isFalse);
    await emulator.onBc2Subscribed('central-1');
    expect(emulator.isConnected.value, isTrue);
    expect(emulator.connectedApp.value?.supportedActions, OpenBikeControlBluetoothEmulator.bc2SupportedActions);
    expect(server.notified.map((n) => (n.$1, n.$3)), [(CycplusBc2Emulator.TX_CHARACTERISTIC_UUID, 'central-1')]);
  });

  test('a click is a press and a release; every frame differs', () async {
    await emulator.onBc2Subscribed('central-1');
    for (final action in OpenBikeControlBluetoothEmulator.bc2SupportedActions) {
      final result = await emulator.sendAction(_pair(action), isKeyDown: true, isKeyUp: true);
      expect(result, isA<Success>(), reason: action.name);
    }
    expect(server.notified, hasLength(1 + 2 * OpenBikeControlBluetoothEmulator.bc2SupportedActions.length));
    final frames = server.notified.map((n) => n.$2.toList().toString()).toList();
    expect(frames.toSet(), hasLength(frames.length));
  });

  test('a release without a press sends nothing', () async {
    await emulator.onBc2Subscribed('central-1');
    server.notified.clear();
    await emulator.sendAction(_pair(InGameAction.shiftUp), isKeyDown: false, isKeyUp: true);
    expect(server.notified, isEmpty);
  });

  test('held: press on key down, release on key up', () async {
    await emulator.onBc2Subscribed('central-1');
    server.notified.clear();
    await emulator.sendAction(_pair(InGameAction.steerLeft), isKeyDown: true, isKeyUp: false);
    expect(server.notified, hasLength(1));
    await emulator.sendAction(_pair(InGameAction.steerLeft), isKeyDown: false, isKeyUp: true);
    expect(server.notified, hasLength(2));
  });

  test('actions a BC2 has no lever for are not handled', () async {
    await emulator.onBc2Subscribed('central-1');
    server.notified.clear();
    final result = await emulator.sendAction(_pair(InGameAction.toggleUi), isKeyDown: true, isKeyUp: true);
    expect(result, isA<NotHandled>());
    expect(server.notified, isEmpty);
  });

  test('no steering angle over BC2', () async {
    await emulator.onBc2Subscribed('central-1');
    expect(emulator.canSendSteeringAngle, isFalse);
  });
}
