import 'package:bike_control/bluetooth/devices/cycplus/cycplus_bc2_ble_emulator.dart';
import 'package:bike_control/bluetooth/peripheral_server.dart';
import 'package:bike_control/utils/actions/base_actions.dart';
import 'package:bike_control/utils/core.dart';
import 'package:bike_control/utils/keymap/apps/my_whoosh.dart';
import 'package:bike_control/utils/keymap/apps/supported_app.dart';
import 'package:bike_control/utils/keymap/buttons.dart';
import 'package:bike_control/utils/keymap/keymap.dart';
import 'package:bike_control/utils/requirements/multi.dart';
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
  late CycplusBc2BluetoothEmulator emulator;

  setUp(() {
    server = _RecordingPeripheralServer();
    emulator = CycplusBc2BluetoothEmulator(server: server);
  });

  test('subscribing connects the app and sends one frame', () async {
    expect(emulator.isConnected.value, isFalse);
    await emulator.onSubscribed('central-1');
    expect(emulator.isConnected.value, isTrue);
    expect(server.notified.map((n) => (n.$1, n.$3)), [(CycplusBc2Emulator.TX_CHARACTERISTIC_UUID, 'central-1')]);
  });

  test('nothing is sent before an app subscribes', () async {
    final result = await emulator.sendAction(_pair(InGameAction.shiftUp), isKeyDown: true, isKeyUp: true);
    expect(result, isA<Error>());
    expect(server.notified, isEmpty);
  });

  test('a click is a press and a release; every frame differs', () async {
    await emulator.onSubscribed('central-1');
    for (final action in CycplusBc2BluetoothEmulator.actions) {
      final result = await emulator.sendAction(_pair(action), isKeyDown: true, isKeyUp: true);
      expect(result, isA<Success>(), reason: action.name);
    }
    expect(server.notified, hasLength(1 + 2 * CycplusBc2BluetoothEmulator.actions.length));
    final frames = server.notified.map((n) => n.$2.toList().toString()).toList();
    expect(frames.toSet(), hasLength(frames.length));
  });

  test('a release without a press sends nothing', () async {
    await emulator.onSubscribed('central-1');
    server.notified.clear();
    await emulator.sendAction(_pair(InGameAction.shiftUp), isKeyDown: false, isKeyUp: true);
    expect(server.notified, isEmpty);
  });

  test('held: press on key down, release on key up', () async {
    await emulator.onSubscribed('central-1');
    server.notified.clear();
    await emulator.sendAction(_pair(InGameAction.steerLeft), isKeyDown: true, isKeyUp: false);
    expect(server.notified, hasLength(1));
    await emulator.sendAction(_pair(InGameAction.steerLeft), isKeyDown: false, isKeyUp: true);
    expect(server.notified, hasLength(2));
  });

  test('actions a BC2 has no lever for are not handled', () async {
    await emulator.onSubscribed('central-1');
    server.notified.clear();
    final result = await emulator.sendAction(_pair(InGameAction.toggleUi), isKeyDown: true, isKeyUp: true);
    expect(result, isA<NotHandled>());
    expect(server.notified, isEmpty);
  });

  group('MyWhoosh', () {
    tearDown(() async {
      await core.settings.setBc2BleEnabled(false);
    });

    test('offers BC2 over Bluetooth only with the app on another device', () async {
      core.settings.setTrainerApp(MyWhoosh());
      expect(MyWhoosh().supports(AppConnectionMethod.cycplusBc2Ble), isTrue);
      expect(MyWhoosh().supports(AppConnectionMethod.obpBle), isFalse);

      await core.settings.setLastTarget(Target.otherDevice);
      expect(core.logic.trainerConnections, contains(same(core.bc2BluetoothEmulator)));
      await core.settings.setLastTarget(Target.thisDevice);
      expect(core.logic.trainerConnections, isNot(contains(same(core.bc2BluetoothEmulator))));
    });

    test('enabled counts as a connection method and is one of the enabled ones', () async {
      core.settings.setTrainerApp(MyWhoosh());
      await core.settings.setLastTarget(Target.otherDevice);
      await core.settings.setBc2BleEnabled(true);
      expect(core.logic.isBc2BleEnabled, isTrue);
      expect(core.logic.emulatorEnabled, isTrue);
      expect(core.logic.enabledTrainerConnections, contains(same(core.bc2BluetoothEmulator)));
    });
  });
}
