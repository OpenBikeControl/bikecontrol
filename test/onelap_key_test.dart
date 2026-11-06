import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:bike_control/bluetooth/devices/bluetooth_device.dart';
import 'package:bike_control/bluetooth/devices/magene/onelap_key.dart';
import 'package:bike_control/bluetooth/devices/magene/onelap_key_packet.dart';
import 'package:bike_control/bluetooth/emulation/emulated_ble_platform.dart';
import 'package:bike_control/gen/l10n.dart';
import 'package:bike_control/utils/actions/base_actions.dart';
import 'package:bike_control/utils/core.dart';
import 'package:bike_control/utils/keymap/apps/custom_app.dart';
import 'package:bike_control/utils/keymap/apps/my_whoosh.dart';
import 'package:bike_control/utils/keymap/buttons.dart';
import 'package:bike_control/utils/keymap/keymap.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart' show LucideIcons;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:universal_ble/universal_ble.dart';

Uint8List _hex(String value) => Uint8List.fromList([
  for (var offset = 0; offset < value.length; offset += 2) int.parse(value.substring(offset, offset + 2), radix: 16),
]);

class _TestOnelapKey extends OnelapKey {
  _TestOnelapKey(super.scanResult);

  bool repeatEnabled = false;

  @override
  bool get isProEnabledForRepeat => repeatEnabled;

  @override
  Future<void> disconnectUpstream() async {}
}

Future<void> main() async {
  TestWidgetsFlutterBinding.ensureInitialized();
  await AppLocalizations.load(const Locale('en'));
  final fixture =
      jsonDecode(
            File('test/fixtures/onelap_key_capture.json').readAsStringSync(),
          )
          as Map<String, dynamic>;
  final cases = fixture['cases'] as List<dynamic>;

  late _TestOnelapKey device;
  late StubActions actions;

  setUp(() {
    actions = StubActions();
    core.actionHandler = actions;
    device = _TestOnelapKey(
      BleDevice(deviceId: 'onelap-1', name: 'Onelap Key_12224'),
    );
  });

  tearDown(() async {
    BluetoothDevice.debugIsWeb = null;
    await device.disconnect();
    await device.actionStreamInternal.close();
  });

  Future<void> send(String hex, {String? characteristic}) => device.processCharacteristic(
    characteristic ?? OnelapKeyConstants.characteristicUuid,
    _hex(hex),
  );

  group('Onelap Key hardware frames', () {
    for (final value in cases) {
      final sample = value as Map<String, dynamic>;
      final name = sample['button'] as String;
      final longPress = sample['trigger'] == 'longPress';
      test('$name ${sample['trigger']}', () async {
        for (final value in sample['packets'] as List<dynamic>) {
          await send(value as String);
        }
        final button = OnelapKeyButtons.values.singleWhere(
          (button) => button.name == name,
        );
        if (longPress) {
          expect(actions.performedActions, [
            PerformedAction(
              button,
              isDown: true,
              isUp: false,
              trigger: ButtonTrigger.longPress,
            ),
            PerformedAction(
              button,
              isDown: false,
              isUp: true,
              trigger: ButtonTrigger.longPress,
            ),
          ]);
        } else {
          expect(actions.performedActions, [
            PerformedAction(button, isDown: true, isUp: true),
          ]);
        }
      });
    }

    test('preserves consecutive identical clicks', () async {
      await send('8bf510e503000004040000');
      await send('8bf510e503000004040000');
      expect(actions.performedActions, [
        PerformedAction(OnelapKeyButtons.up, isDown: true, isUp: true),
        PerformedAction(OnelapKeyButtons.up, isDown: true, isUp: true),
      ]);
    });

    test('dispatches all known buttons in a multi-bit mask', () async {
      await send('8bf510e5030000000a0000');
      expect(actions.performedActions.map((action) => action.button.name), [
        'onelapLeft',
        'onelapRight',
      ]);
    });

    test('ignores CC03 and other messages', () async {
      await send(
        '8bf510e503000004040000',
        characteristic: '8ce5cc03-0a4d-11e9-ab14-d663bd873d93',
      );
      await send('8b0010e503000004040000');
      await send('8bf500e503000004040000');
      expect(actions.performedActions, isEmpty);
    });

    test('ignores short frames and unknown high bits', () async {
      for (var length = 0; length < 11; length++) {
        await device.processCharacteristic(
          OnelapKeyConstants.characteristicUuid,
          Uint8List(length),
        );
      }
      await send('8bf510e503000000e000e0');
      expect(actions.performedActions, isEmpty);
    });

    test('invalid frames release an active long press', () async {
      await send('8bf510e503000000000004');
      await send('00');
      expect(actions.performedActions, [
        PerformedAction(
          OnelapKeyButtons.up,
          isDown: true,
          isUp: false,
          trigger: ButtonTrigger.longPress,
        ),
        PerformedAction(
          OnelapKeyButtons.up,
          isDown: false,
          isUp: true,
          trigger: ButtonTrigger.longPress,
        ),
      ]);
    });

    test('disconnect releases long press and the next click starts clean', () async {
      await send('8bf510e503000000000001');
      await device.disconnect();
      await send('8bf510e503000004040000');
      expect(actions.performedActions, [
        PerformedAction(
          OnelapKeyButtons.center,
          isDown: true,
          isUp: false,
          trigger: ButtonTrigger.longPress,
        ),
        PerformedAction(
          OnelapKeyButtons.center,
          isDown: false,
          isUp: true,
          trigger: ButtonTrigger.longPress,
        ),
        PerformedAction(OnelapKeyButtons.up, isDown: true, isUp: true),
      ]);
    });

    test('releases the previous long press before a new gesture', () async {
      await send('8bf510e503000000000001');
      await send('8bf510e503000004040000');
      expect(actions.performedActions.last.trigger, ButtonTrigger.singleClick);
      expect(actions.performedActions[1].isUp, isTrue);
      expect(actions.performedActions, hasLength(3));
    });

    test('characteristic UUID matching is case-insensitive', () async {
      await send(
        '8bf510e503000004040000',
        characteristic: OnelapKeyConstants.characteristicUuid.toUpperCase(),
      );
      expect(actions.performedActions, hasLength(1));
    });
  });

  group('Onelap Key detection and registration', () {
    for (final web in [false, true]) {
      test('${web ? 'Web' : 'native'} detects a battery-only advertisement by name', () {
        BluetoothDevice.debugIsWeb = () => web;
        for (final name in [
          'Onelap Key_12224',
          'ONELAP KEY_12224',
          'Onelap Key',
        ]) {
          final result = BluetoothDevice.fromScanResult(
            BleDevice(
              deviceId: 'scan',
              name: name,
              services: ['0000180f-0000-1000-8000-00805f9b34fb'],
            ),
          );
          expect(result, isA<OnelapKey>());
        }
      });

      test('${web ? 'Web' : 'native'} ignores other Magene devices and unnamed devices', () {
        BluetoothDevice.debugIsWeb = () => web;
        for (final name in ['Onelap Keyboard', 'Magene', 'Onelap']) {
          expect(
            BluetoothDevice.fromScanResult(
              BleDevice(deviceId: 'other', name: name),
            ),
            isNull,
          );
        }
        expect(
          BluetoothDevice.fromScanResult(
            BleDevice(
              deviceId: 'unnamed',
              name: null,
              services: [OnelapKeyConstants.serviceUuid],
            ),
          ),
          isNull,
        );
      });
    }

    test('diagram faces match the molded cross', () {
      expect(OnelapKeyButtons.up.icon, LucideIcons.circle);
      expect(OnelapKeyButtons.left.icon, LucideIcons.triangle);
      expect(OnelapKeyButtons.right.icon, LucideIcons.square);
      expect(OnelapKeyButtons.down.icon, LucideIcons.grip);
      expect(OnelapKeyButtons.center.icon, isNull);
      expect(OnelapKeyButtons.center.label, 'ONELAP');
      expect(device.controllerLayout.positions[OnelapKeyButtons.up], const Offset(0.5, 0.2));
      expect(device.controllerLayout.positions[OnelapKeyButtons.left], const Offset(0.2, 0.5));
      expect(device.controllerLayout.positions[OnelapKeyButtons.right], const Offset(0.8, 0.5));
      expect(device.controllerLayout.positions[OnelapKeyButtons.down], const Offset(0.5, 0.8));
      expect(device.controllerLayout.positions[OnelapKeyButtons.center], const Offset(0.5, 0.5));
    });

    test('Web exposes CC01 and registers all five buttons', () {
      expect(
        BluetoothDevice.servicesToScan,
        contains(OnelapKeyConstants.serviceUuid),
      );
      expect(ControllerButton.values, containsAll(OnelapKeyButtons.values));
      expect(device.controllerLayout.positions, hasLength(5));
      expect(device.supportsLongPress, isTrue);
    });

    test('MyWhoosh mapping includes all five buttons after registration', () async {
      SharedPreferences.setMockInitialValues({'trainer_app': 'MyWhoosh'});
      core.settings.prefs = await SharedPreferences.getInstance();
      final keymap = MyWhoosh().keymap;
      keymap.addNewButtons(device.availableButtons);
      for (final button in device.availableButtons) {
        expect(keymap.getKeyPair(button)?.inGameAction, button.action);
      }
    });

    test('hardware release stops Pro implicit repeat', () async {
      final app = CustomApp(profileName: 'Onelap repeat');
      final button = device.availableButtons[2];
      app.keymap.addKeyPair(
        KeyPair(
          buttons: [button],
          physicalKey: null,
          logicalKey: null,
          inGameAction: InGameAction.shiftUp,
        ),
      );
      actions.supportedApp = app;
      device.repeatEnabled = true;
      await send('8bf510e503000000000004');
      await Future<void>.delayed(Duration.zero);
      expect(actions.performedActions, hasLength(1));
      await send('8bf510e503000004000000');
      final afterRelease = actions.performedActions.length;
      await Future<void>.delayed(const Duration(milliseconds: 350));
      expect(actions.performedActions, hasLength(afterRelease));
    });

    test('multiple controllers keep independent device identifiers', () {
      final other = OnelapKey(
        BleDevice(deviceId: 'onelap-2', name: 'Onelap Key_2'),
      );
      expect(
        device.availableButtons.every(
          (button) => button.sourceDeviceId == 'onelap-1',
        ),
        isTrue,
      );
      expect(
        other.availableButtons.every(
          (button) => button.sourceDeviceId == 'onelap-2',
        ),
        isTrue,
      );
      expect(
        other.availableButtons.first,
        isNot(equals(device.availableButtons.first)),
      );
    });

    test('subscribes only to CC02 and sends no initialization write', () async {
      final peripheral = FakePeripheral(
        deviceId: device.uniqueId,
        name: device.name,
        services: [
          BleService(OnelapKeyConstants.serviceUuid, [
            BleCharacteristic(OnelapKeyConstants.characteristicUuid, [
              CharacteristicProperty.notify,
            ], []),
          ]),
        ],
      );
      final ble = FakeUniversalBlePlatform()..addPeripheral(peripheral);
      UniversalBle.setInstance(ble);
      await device.handleServices(peripheral.services);
      expect(peripheral.subscriptions, [
        OnelapKeyConstants.characteristicUuid,
      ]);
      expect(peripheral.writes, isEmpty);
    });

    test('missing CC01 or CC02 fails clearly', () async {
      await expectLater(device.handleServices([]), throwsException);
      await expectLater(
        device.handleServices([
          BleService(OnelapKeyConstants.serviceUuid, []),
        ]),
        throwsException,
      );
    });
  });

  test('protocol preserves device type and index and rejects unknown types', () {
    final bytes = _hex('8bf510e503e20000040000');
    final packet = OnelapKeyPacket.parse(bytes)!;
    expect(packet.deviceType, 2);
    expect(packet.deviceIndex, 7);
    expect(packet.clickedButtons, 4);
    bytes[5] = 3;
    expect(OnelapKeyPacket.parse(bytes), isNull);
  });
}
