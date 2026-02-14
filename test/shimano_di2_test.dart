import 'dart:typed_data';

import 'package:bike_control/bluetooth/devices/shimano/shimano_di2.dart';
import 'package:bike_control/utils/actions/base_actions.dart';
import 'package:bike_control/utils/core.dart';
import 'package:bike_control/utils/keymap/apps/openbikecontrol.dart';
import 'package:bike_control/utils/keymap/buttons.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:universal_ble/universal_ble.dart';

Future<void> main() async {
  final stubActions = StubActions();
  stubActions.supportedApp = OpenBikeControl();

  SharedPreferences.setMockInitialValues({});
  await core.settings.init();
  core.actionHandler = stubActions;

  group('Shimano DI2 Tests', () {
    test('Should parse Di2 values correctly', () async {
      stubActions.cleanup();
      final instance = ShimanoDi2(BleDevice(name: 'Di2', deviceId: ''));
      await instance.processCharacteristic(
        ShimanoDi2Constants.D_FLY_CHANNEL_UUID,
        Uint8List.fromList([0x21, 0x13, 0xF0, 0xF0]),
      );

      expect(stubActions.performedActions.isEmpty, true);

      await instance.processCharacteristic(
        ShimanoDi2Constants.D_FLY_CHANNEL_UUID,
        Uint8List.fromList([0x21, 0x13, 0xF0, 0xF0]),
      );
      expect(stubActions.performedActions.isEmpty, true);

      await instance.processCharacteristic(
        ShimanoDi2Constants.D_FLY_CHANNEL_UUID,
        Uint8List.fromList([0x21, 0x14, 0xF0, 0xF0]),
      );
      expect(stubActions.performedActions.isEmpty, false);
    });

    test('should transmit all events', () async {
      stubActions.cleanup();
      final instance = ShimanoDi2(BleDevice(name: 'Di2', deviceId: ''));
      await instance.processCharacteristic(
        ShimanoDi2Constants.D_FLY_CHANNEL_UUID,
        Uint8List.fromList([0x21, 0x13, 0xF0, 0xF0]),
      );

      expect(stubActions.performedActions.isEmpty, true);

      await instance.processCharacteristic(
        ShimanoDi2Constants.D_FLY_CHANNEL_UUID,
        Uint8List.fromList([0x21, 0x13, 0xF0, 0xF0]),
      );
      expect(stubActions.performedActions.isEmpty, true);

      await instance.processCharacteristic(
        ShimanoDi2Constants.D_FLY_CHANNEL_UUID,
        Uint8List.fromList([0x21, 0x14, 0xF0, 0xF0]),
      );
      final button = ControllerButton('D-Fly Channel 1');
      expect(
        stubActions.performedActions,
        equals([
          PerformedAction(button, isDown: true, isUp: false),
          PerformedAction(button, isDown: false, isUp: true),
        ]),
      );

      await instance.processCharacteristic(
        ShimanoDi2Constants.D_FLY_CHANNEL_UUID,
        Uint8List.fromList([0x21, 0x15, 0xF0, 0xF0]),
      );
      expect(
        stubActions.performedActions,
        equals([
          PerformedAction(button, isDown: true, isUp: false),
          PerformedAction(button, isDown: false, isUp: true),
          PerformedAction(button, isDown: true, isUp: false),
          PerformedAction(button, isDown: false, isUp: true),
        ]),
      );
    });
  });
}
